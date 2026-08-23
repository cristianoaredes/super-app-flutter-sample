#!/usr/bin/env python3
"""handoff.py — validador único de contratos de transição (TCK-1190 / PLN-0017 D2).

O check mecânico que um orquestrador roda ANTES de passar um ticket entre
agentes/fases. Cada transição de fase tem um contrato de artefatos; antes os
checks viviam espalhados (DoR greps, existência de playbook, criteria-lock,
frescor de VER). Este módulo unifica todos num só lugar:

    raw       -> triaged    severity+category+effort set; acceptance[] para
                            tickets de código (ou waiver); sem campos desconhecidos
    triaged   -> designed   linked_designs não-vazio; DES existe com status
                            approved + scope_files set
    designed  -> executing  playbook existe; branch policy sã (git-flow);
                            nenhum passo destrutivo sem flag de aprovação
    executing -> verifying  run dir com REPORT.md + actions.jsonl;
                            acceptance-check executável
    verifying -> done       VER fresco + vinculado (catraca SPC-0058 — reusa
                            lib/ticket.py, não duplica); acceptance-lock verde
    paused-*  -> executing  contrato de designed->executing + evidência de run
                            anterior para retomar

Cada check retorna ``{"ok": bool, "failures": [str]}``. READ-ONLY: nunca muta
ticket, lock, run ou git — safe para dry-run em qualquer nível de autonomia.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path
from typing import Any, Callable

from lib.acceptancelock import count_active_worktrees, read_lock
from lib.dependencies import (
    dependency_failures,
    evaluate_ticket_dependencies,
    is_progress_status,
)
from lib.paths import paths
from lib.readiness_events import emit_readiness_event
from lib.runstate import ALL_PAUSED_STATUSES
from lib import ticket as ticket_lib

# ---------------------------------------------------------------------------
# Constantes do contrato
# ---------------------------------------------------------------------------

# Campos conhecidos do frontmatter de ticket: ordem canônica + campos que o
# ciclo grava fora da ordem (catraca, épicos, waiver).
KNOWN_TICKET_FIELDS = frozenset(
    set(ticket_lib.TICKET_FIELD_ORDER)
    | {
        "children",
        "acceptance_waiver",
        "forced_past_ver_gate",
        "ver_pending_hotfix",
        # O que o próprio método manda escrever no TCK compilado de SPC
        # (core/00-inception/INCEPTION.md §compilação: `linked_spec`,
        # `security_sensitive` propagado). O kernel não pode mandar e rejeitar
        # ao mesmo tempo — medido: 64/64 tickets abertos de um consumidor
        # reprovavam raw→triaged (deep-codebase-ops, TCK-0127).
        "linked_spec",
        "security_sensitive",
    }
)

VALID_EFFORTS = frozenset({"XS", "S", "M", "L", "XL"})

# Categorias que NÃO exigem acceptance[] no triage (não-code tickets).
NON_CODE_CATEGORIES = frozenset({"docs", "research"})

# Git-flow (DES-0192/TCK-0209) — prefixos de branch válidos para executar.
GIT_FLOW_PREFIXES = ("feature/", "bugfix/", "chore/", "hotfix/")

# Próximo handoff "para frente" por status — usado por `handoff check --all`.
NEXT_HANDOFF: dict[str, str] = {
    "raw": "triaged",
    "triaged": "designed",
    "designed": "executing",
    "executing": "verifying",
    "verifying": "done",
}
for _paused in ALL_PAUSED_STATUSES:
    NEXT_HANDOFF[_paused] = "executing"

CheckFn = Callable[[ticket_lib.TicketDocument, Path], list[str]]

# ---------------------------------------------------------------------------
# Autonomy ratchet wiring (TCK-1223 / PLN-0017 D5)
# ---------------------------------------------------------------------------

# Stage do pipeline -> classe de decisão do autonomy ratchet
# (lib/autonomy_ratchet.CLASSES). O driver consulta ANTES do trabalho de cada
# estágio: classe `promoted` flui sem gate; gated/probation seguem o nível de
# autonomia corrente (L0/L1 stop, L2/L3 flow — semântica de check_gate).
STAGE_RATCHET_CLASSES: dict[str, str] = {
    "raw": "triage",
    "triaged": "design-approval",
    "designed": "execute-scoped",
    "executing": "execute-scoped",
    "verifying": "judge-verdict",
    "done": "ship-readiness",  # ship-ish: verifying->done é o gate de ship do driver
}


def ratchet_gate_for_stage(
    stage: str,
    *,
    level: str = "L2",
    root: str | Path | None = None,
) -> dict[str, Any]:
    """Consulta FAIL-OPEN ao autonomy ratchet para um estágio do pipeline.

    Retorna ``{"stage", "classe", "gate": "flow"|"stop", "note"}``. Qualquer
    erro na consulta (import, store, classe desconhecida, stage sem mapeamento)
    degrada para ``gate="flow"`` + nota — o ratchet NUNCA hard-bloqueia por
    falha dele mesmo; o comportamento atual (nível de autonomia) prevalece.
    """
    classe = STAGE_RATCHET_CLASSES.get(str(stage or "").strip())
    out: dict[str, Any] = {"stage": stage, "classe": classe, "gate": "flow", "note": ""}
    if not classe:
        out["note"] = f"stage {stage!r} sem classe de ratchet mapeada (fail-open)"
        return out
    try:
        from lib import autonomy_ratchet

        gate = autonomy_ratchet.check_gate(classe, level=level, root=root)
        out["gate"] = gate if gate in ("flow", "stop") else "flow"
    except Exception as exc:  # fail-open: erro do ratchet nunca bloqueia
        out["note"] = f"ratchet consult failed (fail-open): {exc}"
    return out


def _ok(failures: list[str]) -> dict[str, Any]:
    return {"ok": not failures, "failures": failures}


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _non_empty(value: Any) -> bool:
    return bool(str(value or "").strip())


# ---------------------------------------------------------------------------
# raw -> triaged
# ---------------------------------------------------------------------------

def _check_triage_fields(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    fm = doc.frontmatter
    failures: list[str] = []
    for field in ("severity", "category"):
        if not _non_empty(fm.get(field)):
            failures.append(f"triage: campo obrigatório ausente/vazio: {field}")
    effort = str(fm.get("effort") or "").strip().upper()
    if effort not in VALID_EFFORTS:
        failures.append(
            f"triage: effort inválido/ausente: {fm.get('effort')!r} "
            f"(válidos: {sorted(VALID_EFFORTS)})"
        )
    return failures


def _check_triage_acceptance(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    fm = doc.frontmatter
    category = str(fm.get("category") or "").strip().lower()
    if category in NON_CODE_CATEGORIES:
        return []
    acceptance = _as_list(fm.get("acceptance"))
    if acceptance:
        return []
    if _non_empty(fm.get("acceptance_waiver")):
        return []
    return [
        "triage: acceptance[] vazio em ticket de código "
        f"(category={category or '?'}); preencha critérios ou acceptance_waiver"
    ]


def _check_no_unknown_fields(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    unknown = sorted(set(doc.frontmatter) - KNOWN_TICKET_FIELDS)
    if not unknown:
        return []
    return [f"triage: campos desconhecidos no frontmatter: {', '.join(unknown)}"]


# ---------------------------------------------------------------------------
# triaged -> designed
# ---------------------------------------------------------------------------

def _load_design_frontmatter(design_id: str, root: Path) -> tuple[dict[str, Any] | None, str | None]:
    """Resolve um DES pelo resolver canônico; retorna (frontmatter, erro)."""
    from lib.artifacts import resolve_artifact

    try:
        path = resolve_artifact("DES", design_id, root=root, include_archive=False)
    except Exception:
        return None, f"design: {design_id} não encontrado em {paths(root).designs}"
    try:
        from lib.frontmatter import parse_frontmatter

        return parse_frontmatter(path.read_text(encoding="utf-8")), None
    except OSError as exc:
        return None, f"design: {design_id} ilegível ({exc})"


def _design_path(design_id: str, root: Path) -> Path | None:
    from lib.artifacts import resolve_artifact

    try:
        return resolve_artifact("DES", design_id, root=root, include_archive=False)
    except Exception:
        return None


def _check_linked_designs(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    designs = [str(d) for d in _as_list(doc.frontmatter.get("linked_designs")) if _non_empty(d)]
    if not designs:
        return ["design: linked_designs vazio — vincule um DES antes de designed"]
    failures: list[str] = []
    for design_id in designs:
        fm, err = _load_design_frontmatter(design_id, root)
        if err:
            failures.append(err)
            continue
        status = str(fm.get("status") or "").strip()
        if status != "approved":
            failures.append(f"design: {design_id} status={status or '?'} (exigido: approved)")
        scope = (
            _as_list(fm.get("scope_files_new"))
            + _as_list(fm.get("scope_files_modified"))
            + _as_list(fm.get("scope_files_deleted"))
        )
        if not scope:
            failures.append(
                f"design: {design_id} sem scope_files "
                "(new/modified/deleted todos vazios)"
            )
    return failures


# ---------------------------------------------------------------------------
# designed -> executing (base para paused-* -> executing)
# ---------------------------------------------------------------------------

def _playbook_path_for(doc: ticket_lib.TicketDocument, root: Path) -> tuple[Path | None, str | None]:
    """Playbook do primeiro design vinculado: campo `playbook` do DES ou o
    path convencional playbooks/<DES>-playbook.md."""
    designs = [str(d) for d in _as_list(doc.frontmatter.get("linked_designs")) if _non_empty(d)]
    if not designs:
        return None, "playbook: sem linked_designs para derivar playbook"
    design_id = designs[0]
    fm, err = _load_design_frontmatter(design_id, root)
    if err:
        return None, err
    declared = str(fm.get("playbook") or "").strip()
    if declared:
        candidate = Path(declared)
        if not candidate.is_absolute():
            candidate = paths(root).root / declared
        return candidate, None
    return paths(root).playbooks / f"{design_id}-playbook.md", None


def _check_playbook_exists(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    playbook, err = _playbook_path_for(doc, root)
    if err:
        return [err]
    if playbook is None or not playbook.exists():
        return [f"playbook: não encontrado ({playbook})"]
    return []


def _check_branch_policy(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """Branch atual segue git-flow e referencia o ticket. Sem git (fixtures)
    o check é pulado — read-only, nunca falha fechado fora de repo."""
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if out.returncode != 0:
        return []
    branch = out.stdout.strip()
    if not branch:
        return []
    playbook, _ = _playbook_path_for(doc, root)
    prefixes = list(GIT_FLOW_PREFIXES)
    if playbook is not None and playbook.exists():
        from lib.frontmatter import parse_frontmatter

        pb_fm = parse_frontmatter(playbook.read_text(encoding="utf-8"))
        declared = str(pb_fm.get("branch_prefix") or "").strip()
        if declared and declared not in prefixes:
            prefixes.append(declared)
    failures: list[str] = []
    if not any(branch.startswith(p) for p in prefixes):
        failures.append(
            f"branch: '{branch}' fora dos prefixos git-flow {tuple(prefixes)} (DES-0192)"
        )
    if doc.ticket_id.lower() not in branch.lower():
        failures.append(
            f"branch: '{branch}' não referencia {doc.ticket_id} "
            "(convenção <prefix>/TCK-NNNN-<slug>)"
        )
    return failures


def _check_no_unapproved_destructive(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    playbook, err = _playbook_path_for(doc, root)
    if err or playbook is None or not playbook.exists():
        return []  # ausência/resolução já reportada por _check_playbook_exists
    from lib.frontmatter import parse_frontmatter

    text = playbook.read_text(encoding="utf-8")
    fm = parse_frontmatter(text)
    try:
        destructive_steps = int(fm.get("destructive_steps") or 0)
    except (TypeError, ValueError):
        destructive_steps = 0
    body_markers = len(re.findall(r"\[destructive\]", text, re.IGNORECASE))
    if destructive_steps <= 0 and body_markers == 0:
        return []
    if _non_empty(fm.get("approved_by")):
        return []
    return [
        f"playbook: {max(destructive_steps, body_markers)} passo(s) destrutivo(s) "
        "sem flag de aprovação (approved_by vazio)"
    ]


# ---------------------------------------------------------------------------
# executing -> verifying
# ---------------------------------------------------------------------------

def _find_run_dir(run_id: str, root: Path) -> Path | None:
    runs_dir = paths(root).runs
    candidate = runs_dir / run_id
    if candidate.is_dir():
        return candidate
    matches = sorted(p for p in runs_dir.glob(f"{run_id}*") if p.is_dir())
    return matches[0] if matches else None


def _check_run_evidence(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    runs = [str(r) for r in _as_list(doc.frontmatter.get("linked_runs")) if _non_empty(r)]
    if not runs:
        return ["run: linked_runs vazio — nenhum run para verificar"]
    failures: list[str] = []
    valid = 0
    for run_id in runs:
        run_dir = _find_run_dir(run_id, root)
        if run_dir is None:
            failures.append(f"run: diretório não encontrado para {run_id}")
            continue
        missing = [req for req in ("REPORT.md", "actions.jsonl") if not (run_dir / req).exists()]
        if missing:
            failures.append(f"run: {run_dir.name} sem {', '.join(missing)}")
        else:
            valid += 1
    if valid == 0 and not failures:
        failures.append("run: nenhum run com evidência completa (REPORT.md + actions.jsonl)")
    return failures


def _check_acceptance_runnable(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    acceptance = _as_list(doc.frontmatter.get("acceptance"))
    if not acceptance:
        if _non_empty(doc.frontmatter.get("acceptance_waiver")):
            return []
        return ["acceptance: vazio e sem waiver — criteria-check não tem o que executar"]
    failures: list[str] = []
    for idx, item in enumerate(acceptance, 1):
        if isinstance(item, dict):
            if not _non_empty(item.get("check")):
                failures.append(f"acceptance[{idx}]: campo 'check' vazio (não executável)")
        elif not _non_empty(item):
            failures.append(f"acceptance[{idx}]: item vazio (não executável)")
    return failures


# ---------------------------------------------------------------------------
# verifying -> done (catraca SPC-0058 — REUSA lib/ticket.py, não duplica)
# ---------------------------------------------------------------------------

def _check_ver_fresh(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    children = [str(c) for c in _as_list(doc.frontmatter.get("children")) if _non_empty(c)]
    if children:
        # Épico: satisfaz por agregação (mesma regra de transition_ticket).
        incomplete = ticket_lib._incomplete_children(children, root)
        if incomplete:
            return [
                "done: épico com children pendentes (catraca SPC-0058): "
                + ", ".join(incomplete)
            ]
        return []
    ver_check = ticket_lib.ver_required(doc.frontmatter)
    if not ver_check["required"]:
        return []
    if ver_check["mode"] == "hotfix_postmortem":
        return []  # VER póstumo: deadline gravado na transição (SPC-0058)
    # TCK-2571: o `naive_out` existe porque os dois consumidores desta função
    # precisam do MESMO diagnóstico. Um verificador independente mediu o
    # descompasso: com um VER de `date:` sem fuso, `transition --to done` dizia
    # "SEM FUSO, reemita com sufixo Z" enquanto o handoff dizia "nenhum VER
    # aprovado, fresco e vinculado foi encontrado" — mandando o operador caçar
    # um VER que está ali, a um sufixo de distância.
    #
    # É a lição `gate-only-in-handoff-is-decorative` pelo avesso: não é que o
    # handoff não consome o gate — é que consome e conta outra história.
    naive: list[str] = []
    if ticket_lib._find_valid_fresh_ver(doc, root, naive_out=naive) is not None:
        return []
    if naive:
        return [
            f"done: catraca de confiança (SPC-0058) — {len(naive)} VER com "
            f"`date:` SEM FUSO ({', '.join(naive[:3])}). Sem fuso o instante "
            f"não é comparável com o log de transições, que grava UTC. "
            f"Reemita com sufixo Z; não use --force"
        ]
    return [
        "done: catraca de confiança (SPC-0058) — VER exigido "
        f"({ver_check['reason']}) mas nenhum VER aprovado, fresco e "
        "vinculado foi encontrado"
    ]


def _check_acceptance_lock(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    # Mesma regra de transition_ticket (SPC-0057/C2.2, DES-0213 §3.5): o lock
    # só é exigido em contexto paralelo (>1 worktree ativo).
    if count_active_worktrees(root) <= 1:
        return []
    entry = read_lock(root).get(doc.ticket_id)
    if entry and entry.get("passes") is True:
        return []
    return [
        "done: acceptance-lock não está verde "
        "(>1 worktree ativo e passes != true); rode criteria-check/pipeline-verify"
    ]


def _check_done_acceptance(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """TCK-1521 — piso de evidência: `done` exige critério falsificável.

    O gate de triage (`_check_triage_acceptance`) já cobra acceptance na
    ENTRADA, mas nada cobrava na SAÍDA. Medido em 2026-08-01: 27 tickets `done`
    sem acceptance e sem waiver, e **zero** com waiver explícito — o campo
    existe e nunca foi usado.

    Por que isto é o maior buraco: um ticket sem critério é **infalsificável
    para sempre**. Nenhum gate futuro, por melhor que seja, o alcança
    retroativamente — não há o que re-executar. Enquanto a saída não cobrar, o
    balde de "indecidível" cresce a cada fechamento.

    Isenções (as mesmas do triage, deliberadamente — não inventar regra nova):
    categoria não-código, ou `acceptance_waiver` com justificativa escrita.
    Waiver é decisão consciente registrada, não default silencioso.
    """
    fm = doc.frontmatter
    if _as_list(fm.get("children")):
        return []  # épico fecha por agregação; os critérios vivem nos filhos
    category = str(fm.get("category") or "").strip().lower()
    if category in NON_CODE_CATEGORIES:
        return []
    if _as_list(fm.get("acceptance")):
        return []
    if _non_empty(fm.get("acceptance_waiver")):
        return []
    return [
        f"done: {doc.ticket_id} sem acceptance[] e sem acceptance_waiver "
        f"(category={category or '?'}) — ticket sem critério é infalsificável "
        f"para sempre; nenhum gate futuro o alcança. Preencha o critério ou "
        f"registre um waiver com justificativa."
    ]


def _find_ver_files(root: Path, ver_id: str) -> list[Path]:
    """Arquivos de um VER, no diretório vivo E no archive (TCK-1513).

    Os gates N3/N7 varriam só `14-verify/reports/`. IDs arquivados sempre
    resolvem (ADR-0004), e 171 VERs vivem sob `.archagents/archive/` — para
    esses, o glob não achava nada, o laço não rodava e o gate devolvia lista
    vazia: **passa em silêncio**. Falso-verde prospectivo, provado por
    fixture: um VER stub colocado só no archive atravessava os dois gates.

    É o invariante "caminho lido tem dono que escreve" (memória do projeto):
    quem lê precisa cobrir todos os lugares onde o artefato legitimamente mora.
    """
    found: list[Path] = []
    for base in (root / ".archagents" / "14-verify" / "reports",
                 root / ".archagents" / "archive"):
        if not base.is_dir():
            continue
        found.extend(sorted(base.rglob(f"{ver_id}*.md")))
    return found


def _check_ver_evidence(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """TCK-1350 (SPC-0086 N3): VER `approved` exige evidência semântica.

    Criteria PASS sozinho não fabrica aprovação: o VER precisa dizer O QUE
    verificou e referenciar o pedido. Medido no acervo (FND-0104): 72 de 258
    VERs eram stubs auto-gerados, 100% `approved`, zero rejeições.

    Só `approved` passa pela régua — `approved-with-notes` (o que o driver
    emite desde o TCK-1420, com escopo real) e `rejected-*` declaram
    honestamente. Régua em lib/ver_evidence (fonte única).
    """
    from lib.ver_evidence import baselined, check_ver_evidence, read_ver

    linked = [str(v) for v in _as_list(doc.frontmatter.get("linked_verifications"))
              if _non_empty(v)]
    if not linked:
        return []
    checks = [str(item.get("check", "")) for item in
              (doc.frontmatter.get("acceptance") or [])
              if isinstance(item, dict)]
    failures: list[str] = []
    for ver_id in linked:
        # TCK-2207: MESMA régua, MESMO escopo. A transição canônica consulta o
        # baseline e o handoff não consultava — um VER do acervo REPROVAVA aqui
        # e PASSAVA lá. Zero tickets afetados hoje (nenhum reopen pendente),
        # mas dois caminhos com escopos diferentes sobre a mesma régua é a
        # forma dos contadores gêmeos (TCK-1860).
        if baselined(str(ver_id), root):
            continue
        for path in _find_ver_files(root, ver_id):
            text = read_ver(path)
            if not text:
                continue
            for failure in check_ver_evidence(text, ticket_id=doc.ticket_id,
                                              acceptance_checks=checks):
                failures.append(f"{ver_id}: {failure}")
    return failures


def _check_artifact_lineage(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """TCK-1355 (SPC-0090 N7): a cadeia se sustenta no CONTEÚDO, não só nos IDs.

    `cbctl validate` garante que os artefatos linkados existem — estrutura.
    Aqui a régua é semântica: o VER avaliou ESTE ticket (não outro), tem
    substância (não é stub) e ancora em algo da cadeia. Régua em
    lib/artifact_lineage (fonte única).
    """
    from lib.artifact_lineage import check_lineage, read_text

    linked_vers = [str(v) for v in _as_list(doc.frontmatter.get("linked_verifications"))
                   if _non_empty(v)]
    if not linked_vers:
        return []
    designs = [str(d) for d in _as_list(doc.frontmatter.get("linked_designs")) if _non_empty(d)]
    runs = [str(r) for r in _as_list(doc.frontmatter.get("linked_runs")) if _non_empty(r)]
    failures: list[str] = []
    for ver_id in linked_vers:
        for path in _find_ver_files(root, ver_id):
            text = read_text(path)
            if not text:
                continue
            for failure in check_lineage(text, ticket_id=doc.ticket_id,
                                         design_ids=designs, run_ids=runs):
                failures.append(f"{ver_id}: {failure}")
    return failures


def _check_judge_verdict(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """TCK-1348 (SPC-0086 N1): o verdict do Judge é autoridade bloqueante.

    REJECTED, erro de Judge (verdict ilegível/enum inválido) ou safety abaixo
    do piso barram `verifying→done` — que é também o gate de ship do driver.
    Verdict ausente não bloqueia (judge ainda não é obrigatório; DES-0822 T2).
    Regra e piso vivem em lib/judge_gate (fonte única — não duplicar aqui).
    """
    from lib.judge_gate import check_judge_verdict
    return check_judge_verdict(doc.ticket_id, root)


# ---------------------------------------------------------------------------
# Contract table
# ---------------------------------------------------------------------------

def _check_acceptance_delta(doc: ticket_lib.TicketDocument, root: Path) -> list[str]:
    """TCK-2156: DES novo declara se o aceite foi revisitado (reemitted|
    unchanged). Predicado vive em lib.acceptance_delta (fonte única — a
    transição canônica consome a MESMA função, porque contrato que vive num
    lugar só é decorativo, TCK-1636 3×)."""
    from lib.acceptance_delta import check_acceptance_delta
    return check_acceptance_delta(doc.frontmatter, root)


_BASE_EXECUTING_CHECKS: list[CheckFn] = [
    _check_playbook_exists,
    _check_branch_policy,
    _check_no_unapproved_destructive,
    _check_acceptance_delta,
]

CONTRACTS: dict[str, list[CheckFn]] = {
    "triaged": [_check_triage_fields, _check_triage_acceptance, _check_no_unknown_fields],
    "designed": [_check_linked_designs],
    "executing": list(_BASE_EXECUTING_CHECKS),
    "verifying": [_check_run_evidence, _check_acceptance_runnable],
    "done": [_check_ver_fresh, _check_acceptance_lock, _check_judge_verdict,
             _check_ver_evidence, _check_artifact_lineage,
             _check_done_acceptance],
}

# paused-* -> executing: contrato de designed->executing + evidência de run
# anterior (há algo concreto para retomar).
_RESUME_EXTRA_CHECKS: list[CheckFn] = [_check_run_evidence]


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

def check_handoff(
    ticket: str | Path,
    to_status: str | None = None,
    *,
    root: str | Path | None = None,
    resolve_next: bool = False,
) -> dict[str, Any]:
    """Valida o contrato de handoff de um ticket para `to_status`.

    Com ``resolve_next=True``, resolve o alvo a partir do status atual
    (``NEXT_HANDOFF``). Nunca muta nada — read-only por construção.

    Retorna ``{"ok", "ticket", "from_status", "to_status", "failures", "note"}``.
    Levanta ``ticket_lib.TicketError`` se o ticket não resolve.
    """
    document = ticket_lib.load_ticket(ticket, root=root)
    base = paths(root).root
    from_status = document.status

    if resolve_next:
        to_status = NEXT_HANDOFF.get(from_status)
        if to_status is None:
            return {
                "ok": False,
                "ticket": document.ticket_id,
                "from_status": from_status,
                "to_status": None,
                "failures": [
                    f"sem handoff 'para frente' padrão a partir de '{from_status}' "
                    f"(mapa: {', '.join(f'{k}->{v}' for k, v in sorted(NEXT_HANDOFF.items()) if not k.startswith('paused'))})"
                ],
                "note": "no-default-next",
            }
    if not to_status:
        raise ticket_lib.TicketError("handoff check: to_status ausente (use --all para resolver)")

    legal = ticket_lib.STATUS_TRANSITIONS.get(from_status, frozenset())
    if to_status not in legal:
        return {
            "ok": False,
            "ticket": document.ticket_id,
            "from_status": from_status,
            "to_status": to_status,
            "failures": [
                f"transição inválida: {from_status} -> {to_status} "
                f"(legais: {', '.join(sorted(legal)) or 'nenhuma'})"
            ],
            "note": "invalid-transition",
        }

    dependency_gate_failures: list[str] = []
    if is_progress_status(to_status):
        dependency_readiness = evaluate_ticket_dependencies(
            document.ticket_id,
            root=base,
        )
        issue_codes = sorted(
            {issue.code for issue in dependency_readiness.issues}
        )
        emit_readiness_event(
            "dependency_readiness",
            correlation_id=document.ticket_id,
            outcome="ready" if dependency_readiness.eligible else "blocked",
            reason=issue_codes[0] if issue_codes else "ready",
            ticket=document.ticket_id,
            eligible=dependency_readiness.eligible,
            dependency_ids=list(dependency_readiness.dependencies),
            issue_codes=issue_codes,
            consumer="handoff",
        )
        dependency_gate_failures = dependency_failures(dependency_readiness)

    checks = list(CONTRACTS.get(to_status, []))
    if from_status in ALL_PAUSED_STATUSES and to_status == "executing":
        checks += _RESUME_EXTRA_CHECKS
    if not checks:
        return {
            **_ok(dependency_gate_failures),
            "ticket": document.ticket_id,
            "from_status": from_status,
            "to_status": to_status,
            "note": f"sem contrato de artefatos para -> {to_status} (transição administrativa)",
        }

    failures: list[str] = list(dependency_gate_failures)
    for check in checks:
        failures.extend(check(document, base))
    return {
        **_ok(failures),
        "ticket": document.ticket_id,
        "from_status": from_status,
        "to_status": to_status,
        "note": "",
    }


def handoff_check(
    ticket: str | Path,
    to_status: str | None = None,
    *,
    root: str | Path | None = None,
    resolve_next: bool = False,
    level: str = "L2",
    consult_ratchet: bool = False,
) -> dict[str, Any]:
    """``check_handoff`` + consulta opcional ao autonomy ratchet (TCK-1223).

    Backward compatible: ``consult_ratchet=False`` (default) retorna
    EXATAMENTE o mesmo payload de ``check_handoff``. Com ``True``, anexa
    ``result["ratchet"] = ratchet_gate_for_stage(from_status, ...)`` — assim o
    driver faz UMA chamada para contrato de artefatos + gate de autonomia.
    Read-only como ``check_handoff``; a consulta ao ratchet é fail-open.
    """
    result = check_handoff(ticket, to_status, root=root, resolve_next=resolve_next)
    if consult_ratchet:
        try:
            result["ratchet"] = ratchet_gate_for_stage(
                result.get("from_status"), level=level, root=root)
        except Exception as exc:  # belt-and-braces: nunca quebra o caller
            result["ratchet"] = {
                "stage": result.get("from_status"),
                "classe": None,
                "gate": "flow",
                "note": f"ratchet wiring failed (fail-open): {exc}",
            }
    return result


def render_report(result: dict[str, Any]) -> str:
    """Saída humana padrão do CLI: PASS/FAIL + failures."""
    verdict = "PASS" if result["ok"] else "FAIL"
    target = result.get("to_status") or "?"
    lines = [f"[handoff] {result['ticket']} {result['from_status']}->{target}: {verdict}"]
    for failure in result.get("failures", []):
        lines.append(f"  - {failure}")
    if result.get("note"):
        lines.append(f"  note: {result['note']}")
    return "\n".join(lines)
