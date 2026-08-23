#!/usr/bin/env python3
"""Monotonic ID allocation for codebase-ops artifacts.

SPC-0035/F0.5: allocation is cross-branch aware — `next_id_unlocked` takes the max
of the local glob, the git-wide scan across ALL refs (lib.id_ledger.scan_ids_git),
and the committed high-water ledger. NOTE: the per-worktree `id_lock` (fcntl)
serializes allocation WITHIN one checkout only — it does NOT protect cross-branch
allocation; that is what the git-wide scan + ledger provide. Set
CODEBASE_OPS_ID_CROSS_BRANCH=0 to short-circuit all git subprocess calls
(offline/huge-repo fallback to local glob + ledger)."""

from __future__ import annotations

from contextlib import contextmanager
import re
from pathlib import Path
from typing import Iterator

from lib.paths import archived_decisions, archived_designs, archived_tickets, paths
from lib import id_ledger as _id_ledger

import importlib.util as _ilu
fcntl = __import__("fcntl") if _ilu.find_spec("fcntl") else None  # POSIX-only; None elsewhere (F0.7-T2)


@contextmanager
def id_lock(root: str | Path | None = None) -> Iterator[None]:
    """Serialize ID allocation through a shared lock across worktrees.

    Lock lives in git common dir (shared by all worktrees) so that allocations
    from different worktrees (parallel features) are properly serialized.
    This + runtime high-water is the main defense against ID conflicts.
    """
    p = paths(root)
    lock_dir = p.id_state / "locks"
    lock_dir.mkdir(parents=True, exist_ok=True)
    lock_path = lock_dir / "ids.lock"
    with lock_path.open("a+", encoding="utf-8") as fh:
        if fcntl is not None:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            if fcntl is not None:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def e_serie_valida(numero: str) -> bool:
    """Distingue serie (`0021`) de artefato com nome DATADO (`20260720`).

    TCK-2277. O regex aceita `\\d{4,}` de proposito — TCK-0342 alargou para que
    `TCK-10000` fosse visto, e estreitar de volta para 4 exatos quebraria o dia
    em que a serie legitimamente passar de 9999.

    O problema e outro: artefatos legados com nome datado
    (`DSC-20260720-framework-quality-waves.md`) casam o mesmo padrao, e o
    alocador le `20260720` como numero de serie. Medido em 2026-08-10 no
    `high-water.json`: `DSC` e `BRF` em **20260722**, quando o maior DSC
    legitimo do acervo e `DSC-0021`. Toda alocacao seguinte saia como
    `DSC-2026NNNN`, fora da convencao que o resto do sistema assume.

    Data e serie sao distinguiveis sem heuristica de magnitude: 8 digitos que
    parseiam como `YYYYMMDD` plausivel nao sao numero de serie. Uma serie de 8
    digitos e possivel em tese (99 milhoes de tickets) e ficaria de fora — troca
    aceita, e o custo do erro e assimetrico: ignorar uma serie improvavel
    reaproveita um ID; aceitar uma data envenena o contador para sempre.
    """
    if len(numero) != 8:
        return True
    ano, mes, dia = int(numero[:4]), int(numero[4:6]), int(numero[6:])
    return not (2000 <= ano <= 2099 and 1 <= mes <= 12 and 1 <= dia <= 31)


def _max_numeric_id(prefix: str, directories: list[Path]) -> int:
    # TCK-0342: >=4 digits so a 5-digit id (e.g. TCK-10000) is visible, not skipped.
    pattern = re.compile(rf"\b{re.escape(prefix)}-(\d{{4,}})(?:[a-z][0-9]*)?\b")
    highest = 0
    for directory in directories:
        if not directory.exists():
            continue
        for path in directory.glob(f"{prefix}-*.md"):
            match = pattern.search(path.name)
            if match and e_serie_valida(match.group(1)):
                highest = max(highest, int(match.group(1)))
    return highest


def _cross_branch_max(prefix: str, root: str | Path | None) -> int:
    """Highest NNNN across git refs + committed ledger + shared runtime high-water.

    Shared runtime high-water (in git common dir) is the key strengthening
    for worktrees: concurrent allocations from different worktrees are
    serialized by the shared lock and see each other's bumps immediately.
    """
    target = root if root is not None else "."
    highest = 0
    for full in _id_ledger.scan_ids_git(prefix, root=target):
        m = re.search(r"-(\d{4,})", str(full))
        if m and e_serie_valida(m.group(1)):
            highest = max(highest, int(m.group(1)))
    committed = _id_ledger.ledger_high_water(prefix, target)
    runtime = _id_ledger.shared_high_water(prefix, target)
    # TCK-2277: o high-water compartilhado PERSISTE o envenenamento — uma vez
    # gravado `20260722`, todo alocador futuro le dali, mesmo com o scan ja
    # corrigido. Sanear na leitura e o que torna o fix efetivo sem exigir que
    # alguem lembre de editar `.git/.../high-water.json` a mao.
    if not e_serie_valida(str(committed)):
        committed = 0
    if not e_serie_valida(str(runtime)):
        runtime = 0
    return max(highest, committed, runtime)


def next_id_unlocked(prefix: str, directories: list[Path], root: str | Path | None = None,
                     reservar: bool = True) -> str:
    """Return the next ``PREFIX-NNNN`` ID (cross-branch + worktree safe).

    Max of local + git-wide scan + committed ledger + shared runtime high-water.
    The shared high-water bump (under shared lock in git common dir) reserves
    the ID for other worktrees immediately, even before the artifact file is
    written in this worktree. This is the key strengthening for parallel worktrees.
    """
    local = _max_numeric_id(prefix, directories)
    cross = _cross_branch_max(prefix, root)
    candidate = max(local, cross) + 1
    target = root if root is not None else "."
    # TCK-2277: `reservar=False` para quem so quer SABER o proximo id sem
    # consumi-lo. O `--dry-run` do create_ticket bumpava o contador
    # compartilhado: a sonda desta sessao queimou o TCK-2276, que nao existe
    # como arquivo. Dry-run que muta estado compartilhado nao e dry-run.
    if reservar:
        _id_ledger.write_shared_high_water(prefix, candidate, target)
    return f"{prefix}-{candidate:04d}"


def next_id(prefix: str, directories: list[Path], root: str | Path | None = None) -> str:
    """Return the next ``PREFIX-NNNN`` ID while holding the ID lock."""
    with id_lock(root):
        return next_id_unlocked(prefix, directories, root)


def next_ticket_id_unlocked(root: str | Path | None = None, reservar: bool = True) -> str:
    p = paths(root)
    return next_id_unlocked("TCK", [p.tickets, archived_tickets(root)], root,
                            reservar=reservar)


def next_ticket_id(root: str | Path | None = None, reservar: bool = True) -> str:
    with id_lock(root):
        return next_ticket_id_unlocked(root, reservar=reservar)


def next_design_id_unlocked(root: str | Path | None = None) -> str:
    p = paths(root)
    return next_id_unlocked("DES", [p.designs, archived_designs(root)], root)


def next_design_id(root: str | Path | None = None) -> str:
    with id_lock(root):
        return next_design_id_unlocked(root)


def next_adr_id_unlocked(root: str | Path | None = None) -> str:
    p = paths(root)
    return next_id_unlocked("ADR", [p.decisions, archived_decisions(root)], root)


def next_adr_id(root: str | Path | None = None) -> str:
    with id_lock(root):
        return next_adr_id_unlocked(root)


def next_telemetry_plan_id_unlocked(root: str | Path | None = None) -> str:
    p = paths(root)
    return next_id_unlocked("TLP", [p.telemetry_plans], root)


def next_telemetry_plan_id(root: str | Path | None = None) -> str:
    with id_lock(root):
        return next_telemetry_plan_id_unlocked(root)


def next_post_release_report_id_unlocked(root: str | Path | None = None) -> str:
    p = paths(root)
    return next_id_unlocked("PRR", [p.post_release_reports], root)


def next_post_release_report_id(root: str | Path | None = None) -> str:
    with id_lock(root):
        return next_post_release_report_id_unlocked(root)


def next_learning_record_id_unlocked(root: str | Path | None = None) -> str:
    p = paths(root)
    return next_id_unlocked("LRN", [p.learning_records], root)


def next_learning_record_id(root: str | Path | None = None) -> str:
    with id_lock(root):
        return next_learning_record_id_unlocked(root)
