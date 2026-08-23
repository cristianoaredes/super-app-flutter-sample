#!/usr/bin/env python3
"""Repository invariants for codebase-ops validation."""

from __future__ import annotations

import re

from dataclasses import dataclass
import csv
import io
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from lib.frontmatter import parse_frontmatter, parse_list
from lib.paths import paths
from lib.runstate import is_stale

CONTEXT_INDEX_MTIME_TOLERANCE_SECONDS = 1.0


@dataclass(frozen=True)
class InvariantResult:
    name: str
    ok: bool
    severity: str
    message: str

    def as_dict(self) -> dict[str, object]:
        return {
            "name": self.name,
            "ok": self.ok,
            "severity": self.severity,
            "message": self.message,
        }


def _result(name: str, ok: bool, message: str, severity: str = "error") -> InvariantResult:
    return InvariantResult(name=name, ok=ok, severity=severity, message=message)


def _ticket_files(root: str | Path | None = None) -> list[Path]:
    return sorted(paths(root).tickets.glob("TCK-*.md"))


def _ticket_meta(path: Path) -> dict:
    return parse_frontmatter(path.read_text(encoding="utf-8"))


def _backlog_rows(root: str | Path | None = None) -> list[dict[str, str]]:
    p = paths(root).backlog_csv
    if not p.exists():
        return []
    with p.open(encoding="utf-8", newline="") as fh:
        return list(csv.DictReader(fh))


def _derived_backlog_rows(root: str | Path | None = None) -> list[dict[str, str]]:
    # Single source (ADR-0001): scripts/generate-backlog.py owns the backlog schema.
    # Reimplementing the columns here drifted from origin/main (which grew
    # reopened_count..done_at), so the invariant could never match what
    # `derived regenerate` writes (TCK-0172 integration). Delegate to the canonical
    # generator's --stdout so the check can't diverge from the regenerator.
    p = paths(root)
    generator = p.root / "scripts" / "generate-backlog.py"
    if not generator.exists():
        return _backlog_rows(root)  # no generator → nothing to diverge from
    proc = subprocess.run(
        [sys.executable, str(generator), "--stdout"],
        cwd=str(p.root),
        capture_output=True,
        text=True,
        timeout=120,
    )
    if proc.returncode != 0:
        return []  # generator failure → surfaces as a backlog mismatch
    return list(csv.DictReader(io.StringIO(proc.stdout)))


def check_backlog_csv(root: str | Path | None = None) -> InvariantResult:
    actual = _backlog_rows(root)
    expected = _derived_backlog_rows(root)
    return _result(
        "backlog.csv == derive(tickets/*.md)",
        actual == expected,
        "backlog.csv matches tickets" if actual == expected else "backlog.csv is stale; run derived regenerate",
    )


def check_skills_mirror(root: str | Path | None = None) -> InvariantResult:
    # Single source (ADR-0001): scripts/sync-skills.sh owns the mirror contract. A naive
    # byte compare false-positives because skills/codebase-ops/SKILL.md is intentionally a
    # concatenation of core/SKILL.md (router) + core/skills/*/SKILL.md (DES-0135), NOT a
    # byte copy. Delegate to its --check so the invariant honors the real transform.
    p = paths(root).root
    core = p / "core"
    mirror = p / "skills" / "codebase-ops"
    if not core.exists() or not mirror.exists():
        return _result("skills/ == mirror(core/)", False, "core/ or skills/codebase-ops/ missing")
    script = p / "scripts" / "sync-skills.sh"
    if not script.exists():
        return _result("skills/ == mirror(core/)", True, "sync-skills.sh absent — skipped")
    proc = subprocess.run(
        ["bash", str(script), "--check"],
        cwd=str(p),
        capture_output=True,
        text=True,
        timeout=60,
    )
    ok = proc.returncode == 0
    return _result(
        "skills/ == mirror(core/)",
        ok,
        "skills mirror is in sync" if ok else "drift detected (sync-skills.sh --check)",
    )


def check_context_index_fresh(root: str | Path | None = None) -> InvariantResult:
    """TCK-0823: freshness of canonical SQLite index (.index.db), not the
    retired JSON context-index.json cache."""
    p = paths(root)
    index = p.archagents / ".index.db"
    if not index.exists():
        return _result("index.db fresh", False, "index.db missing", severity="warning")
    newest = max((f.stat().st_mtime for f in _ticket_files(root)), default=0)
    index_mtime = index.stat().st_mtime
    ok = index_mtime + CONTEXT_INDEX_MTIME_TOLERANCE_SECONDS >= newest
    return _result(
        ".index.db mtime >= max(tickets/*.md mtime)",
        ok,
        "index.db is fresh"
        if ok
        else f"index.db older than tickets by {newest - index_mtime:.3f}s",
        severity="warning",
    )


def _exists_any(base: Path, artifact_id: str, suffix: str = "*.md") -> bool:
    return any(base.glob(f"{artifact_id}-{suffix}")) or (base / f"{artifact_id}.md").exists()


def check_ticket_links(root: str | Path | None = None) -> list[InvariantResult]:
    p = paths(root)
    results: list[InvariantResult] = []
    missing: list[str] = []
    for ticket in _ticket_files(root):
        fm = _ticket_meta(ticket)
        tid = str(fm.get("id", ticket.stem))
        for design in parse_list(fm.get("linked_designs")):
            if not _exists_any(p.designs, design):
                missing.append(f"{tid}: missing design {design}")
        for run in parse_list(fm.get("linked_runs")):
            if not (p.runs / run).is_dir():
                missing.append(f"{tid}: missing run {run}")
        for ver in parse_list(fm.get("linked_verifications")):
            if not (p.verify_reports / f"{ver}.md").exists():
                missing.append(f"{tid}: missing verification {ver}")
    results.append(
        _result(
            "ticket linked artifacts exist",
            not missing,
            "all linked artifacts exist" if not missing else "; ".join(missing[:10]),
            severity="warning",
        )
    )
    return results


def check_stale_raw_tickets(root: str | Path | None = None, max_days: int = 30) -> InvariantResult:
    now = datetime.now(timezone.utc)
    stale: list[str] = []
    for ticket in _ticket_files(root):
        fm = _ticket_meta(ticket)
        if fm.get("status") != "raw":
            continue
        created = str(fm.get("created_at", "")).replace("Z", "+00:00")
        try:
            created_at = datetime.fromisoformat(created)
        except ValueError:
            continue
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        if (now - created_at).days > max_days:
            stale.append(str(fm.get("id", ticket.stem)))
    return _result(
        "no raw tickets older than 30 days without triage",
        not stale,
        "no stale raw tickets" if not stale else f"stale raw tickets: {', '.join(stale)}",
        severity="warning",
    )


def check_stale_paused_runs(root: str | Path | None = None) -> InvariantResult:
    p = paths(root)
    stale: list[str] = []
    for run_json in p.runs.glob("RUN-*/run.json"):
        try:
            import json

            data = json.loads(run_json.read_text(encoding="utf-8"))
        except Exception:
            continue
        status = str(data.get("status", ""))
        if status.startswith("paused") and is_stale(data.get("started_at")):
            stale.append(str(data.get("id", run_json.parent.name)))
    return _result(
        "no paused-* runs older than 24h without resume",
        not stale,
        "no stale paused runs" if not stale else f"stale paused runs: {', '.join(stale)}",
        severity="warning",
    )


#: TCK-2033: marcadores que declaram uma citação como não-resolvível. Precisam
#: aparecer NA MESMA LINHA do ID, logo depois dele — assim a declaração fica
#: colada ao fato que declara, e não numa nota de rodapé que se descola do texto.
_MARCADORES_CITACAO_DECLARADA = (
    "não-resolvido", "nao-resolvido",   # referência morta, preservada por P6
    "exemplo", "fixture", "placeholder",  # forma ilustrativa, nunca foi ID real
)


#: Prefixos que declaram o trecho como ilustrativo ANTES do ID. Ler estes evita
#: ter de anotar o ID inline: uma linha do tipo "(ex.: VER para TCK-0700/TCK-0701
#: juntos) usa `covers: [...]`" já diz que os IDs são forma, não referência — e
#: anotar dentro dela corromperia o exemplo de código que ela mostra (tentei; o
#: resultado ficou pior que o problema).
_PREFIXOS_ILUSTRATIVOS = ("ex.:", "exemplo", "e.g.", "por exemplo", "fixture")


def _citacao_declarada(texto: str, ticket_id: str) -> bool:
    """True quando TODAS as ocorrências de `ticket_id` estão declaradas.

    Exige de todas de propósito: bastar uma declaração permitiria anotar a
    primeira citação e seguir citando o ID como se fosse real em qualquer outro
    ponto do documento — o que é exatamente o defeito original (ID solto na prosa
    passando por concluído).

    Uma linha declara de duas formas, ambas na MESMA linha do ID: marcador
    DEPOIS dele (anotação explícita) ou prefixo ilustrativo ANTES dele (o texto
    já dizia que é exemplo).
    """
    ocorrencias = list(re.finditer(re.escape(ticket_id) + r"(?!\d)", texto))
    if not ocorrencias:
        return False
    for m in ocorrencias:
        inicio_linha = texto.rfind("\n", 0, m.start()) + 1
        fim_linha = texto.find("\n", m.end())
        if fim_linha == -1:
            fim_linha = len(texto)
        cabeca = texto[inicio_linha: m.start()].lower()
        cauda = texto[m.end(): fim_linha].lower()
        if any(mark in cauda for mark in _MARCADORES_CITACAO_DECLARADA):
            continue
        if any(pref in cabeca for pref in _PREFIXOS_ILUSTRATIVOS):
            continue
        return False
    return True


def check_referenced_ticket_ids_resolve(root: str | Path | None = None) -> InvariantResult:
    """ID de ticket citado em PLANO ou SPEC tem de resolver (TCK-1780).

    Medido em 2026-08-03: o `PLN-0019` declarava

        | E0 — check-scope --enforce no laco | **done** (TCK-1597) |

    e o `TCK-1597` **nao existia** — nem em `15-backlog/`, nem no archive, nem
    em lugar nenhum além daquela linha. O trabalho tambem nunca foi feito
    (`git log -S'check-scope'` no driver: nenhum commit).

    O `plan-board` deriva por `modules[].spec -> linked_tickets`; um ID solto na
    PROSA nao passa por validacao nenhuma. Isso permitiu declarar concluido um
    pre-requisito de SEGURANCA — o gate de escopo que a SPC-0093 exige antes de
    ligar qualquer agente com escrita em laco.

    Severidade `warning` e nao `error` de proposito: ha 7 arquivos com o mesmo
    problema hoje (divida pre-existente, incluindo `TCK-9999` de fixture), e um
    gate que reprova de saida seria desligado antes de ser util. O que importa e
    que a divida passe a ser VISIVEL e nao possa crescer em silencio.
    """
    p = paths(root)
    existentes: set[str] = set()
    for f in _ticket_files(root):
        m = re.match(r"(TCK-\d+)", f.name)
        if m:
            existentes.add(m.group(1))
    # TCK-2033: a divida pre-existente era de duas naturezas, e o check tratava
    # as duas como uma. Cinco eram referencias MORTAS (o ID nunca existiu) e duas
    # eram FIXTURES de documentacao (`TCK-9999` como exemplo de forma).
    #
    # Apagar a citacao do plano seria reescrever registro historico (P6). A saida
    # e ANOTAR: quem quiser silenciar uma citacao tem de declarar, no proprio
    # texto, que ela nao resolve — e a declaracao fica auditavel por grep. Isto
    # nao afrouxa o gate: um ID novo, citado sem declaracao, continua reprovando.
    arquivo_archive = Path(p.tickets).parent.parent / "archive" / "archive.csv"
    if arquivo_archive.is_file():
        existentes |= set(re.findall(r"TCK-\d+",
                                     arquivo_archive.read_text(errors="ignore")))

    fantasmas: list[str] = []
    base = Path(p.tickets).parent.parent / "12-inception"
    for sub in ("plans", "specs"):
        d = base / sub
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.md")):
            texto = f.read_text(errors="ignore")
            # TCK-2033: `TCK-\d{4}` sem boundary casa o PREFIXO de um ID de 5
            # dígitos. Medido: o `PLN-0007` cita "alocação de ID retorna
            # TCK-10000 (colide)" — o valor do bug, não um ticket — e o check
            # extraía "TCK-1000", reportando um fantasma que nunca foi citado.
            # É a mesma cegueira de >4 dígitos do TCK-0342, que é justamente o
            # ticket nomeado naquela linha.
            citados = set(re.findall(r"TCK-\d{4}(?!\d)", texto))
            faltando = sorted(
                tid for tid in (citados - existentes)
                if not _citacao_declarada(texto, tid)
            )
            if faltando:
                fantasmas.append(f"{f.name}: {', '.join(faltando)}")

    return _result(
        "ticket ids cited in plans/specs resolve",
        not fantasmas,
        "all cited ticket ids resolve" if not fantasmas else "; ".join(fantasmas[:8]),
        severity="warning",
    )


def check_done_tickets_are_committed(root: str | Path | None = None) -> InvariantResult:
    """Ticket `done` cujo design declara arquivo NÃO commitado.

    TCK-2068. Achado numa retomada de sessão: `git status` mostrou as 98 linhas
    do TCK-2060 (`migrations/0001-sqlite-index.py`) e o teste dele **fora do
    repositório**, com o ticket em `done`, RUN escrito e VER `approved`. O
    registro dizia entregue; o código existia só na working tree.

    Medido no mesmo dia: **2 dos 11** designs mais recentes com `scope_files`
    estavam assim, e `transition --to done` não tem uma única referência a git.
    O ciclo verifica artefato de governança e resultado de teste — duas coisas
    reais — e nunca verifica que o diff chegou ao repositório.

    **Por que warning e não bloqueio no `done`:** o fluxo natural aqui é fechar
    o ticket e ENTÃO commitar citando-o (`fix(TCK-NNNN): …` referencia um ticket
    já fechado). Bloquear inverteria a ordem e viraria fricção que se aprende a
    contornar com `--force`; gate contornado por desenho é pior que gate
    ausente. Visível no `cbctl validate` e no CI basta.

    Terceiro estado: sem git, sem design vinculado ou sem `scope_files`, o check
    NÃO opina — ausência de meio de medir não é violação.
    """
    p = paths(root)
    base = Path(p.root)
    if not (base / ".git").exists():
        return _result(
            "done tickets have their code committed",
            True,
            "sem git — não medido (terceiro estado)",
            severity="warning",
        )

    pendentes: list[str] = []
    for ticket in _ticket_files(root):
        fm = _ticket_meta(ticket)
        if str(fm.get("status") or "").strip() != "done":
            continue
        tid = str(fm.get("id", ticket.stem))
        for design in parse_list(fm.get("linked_designs")):
            dpath = next(iter(sorted(Path(p.designs).glob(f"{design}-*.md"))), None)
            if dpath is None:
                continue
            try:
                dfm = parse_frontmatter(dpath.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            declarados = [
                str(f) for k in ("scope_files_new", "scope_files_modified")
                for f in (dfm.get(k) or [])
                if isinstance(f, str) and not f.startswith("(")
            ]
            for rel in declarados:
                alvo = base / rel
                if not alvo.exists():
                    continue
                try:
                    st = subprocess.run(
                        ["git", "-C", str(base), "status", "--porcelain", "--", rel],
                        capture_output=True, text=True, timeout=30,
                    ).stdout.strip()
                except Exception:
                    continue
                if st:
                    pendentes.append(f"{tid} ({design}): {rel} [{st.split()[0]}]")
                    break

    return _result(
        "done tickets have their code committed",
        not pendentes,
        "todo ticket done tem o código no repositório" if not pendentes
        else "; ".join(sorted(set(pendentes))[:8]),
        severity="warning",
    )


def check_all(root: str | Path | None = None) -> list[InvariantResult]:
    results: list[InvariantResult] = [
        check_backlog_csv(root),
        check_skills_mirror(root),
        check_context_index_fresh(root),
        check_stale_raw_tickets(root),
        check_stale_paused_runs(root),
        check_referenced_ticket_ids_resolve(root),
        check_done_tickets_are_committed(root),
    ]
    results.extend(check_ticket_links(root))
    return results


def has_failures(results: Iterable[InvariantResult], *, strict: bool = False) -> bool:
    for result in results:
        if result.ok:
            continue
        if strict or result.severity == "error":
            return True
    return False
