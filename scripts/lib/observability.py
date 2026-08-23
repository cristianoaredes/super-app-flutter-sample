#!/usr/bin/env python3
"""observability.py — Governed Post-Release Report (PRR) creation.

Creates PRR artifacts in .archagents/17-observability/post-release/ following
the codebase-ops governed artifact pattern (IDs, templates, fail-open).

Usage:
    from lib.observability import create_post_release_report
    result = create_post_release_report("TCK-0380", "v1.0.0", root)
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from lib.ids import next_post_release_report_id, next_telemetry_plan_id
from lib.paths import paths


def _peek_next_id(directory: Path, prefix: str) -> str:
    """Próximo ID PROVÁVEL, sem consumir o high-water (TCK-2104).

    Só para preview: lê o maior número já em disco e soma 1. Não é autoritativo
    — se duas sessões previewarem ao mesmo tempo verão o mesmo número, e é
    exatamente por isso que a alocação real continua sendo `next_*_id` sob lock,
    no caminho de escrita.
    """
    import re as _re
    maior = 0
    try:
        for f in directory.glob(f"{prefix}-*"):
            m = _re.match(rf"{prefix}-(\d+)", f.name)
            if m:
                maior = max(maior, int(m.group(1)))
    except OSError:
        pass
    return f"{prefix}-{maior + 1:04d}"


@dataclass
class ArtifactResult:
    artifact_id: str
    path: Path
    status: str  # "created" | "dry_run" | "error"


def create_post_release_report(
    ticket: str,
    release: str | None = None,
    root: Path | None = None,
    dry_run: bool = True,
) -> ArtifactResult:
    """Create a Post-Release Report (PRR-NNNN).

    Args:
        ticket: Source ticket ID (e.g., "TCK-0380")
        release: Release version tag (optional)
        root: Repository root (default: auto-detect)
        dry_run: If True, return preview without writing (default: True)

    Returns:
        ArtifactResult with the PRR ID, path, and status.
    """
    p = paths(root)
    prr_dir = p.post_release_reports
    prr_dir.mkdir(parents=True, exist_ok=True)

    # TCK-2104: o ID é alocado SÓ quando se vai escrever. A v1 alocava antes de
    # olhar `dry_run`, e `next_*_id` avança o high-water — dois previews
    # consecutivos queimavam dois IDs. Preview com efeito colateral é a
    # contradição do próprio nome, e produzia buracos permanentes na numeração
    # monotônica (que, por contrato, nunca reusa).
    prr_id = (next_post_release_report_id(p.root) if not dry_run
              else _peek_next_id(prr_dir, "PRR"))
    prr_path = prr_dir / f"{prr_id}.md"

    # Load run telemetry if available
    run_data = _load_run_telemetry(ticket, p.archagents)
    verdict_data = _load_verdict(ticket, p.archagents)

    # Build PRR content
    now = datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    content = f"""---
id: {prr_id}
type: post-release-report
ticket: {ticket}
linked_ticket: {ticket}
release: {release or 'unspecified'}
created_at: "{now}"
status: draft
judge_score: {verdict_data.get('score', 'n/a')}
judge_overall: {verdict_data.get('overall', 'n/a')}
loop_iterations: {run_data.get('loop_iterations', 'n/a')}
lessons_consulted: {run_data.get('lessons_consulted', 'n/a')}
---

# {prr_id} — Post-Release Report

**Ticket:** {ticket}
**Release:** {release or 'unspecified'}
**Created:** {now}

## Health Hypothesis

_To be validated against production signals._

## Observed Metrics

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| judge_score | >= 75 | {verdict_data.get('score', 'n/a')} | _pending_ |
| loop_iterations | <= 3 | {run_data.get('loop_iterations', 'n/a')} | _pending_ |

## Incidents & Alerts

_None reported yet._

## Signals for Learn Stage

_To be populated by /ops-learn._

## Decision

- [ ] Approved — proceed to Learn
- [ ] Needs investigation — create follow-up ticket
- [ ] Rollback required
"""

    if dry_run:
        return ArtifactResult(artifact_id=prr_id, path=prr_path, status="dry_run")

    prr_path.write_text(content, encoding="utf-8")
    return ArtifactResult(artifact_id=prr_id, path=prr_path, status="created")


def _load_run_telemetry(ticket: str, archagents: Path) -> dict[str, Any]:
    """Load run telemetry from the most recent RUN for this ticket. Fail-open."""
    try:
        runs_dir = archagents / "13-execution" / "runs"
        if not runs_dir.is_dir():
            return {}
        # Find runs matching this ticket
        matches = sorted(runs_dir.glob(f"*{ticket}*"), reverse=True)
        if not matches:
            return {}
        run_json = matches[0] / "run.json"
        if run_json.exists():
            import json
            return json.loads(run_json.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def _load_verdict(ticket: str, archagents: Path) -> dict[str, Any]:
    """Load judge verdict for this ticket. Fail-open."""
    try:
        verdicts_dir = archagents / "99-memory" / "verdicts"
        if not verdicts_dir.is_dir():
            return {}
        verdict_file = verdicts_dir / f"{ticket}-judge.json"
        if verdict_file.exists():
            import json
            return json.loads(verdict_file.read_text(encoding="utf-8"))
    except Exception:
        pass
    return {}


def create_telemetry_plan(
    ticket: str,
    root: Path | None = None,
    dry_run: bool = True,
) -> ArtifactResult:
    """Create a Telemetry Plan (TLP-NNNN) — TCK-2104.

    TLP era o ÚNICO id da tabela de rastreabilidade sem create governado: o
    `cbctl` já criava DSC, BRF, PLN, SPC, TCK, DES, ADR, RUN, VER, PRR e LRN, e
    `next_telemetry_plan_id` + `paths.telemetry_plans` existiam desde sempre —
    faltava quem os chamasse.

    A consequência era estrutural, não cosmética: `core/07-ship/SHIP.md:214`
    condiciona a geração do PRR a "**se** o ticket tem TLP vinculado". Medido em
    06/08/2026: **2 tickets em 282** tinham. Sem TLP o ship cai no ramo
    `observe_handoff: "no_tlp"`, o PRR nunca nasce, e o estágio Observe fica
    parado — como ficou desde 07/07.

    O plano nasce com os campos de medição **em branco por desenho**: preencher
    threshold ou métrica antes da janela de observação seria fabricar o número
    que o plano existe para coletar (ADR-0029).
    """
    p = paths(root)
    tlp_dir = p.telemetry_plans
    tlp_dir.mkdir(parents=True, exist_ok=True)

    tlp_id = (next_telemetry_plan_id(p.root) if not dry_run
              else _peek_next_id(tlp_dir, "TLP"))
    tlp_path = tlp_dir / f"{tlp_id}.md"

    now = datetime.datetime.now(
        datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    content = f"""---
id: {tlp_id}
type: telemetry-plan
ticket: {ticket}
linked_ticket: {ticket}
created_at: "{now}"
status: draft
observation_window: ""
---

# {tlp_id} — Plano de Telemetria

**Ticket:** {ticket}
**Criado:** {now}

## O que medir

_Uma métrica por linha, com a fonte de onde ela sai. Métrica sem fonte
declarada não é plano — é intenção._

| métrica | fonte | baseline hoje |
|---|---|---|
| | | |

## Janela de observação

_48h para minor, 1 semana para major. Declarar qual e por quê._

## Critério de sucesso

_O número que, se atingido, valida a hipótese da entrega._

## Critério de falha / rollback

_O sinal que dispara reversão. Sem isto, "observar" vira olhar sem consequência._

## Owner

_Quem olha, e quando._

---

> Campos em branco são o estado **honesto** de um plano recém-criado: a janela
> ainda não decorreu. Preenchê-los agora seria inventar a medição que este plano
> existe para coletar — a classe que o ADR-0029 teve de desfazer.
"""

    if dry_run:
        return ArtifactResult(tlp_id, tlp_path, "dry_run")
    try:
        tlp_path.write_text(content, encoding="utf-8")
    except OSError:
        return ArtifactResult(tlp_id, tlp_path, "error")
    return ArtifactResult(tlp_id, tlp_path, "created")
