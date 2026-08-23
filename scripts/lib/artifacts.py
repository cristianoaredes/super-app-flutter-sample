#!/usr/bin/env python3
"""Atomic artifact operations for designs, ADRs, runs, and verify reports."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import time
from typing import Any

from lib.frontmatter import parse_frontmatter
from lib.ids import (
    id_lock,
    next_adr_id_unlocked,
    next_design_id_unlocked,
)
from lib.paths import paths
from lib.ticket import render_document, slugify, utc_now


class ArtifactError(RuntimeError):
    """Base error for governed artifact operations."""


DESIGN_RE = re.compile(r"^DES-\d{4}$")
TICKET_RE = re.compile(r"^TCK-\d{4}([a-z]\d*)?$")
ADR_RE = re.compile(r"^ADR-\d{4}$")
RUN_RE = re.compile(r"^RUN-\d{8}-\d{6}-[a-z0-9-]+$")
VERIFY_VERDICTS = frozenset(
    {"approved", "approved-with-notes", "rejected", "rejected-rollback-recommended"}
)
GATE_STATUSES = frozenset(
    {
        "flow",
        "paused-safety",
        "paused-evidence",
        "paused-scope",
        "paused-context",
        "paused-budget",
        "paused-prod",
        "paused-secret",
        "failed-fatal",
        "completed",
    }
)


@dataclass
class ArtifactOperationResult:
    artifact_id: str
    path: Path
    changed: bool
    dry_run: bool
    metadata: dict[str, Any]

    def as_dict(self) -> dict[str, Any]:
        return {
            "artifact_id": self.artifact_id,
            "path": str(self.path),
            "changed": self.changed,
            "dry_run": self.dry_run,
            "metadata": self.metadata,
        }


def atomic_write(path: Path, text: str, *, overwrite: bool = False) -> None:
    """Write text atomically, optionally refusing to overwrite existing files."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            delete=False,
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
        ) as fh:
            tmp_path = Path(fh.name)
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        if overwrite:
            os.replace(tmp_path, path)
        else:
            os.link(tmp_path, path)
            tmp_path.unlink()
        tmp_path = None
    except FileExistsError as exc:
        raise ArtifactError(f"artifact already exists: {path}") from exc
    finally:
        if tmp_path is not None:
            tmp_path.unlink(missing_ok=True)


def _find_one(pattern: str, directory: Path, artifact_id: str) -> Path:
    matches = sorted(directory.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"artifact not found: {artifact_id}")
    if len(matches) > 1:
        raise ArtifactError(f"multiple artifacts found for {artifact_id}: {matches}")
    return matches[0]


def _artifact_search_dirs(prefix: str, root, include_archive: bool) -> list:
    """Canonical dir(s) for an artifact PREFIX (+ archive twin when include_archive).
    The single place the prefix->dir map lives (F0.7-T5)."""
    P = paths(root)
    arch = P.archive
    inc = P.archagents / "12-inception"
    arch_inc = arch / "12-inception"
    primary = {
        "TCK": [P.tickets],
        "DES": [P.designs],
        "ADR": [P.decisions],
        "SPC": [inc / "specs"],
        "PLN": [inc / "plans"],
        "BRF": [inc / "briefs"],
        "DSC": [inc / "discoveries"],
        "FND": [P.archagents / "11-assessment"],
    }
    archived = {
        "TCK": [arch / "15-backlog" / "tickets"],
        "DES": [arch / "16-designs"],
        "ADR": [arch / "09-decisions"],
        "SPC": [arch_inc / "specs"],
        "PLN": [arch_inc / "plans"],
        "BRF": [arch_inc / "briefs"],
        "DSC": [arch_inc / "discoveries"],
        "FND": [arch / "11-assessment"],
    }
    dirs = list(primary.get(prefix, []))
    if include_archive:
        dirs += archived.get(prefix, [])
    return dirs


def resolve_artifact(prefix: str, artifact_id: str | Path,
                     root: str | Path | None = None,
                     include_archive: bool = True) -> Path:
    """SPC-0037/F0.7-T5: the single id->path resolver for ``PREFIX-NNNN`` artifacts.

    Searches the canonical dir(s) for ``prefix`` (plus the archive twin when
    ``include_archive``), matching ``{artifact_id}-*.md``. Built on the same
    contract as _find_one: FileNotFoundError on miss, ArtifactError on ambiguity
    (>1 distinct match). An ``artifact_id`` that is already an existing file path
    passes through unchanged (mirrors the find_*_path call sites)."""
    candidate = Path(artifact_id)
    if candidate.exists() and candidate.is_file():
        return candidate
    dirs = _artifact_search_dirs(prefix, root, include_archive)
    matches: list[Path] = []
    for d in dirs:
        d = Path(d)
        if d.is_dir():
            for m in sorted(d.glob(f"{artifact_id}-*.md")):
                # TCK-0671: clarify sidecars (*-questions.md) are not canonical artifacts.
                if m.stem.endswith("-questions"):
                    continue
                matches.append(m)
    uniq: list[Path] = []
    for m in matches:
        if m not in uniq:
            uniq.append(m)
    if not uniq:
        raise FileNotFoundError(f"artifact not found: {artifact_id}")
    if len(uniq) > 1:
        raise ArtifactError(f"multiple artifacts found for {artifact_id}: {uniq}")
    return uniq[0]


def find_design_path(design: str | Path, root: str | Path | None = None) -> Path:
    candidate = Path(design)
    if candidate.exists():
        return candidate
    return _find_one(f"{design}-*.md", paths(root).designs, str(design))


def find_adr_path(adr: str | Path, root: str | Path | None = None) -> Path:
    candidate = Path(adr)
    if candidate.exists():
        return candidate
    return _find_one(f"{adr}-*.md", paths(root).decisions, str(adr))


def find_run_dir(run: str | Path, root: str | Path | None = None) -> Path:
    candidate = Path(run)
    if candidate.exists():
        return candidate
    run_dir = paths(root).runs / str(run)
    if not run_dir.exists():
        raise FileNotFoundError(f"run not found: {run}")
    return run_dir


def read_frontmatter(path: Path) -> dict[str, Any]:
    return parse_frontmatter(path.read_text(encoding="utf-8"))


def create_design(
    *,
    ticket: str,
    title: str,
    status: str = "draft",
    acceptance_delta: str | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    _require_ticket_id(ticket)
    # TCK-2156 (DES-1052): a marca de reconciliação aceite↔design. Opcional na
    # lib (compat com callers); o CLI governado a EXIGE, e o gate na transição
    # designed→executing bloqueia DES novo sem ela.
    if acceptance_delta is not None:
        from lib.acceptance_delta import VALORES_VALIDOS
        if acceptance_delta not in VALORES_VALIDOS:
            raise ArtifactError(
                f"acceptance_delta inválido: {acceptance_delta!r} — vocabulário "
                f"é {'|'.join(VALORES_VALIDOS)}")
    slug = slugify(title)
    timestamp = utc_now()
    p = paths(root)
    if dry_run:
        design_id = next_design_id_unlocked(root=root)
        design_path = p.designs / f"{design_id}-{slug}.md"
    else:
        with id_lock(root):
            design_id = next_design_id_unlocked(root=root)
            design_path = p.designs / f"{design_id}-{slug}.md"
            metadata, body = _design_payload(
                design_id, slug, title, ticket, status, timestamp,
                acceptance_delta=acceptance_delta)
            atomic_write(design_path, render_document(metadata, body), overwrite=False)
            return ArtifactOperationResult(design_id, design_path, True, False, metadata)
    metadata, _body = _design_payload(
        design_id, slug, title, ticket, status, timestamp,
        acceptance_delta=acceptance_delta)
    return ArtifactOperationResult(design_id, design_path, True, True, metadata)


def _design_payload(
    design_id: str, slug: str, title: str, ticket: str, status: str, timestamp: str,
    *, acceptance_delta: str | None = None,
) -> tuple[dict[str, Any], str]:
    metadata: dict[str, Any] = {
        "id": design_id,
        "slug": slug,
        "title": title,
        "ticket": ticket,
        "status": status,
        "type": "design",
        "created_at": timestamp,
        "scope_files_new": [],
        "scope_files_modified": [],
        "scope_files_deleted": [],
        "blast_radius": "low",
        "playbook": f".archagents/16-designs/playbooks/{design_id}-playbook.md",
    }
    if acceptance_delta is not None:
        # TCK-2156: declarado na origem; o gate designed→executing o exige
        metadata["acceptance_delta"] = acceptance_delta
    body = (
        f"# {design_id} - {title}\n\n"
        "## Problema\n\n"
        f"Design criado para {ticket}. Complete a decisao antes do Execute.\n\n"
        "## Solucao\n\n"
        "- A definir.\n\n"
        "## Mudancas\n\n"
        "- A definir.\n\n"
        "## Criterios de sucesso\n\n"
        "- [ ] Criterios do ticket passam.\n"
    )
    return metadata, body


def create_playbook(
    *,
    design: str,
    ticket: str,
    title: str,
    total_steps: int,
    status: str = "draft",
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    _require_design_id(design)
    _require_ticket_id(ticket)
    if total_steps < 0:
        raise ArtifactError("total_steps must be non-negative")
    timestamp = utc_now()
    playbook_path = paths(root).playbooks / f"{design}-playbook.md"
    metadata: dict[str, Any] = {
        "id": f"{design}-playbook",
        "design": design,
        "ticket": ticket,
        "created_at": timestamp,
        "status": status,
        "approved_at": timestamp if status == "approved" else None,
        "approved_by": "codex" if status == "approved" else None,
        "executed_at": None,
        "executed_runs": [],
        "dry_run_supported": True,
        "total_steps": total_steps,
        "destructive_steps": 0,
        "environments": ["dev"],
        "estimated_duration": "30min-2h",
        "branch_prefix": "ops/",
        "branch_name": f"ops/{ticket}-{slugify(title)}",
        "commit_per_step": False,
        "commit_message_format": f"[{ticket}] passo N/{total_steps}: <titulo>",
    }
    body = (
        f"# Playbook - {design}\n\n"
        f"**Ticket:** {ticket}\n"
        f"**Objetivo:** {title}\n\n"
        "## Pre-requisitos\n\n"
        "- [ ] Worktree revisada para evitar colisao com mudancas existentes.\n\n"
        "## Modo dry-run\n\n"
        f"`/ops-execute {design} --dry-run`\n\n"
        "## Passos\n\n"
        "Detalhar passos antes de executar mudancas reais.\n\n"
        "## Criterios de sucesso do playbook\n\n"
        "- [ ] Acceptance do ticket passa.\n"
        "- [ ] Suite relevante passa.\n\n"
        "## Log de execucoes\n\n"
        "- *(sem execucoes ainda)*\n"
    )
    if not dry_run:
        atomic_write(playbook_path, render_document(metadata, body), overwrite=False)
    return ArtifactOperationResult(f"{design}-playbook", playbook_path, True, dry_run, metadata)


def create_adr(
    *,
    title: str,
    status: str = "proposed",
    ticket: str | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    if ticket:
        _require_ticket_id(ticket)
    slug = slugify(title)
    date = datetime.now(timezone.utc).date().isoformat()
    p = paths(root)
    if dry_run:
        adr_id = next_adr_id_unlocked(root=root)
        adr_path = p.decisions / f"{adr_id}-{slug}.md"
    else:
        with id_lock(root):
            adr_id = next_adr_id_unlocked(root=root)
            adr_path = p.decisions / f"{adr_id}-{slug}.md"
            metadata, body = _adr_payload(adr_id, title, status, date, ticket)
            atomic_write(adr_path, render_document(metadata, body), overwrite=False)
            return ArtifactOperationResult(adr_id, adr_path, True, False, metadata)
    metadata, _body = _adr_payload(adr_id, title, status, date, ticket)
    return ArtifactOperationResult(adr_id, adr_path, True, True, metadata)


def _adr_payload(
    adr_id: str, title: str, status: str, date: str, ticket: str | None
) -> tuple[dict[str, Any], str]:
    metadata: dict[str, Any] = {
        "id": adr_id,
        "title": title,
        "status": status,
        "date": date,
        "deciders": "codex",
        "tickets": [ticket] if ticket else [],
        "supersedes": [],
    }
    body = (
        f"# {adr_id} - {title}\n\n"
        "## Contexto\n\n"
        "A preencher antes da aceitacao.\n\n"
        "## Decisao\n\n"
        "A preencher.\n\n"
        "## Alternativas descartadas\n\n"
        "- A preencher.\n\n"
        "## Consequencias\n\n"
        "- A preencher.\n"
    )
    return metadata, body


def create_lineage_run(ticket: str, root=None, *, reason: str = "") -> "str | None":
    """RUN mínimo de LINHAGEM para ticket que fechou sem execução (TCK-2231).

    Medido em 2026-08-09: **85 de 302** tickets `done` (28%) não têm RUN — bug
    20, devex 20, architecture 9. O loop mede runs, então esse trabalho era
    invisível para `loop_quality`, para o judge e para a utilidade de lição.

    Isto NÃO é defeito de quem fechou: ticket leve fecha pelo criteria gate por
    desenho (`spec-driven-run/no-DES-schema-gap`). O que faltava era reconciliar
    o desenho com a métrica.

    O artefato DECLARA o que é (`run_format: "lineage"`), na mesma disciplina do
    TCK-2207: registro que não se disfarça de verificação. O agregador o EXCLUI
    do denominador de qualidade — não exerceu o loop — e o INCLUI na cobertura.

    Devolve o id, ou `None` se não deu para criar (nunca levanta: um ticket que
    não fecha por causa da linhagem é pior que um ticket sem linhagem).
    """
    import json as _json
    import sys as _s
    from datetime import datetime, timezone
    try:
        base = Path(root) if root else Path.cwd()
        agora = datetime.now(timezone.utc)
        rid = f"RUN-{agora.strftime('%Y%m%d-%H%M%S')}-{ticket.lower()}-lineage"
        d = base / ".archagents" / "13-execution" / "runs" / rid
        if d.exists():
            return None
        d.mkdir(parents=True)
        (d / "run.json").write_text(_json.dumps({
            "id": rid, "ticket": ticket, "design": "", "status": "completed",
            "environment": "dev", "mode": "lineage",
            "started_at": agora.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "ended_at": agora.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "current_step": 1, "total_steps": 1,
            "run_format": "lineage",
            "_comment": ("TCK-2231: LINHAGEM, nao execucao. O ticket fechou pelo "
                         "criteria gate sem RUN de execucao; este artefato existe "
                         "para o trabalho nao ser invisivel ao loop. Fica FORA do "
                         "denominador de loop_quality (nao exerceu o loop) e "
                         "DENTRO da cobertura."),
            "reason": reason or "ticket fechou pelo criteria gate, sem execucao",
            "lessons_consulted": _consultar_licoes(ticket, base),
            "loop_iterations": 0, "attempt_count": 0, "loop_cost_usd": 0.0,
            "loop_strategy": "none", "context_peak": 0,
            "final_judge_delta": None, "final_judge_delta_source": "",
        }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (d / "REPORT.md").write_text(
            f"---\nstatus: completed\nrun_id: {rid}\nticket: {ticket}\n"
            f"design: \nstart_time: {agora.strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
            f"end_time: {agora.strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
            f"environment: dev\nmode: lineage\noperator: ops\ncommits: []\n"
            f"files_modified: []\ntest_result:\n  status: pass\n"
            f"  summary: \"criteria gate\"\n---\n"
            f"# RUN (linhagem) — {ticket}\n\n"
            f"Este RUN registra LINHAGEM, nao execucao. O ticket fechou pelo\n"
            f"criteria gate sem run de execucao (comportamento por desenho para\n"
            f"ticket leve). O artefato existe para que o trabalho nao seja\n"
            f"invisivel ao loop — 28% dos `done` estavam nessa condicao.\n\n"
            f"Fica FORA do denominador de `loop_quality` e DENTRO da cobertura.\n",
            encoding="utf-8")
        return rid
    except OSError as e:
        print(f"[codebase-ops] AVISO: nao consegui criar RUN de linhagem "
              f"para {ticket} ({e}) — o trabalho segue invisivel ao loop.",
              file=_s.stderr)
        return None


def _titulo_do_ticket(ticket: str, root) -> "str | None":
    """Título do ticket, para o rank do retrieval (TCK-1945). None se não achar —
    a consulta degrada para banner, e isso é declarado no aviso."""
    try:
        base = Path(root) if root else Path.cwd()
        d = base / ".archagents" / "15-backlog" / "tickets"
        for f in d.glob(f"{ticket}-*.md"):
            for linha in f.read_text(encoding="utf-8", errors="replace").splitlines()[:20]:
                if linha.startswith("title:"):
                    return linha.split(":", 1)[1].strip().strip('"')
        return None
    except OSError:
        return None


def _consultar_licoes(ticket: str, root) -> list:
    """Lições relevantes ao ticket, no nascimento do RUN (TCK-2230).

    Terceiro estado DECLARADO: falha de consulta grava `[]` **e avisa**. Sem o
    aviso, "não havia lição relevante" e "não consegui consultar" produzem o
    mesmo registro — que é exatamente o estado que este ticket veio corrigir,
    e a classe `measurement-failure-becomes-finding`.
    """
    import sys as _s
    try:
        from lib.lesson_channel import consult_lessons_with_fallback
    except ImportError as e:
        print(f"[codebase-ops] AVISO: canal de lições indisponível ({e}) — "
              f"o RUN nasce SEM consulta (não é 'sem lição relevante').",
              file=_s.stderr)
        return []
    try:
        # `title_hint` NÃO é opcional: sem ele a consulta devolve o MESMO
        # conjunto para todo ticket — 3 conjuntos distintos em 40 tickets contra
        # 14 com o hint. É o banner que o TCK-1945 fechou ("não era retrieval,
        # era um banner… dado fabricado virando evidência — a classe do
        # ADR-0029"). Os dois produtores canônicos passam o hint; este nascia
        # sem, e alimentaria o denominador com lição que não tinha como ajudar.
        out = consult_lessons_with_fallback(ticket, root=root, limit=3,
                                            title_hint=_titulo_do_ticket(ticket, root))
    except Exception as e:      # noqa: BLE001 — consulta nunca derruba o create
        print(f"[codebase-ops] AVISO: consulta de lições falhou ({e}) — "
              f"o RUN nasce SEM consulta (não é 'sem lição relevante').",
              file=_s.stderr)
        return []
    if out.get("error"):
        print(f"[codebase-ops] AVISO: consulta de lições degradada "
              f"({out['error']}) — o registro pode estar incompleto.",
              file=_s.stderr)
    licoes = out.get("lessons") or []
    return [str(l.get("text") or l.get("lesson") or l)[:80] if isinstance(l, dict)
            else str(l)[:80] for l in licoes]


def create_run(
    *,
    ticket: str,
    design: str,
    slug: str,
    total_steps: int,
    environment: str = "dev",
    mode: str = "dry-run",
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    _require_ticket_id(ticket)
    _require_design_id(design)
    if total_steps < 0:
        raise ArtifactError("total_steps must be non-negative")
    if environment not in {"dev", "staging", "prod-prep"}:
        raise ArtifactError(f"invalid environment: {environment}")
    if mode not in {"dry-run", "live", "hotfix", "resume"}:
        raise ArtifactError(f"invalid mode: {mode}")
    run_id = _next_run_id(slug, root=root)
    run_dir = paths(root).runs / run_id
    timestamp = utc_now()
    metadata: dict[str, Any] = {
        "id": run_id,
        "design": design,
        "ticket": ticket,
        "started_at": timestamp,
        "started_by": "ops",
        "environment": environment,
        "mode": mode,
        "status": "running",
        "current_step": 0,
        "total_steps": total_steps,
        "ended_at": None,
        "result": None,
        # Loop telemetry seed (SPC-0028 unit 1) — always present contract
        "loop_iterations": 0,
        "attempt_count": 0,
        # TCK-2230: era `[]` HARDCODED. Medido em 2026-08-09 sobre 222 runs:
        # judge e lições são fluxos DISJUNTOS — 112 runs com lição sem judge,
        # 25 com judge sem lição, e apenas **9** com ambos. Como o denominador
        # de `lesson_utility` exige os dois, a saúde do loop repousava sobre 9
        # medições em vez de 121.
        #
        # A causa: o `pipeline-orchestrator` chama `consult_lessons`; o caminho
        # do agente do harness (`cbctl run create` -> aqui) nascia cego. E é o
        # caminho DOMINANTE. Os dois runs fechados em 2026-08-09 provam:
        # `judge='judge'` com `licoes=[]`.
        #
        # Fonte única: `lesson_channel.consult_lessons_with_fallback`, o mesmo
        # que o orquestrador usa. Segunda implementação divergiria pela unidade
        # (TCK-1860, TCK-2178).
        "lessons_consulted": _consultar_licoes(ticket, root),
        "loop_cost_usd": 0.0,
        "loop_strategy": "default",
        "context_peak": 0,
        "final_judge_delta": 0,
    }
    if not dry_run:
        try:
            run_dir.mkdir(parents=True, exist_ok=False)
            (run_dir / "diffs").mkdir()
            (run_dir / "stdout").mkdir()
            atomic_write(run_dir / "run.json", json.dumps(metadata, indent=2) + "\n", overwrite=False)
            atomic_write(run_dir / "actions.jsonl", "", overwrite=False)
            atomic_write(
                run_dir / "REPORT.md",
                _run_report(run_id, ticket, design, timestamp, environment, mode),
                overwrite=False,
            )
        except Exception:
            if run_dir.exists():
                shutil.rmtree(run_dir)
            raise
    return ArtifactOperationResult(run_id, run_dir, True, dry_run, metadata)


def _next_run_id(slug: str, root: str | Path | None = None) -> str:
    clean_slug = slugify(slug)
    with id_lock(root):
        while True:
            ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
            run_id = f"RUN-{ts}-{clean_slug}"
            if not (paths(root).runs / run_id).exists():
                return run_id
            time.sleep(1.0)


def _run_report(
    run_id: str, ticket: str, design: str, timestamp: str, environment: str, mode: str
) -> str:
    metadata: dict[str, Any] = {
        "run_id": run_id,
        "ticket": ticket,
        "design": design,
        "status": "running",
        "start_time": timestamp,
        "end_time": None,
        "environment": environment,
        "mode": mode,
        "operator": "ops",
        "commits": [],
        "files_modified": [],
        "test_result": {"status": None, "summary": "", "details": ""},
    }
    body = (
        f"# {run_id} - {ticket}\n\n"
        "## Resumo executivo\n\n"
        "Run criado por scripts/ops/run/create.py.\n\n"
        "## Evidence Gate\n\n"
        "| Check | Esperado | Obtido | Status |\n"
        "|---|---|---|---|\n"
    )
    return render_document(metadata, body)


def append_action(
    run: str | Path,
    *,
    step: int,
    action: str,
    gate_status: str,
    files: list[str] | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    if step < 0:
        raise ArtifactError("step must be non-negative")
    if gate_status not in GATE_STATUSES:
        raise ArtifactError(f"invalid gate_status: {gate_status}")
    for file_name in files or []:
        file_path = Path(file_name)
        if file_path.is_absolute() or ".." in file_path.parts:
            raise ArtifactError(f"files must be repo-relative safe paths: {file_name}")
    run_dir = find_run_dir(run, root=root)
    run_json = run_dir / "run.json"
    if not run_json.exists():
        raise ArtifactError(f"missing run.json: {run_json}")
    metadata = json.loads(run_json.read_text(encoding="utf-8"))
    entry = {
        "ts": utc_now(),
        "step": step,
        "type": "action",
        "action": action,
        "gate_status": gate_status,
        "files": files or [],
    }
    if not dry_run:
        with (run_dir / "actions.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")
        if isinstance(metadata.get("current_step"), int):
            metadata["current_step"] = max(metadata["current_step"], step)
            atomic_write(run_json, json.dumps(metadata, indent=2) + "\n", overwrite=True)
    return ArtifactOperationResult(str(metadata.get("id", run_dir.name)), run_dir / "actions.jsonl", True, dry_run, entry)


def create_verify_report(
    *,
    run: str,
    verdict: str,
    verified_by: str | None = None,
    verify_context: str | None = None,
    ticket_esperado: str | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
) -> ArtifactOperationResult:
    if verdict == "rejected":
        verdict = "rejected-rollback-recommended"
    if verdict not in VERIFY_VERDICTS:
        raise ArtifactError(f"invalid verdict: {verdict}")
    run_dir = find_run_dir(run, root=root)
    run_json = run_dir / "run.json"
    if run_json.exists():
        run_meta = json.loads(run_json.read_text(encoding="utf-8"))
    else:
        report = run_dir / "REPORT.md"
        run_meta = read_frontmatter(report) if report.exists() else {}
    # TCK-2127 (DES-1046): P10 bloqueante na ORIGEM. O default antigo
    # (`verified_by: "ops"`, hardcoded) produziu 92% de VERs auto-assinados —
    # o prompt do VERIFY.md mandava subagente fresco e o tool nem sabia
    # expressar isso. Agora: identidade obrigatória e DIFERENTE do operator
    # do RUN. Quem verifica não pode ser quem executou.
    if not (verified_by or "").strip():
        raise ArtifactError(
            "verified_by obrigatório (P10/DES-1046): informe a identidade do "
            "verificador — ex.: subagent-fresh-context. Quem executou não pode "
            "assinar o próprio verify.")
    run_operator = str(run_meta.get("operator") or "").strip()
    if run_operator and verified_by.strip().lower() == run_operator.lower():
        raise ArtifactError(
            f"P10 (DES-1046): verified_by={verified_by!r} é o mesmo operator do "
            f"RUN ({run_operator!r}) — auto-verify recusado. Spawne um "
            f"verificador de contexto fresco (só artefatos do run) e assine com "
            f"a identidade dele.")
    ticket = str(run_meta.get("ticket", ""))
    # TCK-2476: o `ticket` do VER é DERIVADO do run, então passar `--run` de
    # outro ticket produz um VER com o ticket errado — em silêncio. Foi assim
    # que 81 VERs de uma campanha em lote acabaram citando
    # `RUN-TCK-0001e-kiro-research` (run de OUTRO ticket, usado como
    # placeholder): os checks rodaram de verdade, mas a procedência ficou
    # irrastreável, e o gate P10 os classificou como "sem procedência",
    # engordando o baseline por dívida de SCHEMA, não de independência.
    if ticket_esperado and ticket and ticket_esperado.strip() != ticket:
        raise ArtifactError(
            f"TCK-2476: o RUN {run_dir.name} pertence a {ticket!r}, mas o VER "
            f"foi pedido para {ticket_esperado!r}. Um VER não pode citar run de "
            f"outro ticket — a procedência da verificação fica irrastreável. "
            f"Use o run do próprio ticket, ou crie um run de linhagem.")
    design = str(run_meta.get("design", ""))
    slug = slugify(ticket or run)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    ver_id = f"VER-{timestamp}-{slug}"
    report_path = paths(root).verify_reports / f"{ver_id}.md"
    # Verification reports need sub-second precision because ticket transition
    # logs intentionally use second precision. Without the fractional part, a
    # report created immediately after `executing` can look simultaneous and be
    # rejected as stale by the trust ratchet.
    report_timestamp = (
        datetime.now(timezone.utc)
        .isoformat(timespec="microseconds")
        .replace("+00:00", "Z")
    )
    metadata: dict[str, Any] = {
        "id": ver_id,
        "run": run_dir.name,
        "design": design,
        "ticket": ticket,
        "created_at": report_timestamp,
        "verified_at": report_timestamp,
        "verified_by": verified_by.strip(),
        "verdict": verdict,
    }
    if verify_context:
        metadata["verify_context"] = verify_context
    # TCK-2207 (2ª rodada do verify): a v1 fez o produtor escrever um bloco de
    # LIMITES fixo para "consertar" os 32 testes que o gate estendido derrubou.
    # Isso foi errado por dois motivos que o verificador provou:
    #
    #   1. placeholder por CONSTRUÇÃO — texto fixo do gerador satisfazendo o
    #      predicado é exatamente `fixture-que-satisfaz-o-predicado`, a classe
    #      que este ticket nomeia. O predicado deixou de discriminar caminho
    #      automático de verificação real.
    #   2. regressão P9 — sumir com "Relatorio criado por" matou o STUB_MARKER,
    #      e um VER `approved` cru, que ERA bloqueado desde o TCK-1350, passou.
    #
    # O produtor volta a NÃO satisfazer a régua, de propósito: ele registra
    # linhagem RUN→VER, e linhagem não é verificação. O corpo diz isso em voz
    # alta e mantém o marcador que o gate reconhece. Quem verificar de fato
    # SUBSTITUI este corpo — e é aí que o ticket fecha.
    body = (
        f"# Verify Report - {ver_id}\n\n"
        f"**Run:** {run_dir.name}\n"
        f"**Design:** {design}\n"
        f"**Ticket:** {ticket}\n\n"
        "## Sumario executivo\n\n"
        "Relatorio criado por scripts/ops/verify/create_report.py.\n\n"
        # O texto abaixo e DELIBERADAMENTE curto e sem as palavras que a regua
        # procura. A 1a versao dizia "substitua pelo que voce mediu e pelo que
        # NAO mediu" — e o proprio "NAO mediu" satisfazia o predicado de
        # limites, fazendo o VER cru passar. O gerador nao pode conter a frase
        # que ele existe para exigir de um humano.
        "Preencha este corpo com o resultado da verificacao antes de fechar o\n"
        "ticket: `core/06-verify/VERIFY.md` descreve o que a regua espera.\n\n"
        f"## Veredito: {verdict.upper()}\n"
    )
    if not dry_run:
        atomic_write(report_path, render_document(metadata, body), overwrite=False)
        # TCK-1234: close applied-loop on VER approved path (agent-driven /
        # cbctl verify) — same reinforcement as pipeline-orchestrator post-judge.
        # Fail-open: never blocks report creation.
        if verdict in ("approved", "approved-with-notes") and run_json.exists():
            try:
                from lib.db import mark_lessons_applied
                consulted = run_meta.get("lessons_consulted") or []
                if isinstance(consulted, list) and consulted:
                    mark_lessons_applied(
                        [str(c) for c in consulted],
                        run_id=run_dir.name,
                        success=True,
                        root=root,
                    )
            except Exception:
                pass
            # TCK-1235: criteria-proxy final_judge_delta when no real judge
            # measurement exists — grows outcome cohort for lesson utility
            # without inventing a full judge score. Source is explicit.
            try:
                _stamp_criteria_proxy_delta(
                    run_dir, run_meta, verdict=verdict, ticket=ticket, root=root)
            except Exception:
                pass
    return ArtifactOperationResult(ver_id, report_path, True, dry_run, metadata)


def _stamp_criteria_proxy_delta(
    run_dir: Path,
    run_meta: dict[str, Any],
    *,
    verdict: str,
    ticket: str,
    root: str | Path | None,
) -> None:
    """TCK-1235: if final_judge_delta unmeasured, stamp from VER + criteria.

    Mapping (explicit source ``criteria-proxy``, never pretends to be judge):
      - approved + criteria pass → delta 25 (score 75, utility 0.5 target)
      - approved-with-notes + criteria pass → delta 15
      - criteria fail / unavailable → leave unmeasured
    Does not overwrite judge/orchestrator sources.
    """
    from lib.lesson_utility import compute_lesson_utility, _has_measured_judge_delta  # type: ignore

    if _has_measured_judge_delta(run_meta):
        return
    src = str(run_meta.get("final_judge_delta_source") or "")
    if src in ("judge", "orchestrator", "escalation", "criteria-proxy"):
        return

    # Prefer live criteria-check when ticket known
    criteria_ok = False
    repo_root = paths(root).root
    if ticket and TICKET_RE.match(ticket):
        try:
            import subprocess
            import sys
            proc = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).resolve().parents[1] / "criteria-check.py"),
                    "--ticket", ticket,
                    "--root", str(repo_root),
                ],
                cwd=str(repo_root),
                capture_output=True, text=True, timeout=120,
            )
            criteria_ok = proc.returncode == 0
        except Exception:
            criteria_ok = False
    else:
        criteria_ok = verdict == "approved"

    if not criteria_ok:
        return

    delta = 25.0 if verdict == "approved" else 15.0
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8")) if rj.exists() else dict(run_meta)
    except (OSError, ValueError, json.JSONDecodeError):
        return
    if not isinstance(data, dict):
        return
    data["final_judge_delta"] = delta
    data["final_judge_delta_source"] = "criteria-proxy"
    try:
        data["lesson_utility"] = compute_lesson_utility(data)
    except Exception:
        pass
    try:
        rj.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    except OSError:
        return


def _require_ticket_id(ticket: str) -> None:
    if not TICKET_RE.match(ticket):
        raise ArtifactError(f"invalid ticket id: {ticket}")


def _require_design_id(design: str) -> None:
    if not DESIGN_RE.match(design):
        raise ArtifactError(f"invalid design id: {design}")
