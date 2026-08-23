#!/usr/bin/env python3
"""runstate.py — Enum CANÔNICO de status de run + helpers de tempo/staleness (TCK-0029).

Fonte única do contrato de run-state, consumida por update-meta.py, verify-run.py
e documentada em core/05-execute/EXECUTE.md. Antes: 3 listas divergentes
(update-meta conhecia paused-evidence só em 1 dos 2 gates; verify-run não conhecia
paused/paused-safety/paused-context; EXECUTE.md citava os três paused-*).

Estados:
  draft            run scaffolded, ainda não iniciado
  running          em execução
  paused           pausa genérica (humano pediu)
  paused-evidence  parado no Evidence Gate (falta evidência fresh)
  paused-safety    parado por stop-condition do SAFETY (humano resolve)
  paused-context   parado por contexto < 30% (retomada em nova sessão)
  paused-budget    parado por teto de tokens do run atingido (SPC-0014; humano
                   destrava: continuar com teto novo, abortar ou decompor)
  paused-attempts  loop de auto-fix do Verify atingiu o teto de tentativas (TCK-0178;
                   default 2; humano destrava — não auto-fixar de novo)
  completed        terminou com sucesso
  aborted          abortado/falha não-recuperável
"""

from __future__ import annotations

import json
import re
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

import importlib.util as _ilu
fcntl = __import__("fcntl") if _ilu.find_spec("fcntl") else None  # POSIX-only; None elsewhere (F0.7-T2)

ACTIVE_STATUSES = frozenset({
    "draft", "running", "paused", "paused-evidence", "paused-safety", "paused-context",
    # paused-budget é um paused-* destravável (SPC-0014/TCK-0107): run pausado por
    # teto de tokens NUNCA pode sumir do dashboard (mesmo princípio FND-09/TCK-0029).
    "paused-budget",
    # paused-attempts (TCK-0178/SPC-0020): loop de auto-fix do Verify atingiu o teto de
    # tentativas (default 2). paused-* destravável por humano — NUNCA some do dashboard
    # (mesmo princípio de paused-budget/FND-09). O cap deixa de viver só no prompt.
    "paused-attempts",
})
TERMINAL_STATUSES = frozenset({"completed", "aborted"})
RUN_STATUSES = ACTIVE_STATUSES | TERMINAL_STATUSES

# FND-0048: Canonical paused-status enum — SINGLE authoritative source consumed
# by both runstate (run-level) and ticket (ticket-level PAUSED_STATUSES).
# Union of every paused-* variant known across the project.
# TCK-0475/SPC-0057-A9: piso absoluto de tentativas do loop — FONTE ÚNICA.
# Antes duplicado em loop_controller.py e verify-run.py (dessincronizável).
# Ratchet P9: este teto só pode SUBIR de proteção (diminuir número) via ADR.
ABSOLUTE_SAFE_MAX_ATTEMPTS = 5

ALL_PAUSED_STATUSES = frozenset({
    "paused-evidence",
    "paused-safety",
    "paused-context",
    "paused-budget",
    "paused-attempts",
    "paused-scope",    # ticket-level: scope explosion pause
    "paused-prod",     # ticket-level: prod-safety pause
    "paused-secret",   # ticket-level: secret-in-diff pause
})

# Run "running" sem atividade há mais de isto é suspeito de órfão (sessão morta).
STALE_AFTER_HOURS = 24


def parse_iso_safe(ts: object) -> datetime | None:
    """Parse ISO-8601 tolerante: None/''/malformado → None (nunca levanta).

    Substitui o parse_iso cru que derrubava o update-meta inteiro por UM
    timestamp malformado num ticket (FND-20260610-14)."""
    if not ts or not isinstance(ts, str):
        return None
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None
    # Sempre tz-aware (TCK-0058): timestamps naive de alvos reais (ex.: ashlar,
    # 'created_at: 2026-04-26T15:36:13.130909' sem offset) quebravam a subtração
    # com um `now` aware no cálculo de cycle-time (TypeError). Naive ⇒ assume UTC.
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def is_stale(started_at: object, now: datetime | None = None,
             hours: int = STALE_AFTER_HOURS) -> bool:
    """True se um run 'running' começou há mais de `hours` (órfão provável).

    started_at malformado/ausente conta como stale — um run running sem
    timestamp confiável é exatamente o caso indistinguível que o FND-10 aponta."""
    dt = parse_iso_safe(started_at)
    if dt is None:
        return True
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    now = now or datetime.now(timezone.utc)
    return (now - dt).total_seconds() > hours * 3600


def effective_run_status(run_dir: "str | Path") -> dict:
    """Status EFETIVO de um run reconciliado entre run.json e REPORT.md (TCK-0979).

    Fonte única da reconciliação que antes vivia só em update-meta.scan_active_runs
    (passos 1-2) — o cockpit lia o run.json cru e mostrava trabalho fantasma
    ("running" de semanas atrás cujo REPORT.md já era terminal).

    Regras:
      - run.json é a fonte primária quando o status é válido (RUN_STATUSES);
      - REPORT.md (frontmatter) preenche quando run.json falta/é inválido;
      - run.json preso em status ATIVO com REPORT.md TERMINAL reconcilia para
        o terminal (`reconciled_from` guarda o status fantasma);
      - `stale` = running sem REPORT terminal e started_at velho/ausente
        (is_stale, FND-10).

    Fail-open: nunca levanta — artefato ilegível vira status None.
    Retorna {"status", "stale", "reconciled_from", "run_data"}.
    """
    import json as _json
    run_dir = Path(run_dir)
    run_data: dict | None = None
    explicit: str | None = None
    run_json = run_dir / "run.json"
    if run_json.exists():
        try:
            run_data = _json.loads(run_json.read_text(encoding="utf-8"))
            explicit = str(run_data.get("status", "")).lower() or None
        except Exception:
            run_data = None
            explicit = None

    report_status: str | None = None
    report = run_dir / "REPORT.md"
    if report.exists():
        try:
            from lib.frontmatter import parse_frontmatter
            fm = parse_frontmatter(report.read_text(encoding="utf-8"))
            report_status = str(fm.get("status", "")).lower() or None
        except Exception:
            report_status = None

    if explicit not in RUN_STATUSES and report_status:
        explicit = report_status

    reconciled_from: str | None = None
    if explicit in ACTIVE_STATUSES and report_status in TERMINAL_STATUSES:
        reconciled_from = explicit
        explicit = report_status

    stale = False
    if explicit == "running":
        stale = is_stale((run_data or {}).get("started_at"))

    return {
        "status": explicit,
        "stale": stale,
        "reconciled_from": reconciled_from,
        "run_data": run_data,
    }


@contextmanager
def runstate_lock(root: "str | Path | None" = None) -> Iterator[None]:
    """SPC-0036/F0.6: serialize run.json write-back via a DEDICATED lock
    (.locks/runstate.lock), independent from ids.id_lock so run-state writes
    don't couple to ID allocation (a ticket-create holding ids.lock must not
    block lessons write-back, and vice-versa).

    fcntl is POSIX-only; on a non-POSIX harness this degrades to best-effort
    (atomic_write/os.replace remains the crash-safety guarantee)."""
    from lib.paths import paths  # lazy: keeps runstate importable standalone (tests)

    lock_dir = paths(root).locks
    lock_dir.mkdir(parents=True, exist_ok=True)
    lock_path = lock_dir / "runstate.lock"
    with lock_path.open("a+", encoding="utf-8") as fh:
        if fcntl is not None:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            if fcntl is not None:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def resolve_run_for_ticket(
    runs_dir: "str | Path",
    ticket_id: str,
    run_hint: str | None = None,
) -> Path | None:
    """SPC-0036/F0.6: ticket-scoped run.json selection (single home).

    Resolution order: (a) an explicit run_hint dir if it exists, else (b) the
    newest-by-mtime run dir whose name contains EITHER the canonical hyphenated
    form `tck-NNNN` (pipeline-orchestrator naming) OR the legacy no-hyphen form
    `tckNNNN` (present in real legacy dirs). Returns None when no ticket-matching
    run exists — NEVER a global newest (that is the F12 wrong-attribution bug).

    Both forms are matched on purpose: the prior find_run stripped the hyphen from
    the needle only, so it missed canonically-named dirs. This is the corrected
    rule both the judge and the executor share."""
    runs_dir = Path(runs_dir)
    if run_hint:
        cand = runs_dir / run_hint
        if cand.exists():
            return cand
    if not runs_dir.is_dir():
        return None
    needle_hyphen = ticket_id.lower()                 # tck-0225 (orchestrator)
    needle_strip = ticket_id.lower().replace("-", "")  # tck0225 (legacy)
    matches = [
        d for d in runs_dir.iterdir()
        if d.is_dir() and (needle_hyphen in d.name.lower() or needle_strip in d.name.lower())
    ]
    if not matches:
        return None
    return sorted(matches, key=lambda p: p.stat().st_mtime, reverse=True)[0]


# --- Loop Telemetry (SPC-0028 unit 1: rich always-present fields for smarter loops)
# Contract: after any loop execution (orchestrator/judge etc.), run artifacts
# always carry these. Legacy runs tolerated via defaults/normalization.
LOOP_TELEMETRY_FIELDS = [
    "loop_iterations",
    "attempt_count",
    "lessons_consulted",
    "loop_cost_usd",
    "loop_strategy",
    "context_peak",
    "final_judge_delta",
    "warmup",  # TCK-0747: synthetic consult-only runs
]

LOOP_TELEMETRY_DEFAULTS = {
    "loop_iterations": 0,
    "attempt_count": 0,
    "lessons_consulted": [],
    "loop_cost_usd": 0.0,
    "loop_strategy": "default",
    "context_peak": 0,
    # SPC-0034/F0.4: float (not int 0) so the REAL column, the verify-run gate's
    # numeric check, and the round-trip test agree (no int-in/REAL-out flap).
    "final_judge_delta": 0.0,
    "warmup": False,  # TCK-0747
}


def ensure_loop_telemetry(run_data: dict) -> dict:
    """Idempotent normalizer: guarantees all LOOP_TELEMETRY_FIELDS are present.
    Legacy keys (e.g. "iterations") mapped. Never mutates input shape unexpectedly.

    TCK-1234 / TCK-1129: **measured** fields (``LOOP_TELEMETRY_MEASURED_FIELDS``)
    keep explicit ``None`` ("not measured"). Never coerce ``None`` → numeric
    default (that was collapsing ``final_judge_delta`` null into 0.0 and diluting
    lesson utility).
    """
    data = dict(run_data) if run_data else {}
    measured = set(LOOP_TELEMETRY_MEASURED_FIELDS)
    # legacy mapping
    if "iterations" in data and "loop_iterations" not in data:
        data["loop_iterations"] = data["iterations"]
    for k, default in LOOP_TELEMETRY_DEFAULTS.items():
        if k not in data:
            # Absent measured field → explicit null; config fields get default.
            data[k] = None if k in measured else default
            continue
        if data[k] is None and k in measured:
            continue  # preserve not-measured
        # type guards
        if k in ("lessons_consulted",) and not isinstance(data[k], list):
            data[k] = list(data[k]) if data[k] else []
        if k in ("loop_iterations", "attempt_count", "context_peak") and not isinstance(data[k], int):
            try:
                data[k] = int(data[k])
            except Exception:
                data[k] = None if k in measured else default
        if k in ("loop_cost_usd", "final_judge_delta") and not isinstance(data[k], (int, float)):
            try:
                data[k] = float(data[k])
            except Exception:
                data[k] = None if k in measured else default
        if k == "warmup" and not isinstance(data[k], bool):
            data[k] = bool(data[k])
    return data


def accumulate_run_cost(run_data: dict, delta_usd: float) -> dict:
    """SPC-0033/F0.3: add delta_usd (an estimate) onto run_data['loop_cost_usd'].

    Monotonic: a negative/garbage delta is a no-op (cost never decreases); a
    missing field seeds from 0.0. Returns a NEW dict (does not mutate input)."""
    data = dict(run_data) if run_data else {}
    try:
        current = float(data.get("loop_cost_usd", 0.0) or 0.0)
    except (TypeError, ValueError):
        current = 0.0
    try:
        delta = float(delta_usd)
    except (TypeError, ValueError):
        delta = 0.0
    if delta < 0:
        delta = 0.0
    data["loop_cost_usd"] = float(current + delta)
    return data


def get_loop_iterations(run_data: dict) -> int:
    # TCK-2131: campos MEDIDOS preservam None = não-medido (TCK-1234, acima);
    # `int(None)` estourava TypeError no primeiro caller de verdade (o judge).
    # 0 é a leitura honesta de "não medido" para quem precisa de um int —
    # o mesmo vocabulário do stall_retry_stats (TCK-2090).
    d = ensure_loop_telemetry(run_data)
    v = d.get("loop_iterations")
    return int(v) if v is not None else 0


def get_attempt_count(run_data: dict) -> int:
    # gêmeo do de cima — mesmo contrato, mesmo motivo (TCK-2131)
    d = ensure_loop_telemetry(run_data)
    v = d.get("attempt_count")
    return int(v) if v is not None else 0


# --- TCK-1129: null-vs-default seed + Fase-7 derivation (agent-driven path) -----
# Campos MEDIDOS na finalização: entram no run.json do scaffold (init-run.sh)
# como None explícito — "não medido" ≠ "medido zero". ensure_loop_telemetry()
# coage None → default para consumidores; o gate do verify-run tolera null
# explícito como se fosse chave ausente. Campos de CONFIGURAÇÃO conhecidos no
# scaffold entram com default real (LOOP_TELEMETRY_SCAFFOLD_DEFAULTS).
LOOP_TELEMETRY_MEASURED_FIELDS = [
    "loop_iterations",
    "attempt_count",
    "lessons_consulted",
    "loop_cost_usd",
    "context_peak",
    "final_judge_delta",
]

LOOP_TELEMETRY_SCAFFOLD_DEFAULTS = {
    "loop_strategy": "default",
    "warmup": False,
}

# gate_status de actions.jsonl (lib/artifacts.GATE_STATUSES) que NÃO é fluxo
# limpo: cada entrada dessas é um step que bateu num gate = tentativa falha.
_FAILED_GATE_STATUSES = frozenset({
    "paused-safety", "paused-evidence", "paused-scope", "paused-context",
    "paused-budget", "paused-prod", "paused-secret", "failed-fatal",
})


# Alias histórico do MESMO conjunto (`_FAILED_GATE_STATUSES` é lido por
# tests/test_driver_loop_telemetry.py). TCK-1870: antes eram dois frozensets
# idênticos acompanhando DUAS definições de `_read_actions_entries` e
# `derive_loop_telemetry` — a segunda vencia em silêncio, então consertar a
# primeira não mudava nada. Um caminho, um dono.
_NON_FLOW_GATE_STATUSES = _FAILED_GATE_STATUSES


def _read_actions_entries(run_dir: Path) -> list[dict]:
    """Lê actions.jsonl linha a linha; malformadas ignoradas; I/O error → []."""
    entries: list[dict] = []
    try:
        with (Path(run_dir) / "actions.jsonl").open("r", encoding="utf-8") as fh:
            for raw in fh:
                line = raw.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if isinstance(obj, dict):
                    entries.append(obj)
    except OSError:
        return []
    return entries


def measured_iteration_costs(entries: "list[dict]") -> list[float]:
    """TCK-1870: custos por volta REALMENTE medidos em `actions.jsonl`.

    O produtor é o `pipeline-driver` (TCK-1873), que grava `cost_usd` em cada
    entrada de iteração — inclusive `None`, de propósito, quando o harness não
    declara `cost_report` no registry.

    `None` (não medido) NUNCA entra como `0.0`: era essa confusão que deixava
    `loop_cost_usd` em `0.0` em 153 runs sem ninguém poder distinguir "o loop é
    grátis" de "nada foi medido". Bool/string/negativo também são ausência de
    medida, não medida de zero.
    """
    costs: list[float] = []
    for e in entries:
        raw = e.get("cost_usd")
        if isinstance(raw, bool) or not isinstance(raw, (int, float)):
            continue
        value = float(raw)
        if value < 0:
            continue  # custo não é negativo; lixo não é medição
        costs.append(value)
    return costs


def derive_loop_counters(entries: "list[dict]") -> dict:
    """TCK-1860: fonte ÚNICA de `loop_iterations` e `attempt_count`.

    Os dois contadores respondem sobre a MESMA coisa — a volta do laço
    execute/verify registrada em `actions.jsonl` — e por isso são derivados aqui,
    juntos, da mesma unidade. Antes cada um contava a sua: `loop_iterations`
    deduplicava por `step` e `attempt_count` somava ENTRADAS. Duas entradas
    não-fluxo do mesmo step publicavam `loop_iterations: 1` com
    `attempt_count: 2` — uma volta com duas tentativas falhas, que não existe.

    Unidade: o `step` (int, e `bool` não conta — `isinstance(True, int)` mente).
    Uma volta é tentativa falha quando QUALQUER registro dela tem `gate_status`
    não-fluxo: gate batido é evidência, e um registro posterior de retry no mesmo
    step não a apaga (contrato de `tests/test_telemetry_retrofit.py` — step com
    `failed-fatal` seguido de `flow` conta 1). O que a volta não pode é contar
    duas vezes.

    Só o vocabulário canônico `_NON_FLOW_GATE_STATUSES` marca falha: status
    ausente ou desconhecido é falta de medida, e virar tentativa a partir dela
    seria o falso-zero ao contrário.

    Invariante garantido pelo formato: `nao_fluiram` é SUBCONJUNTO de `voltas`,
    logo `0 <= attempt_count <= loop_iterations`, e os dois campos nascem e
    faltam juntos. Sem volta registrada devolve `{}` — ausência é "não medido"
    (TCK-1129), nunca zero fabricado.
    """
    voltas: set[int] = set()
    nao_fluiram: set[int] = set()
    for entry in entries:
        step = entry.get("step")
        if not isinstance(step, int) or isinstance(step, bool):
            continue
        voltas.add(step)
        if entry.get("gate_status") in _NON_FLOW_GATE_STATUSES:
            nao_fluiram.add(step)
    if not voltas:
        return {}
    return {
        "loop_iterations": len(voltas),
        "attempt_count": len(nao_fluiram),
    }


def derive_loop_telemetry(run_dir: "str | Path") -> dict:
    """TCK-1129: deriva telemetria de loop SOMENTE de artefatos reais do run.

    Retorna dict contendo APENAS os campos com evidência real — nunca fabrica
    zeros. Campo sem evidência fica ausente (o caller preserva o null explícito
    de "not measured"). Fontes:
      - loop_iterations
        e attempt_count:  os DOIS saem de `derive_loop_counters` (TCK-1860), que
                          é a fonte única — steps distintos de actions.jsonl e,
                          dentre eles, os cujo desfecho não fluiu
                          (paused-*/failed-fatal). Contar aqui de novo é o que
                          fazia os dois divergirem.
      - loop_cost_usd:   soma dos `cost_usd` MEDIDOS por volta em actions.jsonl
                         (TCK-1870), reconciliada com o spend durável de
                         budget.json / council-cost.json via
                         lib.pipeline_loop.reconcile_loop_cost

    TCK-1870 — por que a soma das voltas entrou: `budget.json` só existe quando
    o operador passa `--budget-usd`, então o custo real que o driver já media
    por volta (TCK-1873) morria no `actions.jsonl`. A reconciliação é MAX, não
    soma: os dois canais recebem o mesmo gasto do driver (`accumulate_spend`) e
    somá-los cobraria em dobro; o durável ainda vence quando inclui custo
    cross-process (council/judge) que este laço não viu.

    Sem nenhuma volta medida E sem registro durável com spend > 0, o campo fica
    AUSENTE — `0.0` aqui seria reproduzir o defeito original por outro caminho.
    """
    run_dir = Path(run_dir)
    derived: dict = {}
    entries = _read_actions_entries(run_dir)
    derived.update(derive_loop_counters(entries))
    measured = measured_iteration_costs(entries)
    has_durable = ((run_dir / "budget.json").exists()
                   or (run_dir / "council-cost.json").exists())
    if measured or has_durable:
        cost = sum(measured)
        try:
            from lib.pipeline_loop import reconcile_loop_cost  # lazy: evita ciclo
            cost = float(reconcile_loop_cost(run_dir, cost) or 0.0)
        except Exception:
            pass  # fail-open: sobra a soma medida (nada, se não houve medida)
        # `measured` presente ⇒ há medição, e um zero medido é fato publicável.
        if measured or cost > 0:
            derived["loop_cost_usd"] = round(cost, 6)
    return derived


def ensure_lessons_consulted(
    run_dir: "str | Path",
    *,
    force: bool = False,
    limit: int = 3,
) -> list:
    """TCK-1232: write-back universal de ``lessons_consulted`` (reflect 0/65).

    Problema: só orchestrator/driver-com-executor gravavam o campo. Caminho
    agent-driven (cbctl run + finalize) e driver external deixavam
    ``null``/ausente → reflect reportava coverage 0% mesmo com canal de
    lições vivo (TCK-1135/1213).

    Comportamento:
      - se ``lessons_consulted`` já é lista **não-vazia** e ``force=False`` → no-op
      - se ``null``/ausente (ou ``force=True`` ou lista vazia com force) → consulta
        via ``lesson_channel.consult_lessons_with_fallback`` e grava needles
        (lista de str). Consulta vazia grava ``[]`` (medido: zero lições),
        distinguível de ``null`` (não medido).
    Fail-open: qualquer erro → devolve o valor atual (ou []) sem raise.
    """
    run_dir = Path(run_dir)
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    if not isinstance(data, dict):
        return []

    current = data.get("lessons_consulted")
    if (
        not force
        and isinstance(current, list)
        and len(current) > 0
    ):
        return list(current)

    # null / missing / empty (when force) → consult
    if (
        not force
        and isinstance(current, list)
        and len(current) == 0
        and current is not None
    ):
        # Empty list may mean "consulted, none found" — only refill if force.
        # But scaffold often seeds [] without consult. Treat empty as refill
        # candidate when ticket exists (TCK-1232): cheap consult, fail-open.
        pass  # fall through to consult

    ticket = str(data.get("ticket") or "").strip()
    if not ticket:
        # Sem ticket não há o que consultar — marca medido-vazio se era null
        if data.get("lessons_consulted") is None:
            data["lessons_consulted"] = []
            try:
                rj.write_text(
                    json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                )
            except OSError:
                pass
        return list(data.get("lessons_consulted") or [])

    needles: list[str] = []
    try:
        from lib.lesson_channel import consult_lessons_with_fallback
        # repo root = parents of .archagents/13-execution/runs/<id>
        root = run_dir
        for _ in range(6):
            if (root / ".archagents").is_dir() or (root / "scripts" / "lib").is_dir():
                break
            root = root.parent
        result = consult_lessons_with_fallback(ticket, root=root, limit=limit)
        needles = [
            str(n).strip()
            for n in (result.get("needles") or [])
            if str(n).strip()
        ]
        if not needles:
            # fallback: lesson text prefixes as needles
            for lesson in result.get("lessons") or []:
                if not isinstance(lesson, dict):
                    continue
                text = str(lesson.get("lesson") or lesson.get("text") or "").strip()
                if text:
                    needles.append(text[:80])
    except Exception:
        needles = list(current) if isinstance(current, list) else []

    merged = list(dict.fromkeys(
        list(current if isinstance(current, list) else []) + needles
    ))
    # Only touch lessons_consulted — NÃO chamar ensure_loop_telemetry aqui
    # (ele normaliza null→default e apaga a semântica "not measured" dos
    # demais campos medidos; TCK-1129).
    data["lessons_consulted"] = merged
    try:
        rj.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except OSError:
        pass
    return list(data.get("lessons_consulted") or [])


def finalize_loop_telemetry(run_dir: "str | Path") -> dict:
    """TCK-1129 + TCK-1232: write-back da finalização Fase-7 (agent-driven).

    Preenche os campos medidos que ainda estão null/ausentes no run.json com os
    valores derivados de artefatos reais (derive_loop_telemetry). NUNCA
    sobrescreve valor não-null já escrito por outro produtor (orquestrador,
    judge, stamp-run-cost, record_lessons_consulted) — o valor real existente
    sempre vence. Campo sem evidência MANTÉM o null explícito ("not measured"),
    para o reflect distinguir de um zero medido.

    TCK-1232: após a derivação, chama ``ensure_lessons_consulted`` quando
    ``lessons_consulted`` está null/ausente/vazio — path universal (não só
    orchestrator/driver-com-executor).

    Fail-open: run.json ausente/ilegível retorna {} e não escreve nada.
    Retorna o dict final do run.json (pós-write) ou {} em falha.
    """
    run_dir = Path(run_dir)
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    for key, value in derive_loop_telemetry(run_dir).items():
        if key in LOOP_TELEMETRY_MEASURED_FIELDS and data.get(key) is None:
            data[key] = value
    try:
        rj.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    except OSError:
        return {}
    # TCK-1232: consult lessons if not yet measured (null/[] without needles)
    try:
        ensure_lessons_consulted(run_dir, force=False)
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        pass
    return data if isinstance(data, dict) else {}


def finalize_run_status(run_dir: "str | Path", *, status: str = "completed",
                        note: str = "") -> bool:
    """TCK-1447: transiciona o run para status TERMINAL quando o trabalho acabou.

    Lacuna medida: o pipeline-driver gravava ``drive.final_status=done`` mas
    nunca tocava o ``status`` top-level — todo run do driver ficava ``running``
    para sempre. O dashboard contava 6 runs "ativos" cujos tickets estavam
    ``done`` (zumbis até o marcador de staleness de 24h).

    Contrato:
      - só transiciona a partir de status ATIVO (``running``/``paused-*``) ou
        ausente — status terminal já escrito NUNCA é sobrescrito (mesma
        doutrina do finalize_loop_telemetry: o valor real existente vence);
      - grava ``ended_at`` (verify-run trata ativo+ended_at como violação —
        o par muda junto);
      - espelha ``status``/``end_time`` no frontmatter do REPORT.md, best-effort
        (o REPORT nasce com ``status: running`` + ``end_time: null``);
      - fail-open: run.json ausente/ilegível retorna False sem levantar.
    """
    if status not in TERMINAL_STATUSES:
        return False
    run_dir = Path(run_dir)
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    if not isinstance(data, dict):
        return False
    current = str(data.get("status") or "").lower()
    if current in TERMINAL_STATUSES:
        return False  # terminal já escrito vence
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    data["status"] = status
    # não usar setdefault: create_run grava "ended_at": null EXPLÍCITO, e
    # setdefault não substitui chave presente com None.
    if not data.get("ended_at"):
        data["ended_at"] = now
    if note:
        data["result"] = note
    try:
        rj.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    except OSError:
        return False
    # Espelho no REPORT.md (best-effort): frontmatter é o 1º bloco --- ... ---
    report = run_dir / "REPORT.md"
    try:
        text = report.read_text(encoding="utf-8")
        if text.startswith("---"):
            head, sep, tail = text[3:].partition("---")
            head = re.sub(r"(?m)^status:\s*.*$", f"status: {status}", head, count=1)
            # TCK-1117: espelhar o `ended_at` EFETIVO, não `now`. O run.json já
            # respeita um valor pré-semeado (`if not data.get("ended_at")` acima);
            # usar `now` aqui fazia os dois artefatos descreverem o mesmo run com
            # instantes diferentes, e o REPORT — o que um humano lê — ficava com o
            # fabricado. Medido fechando 22 runs de 2026-08-10: 22/22 divergiram.
            head = re.sub(r"(?m)^end_time:\s*.*$",
                          f"end_time: {data['ended_at']}", head, count=1)
            report.write_text("---" + head + sep + tail, encoding="utf-8")
    except OSError:
        pass
    return True


def backfill_completed_missing_ended_at(run_dir: "str | Path") -> "str | None":
    """TCK-2770 — fecha `run.json status: completed` com `ended_at: null`.

    Espelho de `backfill_stale_run_status` na direcao OPOSTA do MESMO defeito
    de sincronizacao REPORT.md<->run.json: la o STATUS ficava preso ATIVO
    (`running`) com o REPORT ja terminal; aqui o STATUS ja e o terminal certo
    (`completed`) e so o TIMESTAMP nunca chegou. `backfill_stale_run_status`
    devolve None em silencio para todo run cujo status atual ja e terminal
    (`if current not in ACTIVE_STATUSES: return None`) — e por isso os 54 do
    TCK-2770 escaparam do TCK-2694: o predicado dele nunca olhava para eles.

    Tres fontes de evidencia REAL, nesta ordem — a primeira que existir
    decide; nunca combina, nunca inventa:
      1. ``run.json["finished_at"]`` — alias legado que runs antigos (pre
         padronizacao de `ended_at`) gravam com o MESMO dado em chave
         diferente.
      2. ``REPORT.md`` frontmatter ``end_time`` (TCK-0979/TCK-2694) — o
         relatorio ja registrou a hora real; so o run.json nunca sincronizou.
      3. Backreferencia: qualquer ``RET-*.md`` sob ``.archagents/retired/``
         cujo frontmatter declare ``run: <este run_id>`` — o MAIOR
         ``retired_at`` entre eles e o ultimo instante de atividade REAL do
         run, provado por um artefato que o proprio run produziu (nao e o
         "agora" do backfill). Cobre runs sem REPORT.md e sem `finished_at`
         (ex.: chores ad-hoc que so gravaram `run.json` + retirement records).

    Sem NENHUMA das tres: recusa tocar e devolve None — mesma doutrina
    ADR-0029/TCK-2477 de nunca escrever ``now()`` num run de dias/semanas
    atras. Nunca sobrescreve um ``ended_at`` ja preenchido, nem mexe num
    ``status`` diferente de ``completed`` (essa metade e do
    `backfill_stale_run_status`).

    Marca ``status_backfilled_by = "TCK-2770"`` — proveniencia distinta do
    TCK-2694 (a outra direcao), para quem ler saber qual defeito foi
    corrigido e por qual ticket.

    Retorna o `ended_at` escrito, ou None se nada mudou.
    """
    run_dir = Path(run_dir)
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    if str(data.get("status") or "").lower() != "completed":
        return None  # nao e desta metade — active status e do backfill gemeo
    if data.get("ended_at"):
        return None  # ja preenchido — o valor real existente sempre vence

    evidence: str | None = None
    tier: str | None = None

    # Tier 1: alias legado no proprio run.json
    finished_at = data.get("finished_at")
    if isinstance(finished_at, str) and finished_at.strip():
        evidence = finished_at.strip()
        tier = "finished_at-legado"

    # Tier 2: REPORT.md end_time
    if evidence is None:
        report = run_dir / "REPORT.md"
        if report.exists():
            try:
                from lib.frontmatter import parse_frontmatter
                fm = parse_frontmatter(report.read_text(encoding="utf-8"))
                end_raw = fm.get("end_time")
                if end_raw not in (None, "", "null"):
                    evidence = str(end_raw)
                    tier = "report-end_time"
            except Exception:
                pass

    # Tier 3: backreferencia em RET-*.md que este run produziu
    if evidence is None:
        root = run_dir
        for _ in range(8):
            if (root / ".archagents").is_dir():
                break
            root = root.parent
        retired_dir = root / ".archagents" / "retired"
        if retired_dir.is_dir():
            run_id = run_dir.name
            candidates: list[str] = []
            for ret in sorted(retired_dir.glob("RET-*.md")):
                try:
                    from lib.frontmatter import parse_frontmatter
                    fm = parse_frontmatter(ret.read_text(encoding="utf-8"))
                except Exception:
                    continue
                if str(fm.get("run") or "") != run_id:
                    continue
                ts = fm.get("retired_at")
                if isinstance(ts, str) and ts.strip():
                    candidates.append(ts.strip())
            if candidates:
                # INFERIDO, nao copiado: e o ultimo instante em que o run
                # comprovadamente estava VIVO, logo um limite INFERIOR do fim.
                evidence = max(candidates)  # ISO-8601 ordena lexicograficamente
                tier = "ret-backreferencia-LIMITE-INFERIOR"

    if evidence is None:
        return None  # sem nenhuma prova — nao fabrica, nao toca

    data["ended_at"] = evidence
    data["status_backfilled_by"] = "TCK-2770"
    # A PROCEDENCIA VIAJA COM O DADO (integrador, 2026-08-22). As 3 tiers nao
    # sao equivalentes: 1 e 2 COPIAM um fim registrado; a 3 INFERE a partir do
    # ultimo instante em que o run comprovadamente estava vivo (um RET-*.md que
    # ele produziu). Isso e limite INFERIOR, nao o fim.
    #
    # Sem este campo os 54 carregam o mesmo marcador e quem ler o run.json
    # amanha nao distingue "copiei o fim" de "inferi que ele ainda estava vivo
    # aqui" — que e a classe `declared-provenance-beats-heuristic`, dentro do
    # produtor que existe para nao fabricar.
    data["ended_at_evidence"] = tier
    try:
        rj.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    except OSError:
        return None
    return evidence


def backfill_stale_run_status(run_dir: "str | Path", *, ticket_is_terminal: bool = False,
                              stale_hours: int = STALE_AFTER_HOURS) -> "str | None":
    """TCK-2694 — fecha `status: running` orfao com a PROPRIA evidencia gravada.

    Nao fabrica timestamp (doutrina ADR-0029/TCK-2477: escrever `ended_at:
    now()` num run de dias atras e invencao, nao medicao — a decisao
    documentada em zombie-run-scan.py para o mesmo tipo de objeto). Duas
    rotas, nesta ordem — a primeira que casar decide:

      1. REPORT.md (frontmatter, TCK-0979) ja e TERMINAL: run.json so nao foi
         sincronizado (mesma classe do TCK-1447/`finalize_run_status`, so que
         medida bem depois). Copia `status` + `end_time` REAIS do REPORT.md —
         nao inventa nada, so propaga o que ja estava escrito.
      2. REPORT.md continua ATIVO (`running`/`draft`, sem `end_time`) mas o
         run esta stale (`is_stale`, > `stale_hours`) e o CHAMADOR confirma
         que o ticket associado ja fechou (`ticket_is_terminal=True`): o run
         morreu sem nunca ser finalizado. Grava `aborted` — nao ha prova de
         sucesso, so de abandono — com `ended_at: None` explicito (a verdade
         e "nao sabemos quando parou", nunca "agora"). Espelha o mesmo
         veredito em REPORT.md para as duas fontes pararem de se contradizer.

    Sem nenhuma das duas provas: recusa tocar (retorna None) — nunca adivinha
    o destino de um run que ainda pode estar em curso ou cujo ticket segue
    aberto. Terminal ja escrito tambem nunca e sobrescrito (mesma doutrina de
    `finalize_run_status`/`finalize_loop_telemetry`: o valor real vence).

    Marca `status_backfilled_by` no run.json — proveniencia: isto NAO foi uma
    transicao ao vivo, foi inferido a partir de evidencia ja existente.

    Retorna o novo status escrito, ou None se nada mudou.
    """
    run_dir = Path(run_dir)
    rj = run_dir / "run.json"
    try:
        data = json.loads(rj.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    current = str(data.get("status") or "").lower()
    if current not in ACTIVE_STATUSES:
        return None  # terminal ja escrito vence; nada ativo, nada a fazer

    report_status: str | None = None
    report_end: str | None = None
    report_text: str | None = None
    report = run_dir / "REPORT.md"
    if report.exists():
        try:
            report_text = report.read_text(encoding="utf-8")
            from lib.frontmatter import parse_frontmatter
            fm = parse_frontmatter(report_text)
            report_status = str(fm.get("status", "")).lower() or None
            end_raw = fm.get("end_time")
            if end_raw not in (None, "", "null"):
                report_end = str(end_raw)
        except Exception:
            report_status = None
            report_text = None

    new_status: str | None = None
    new_ended: str | None = None
    mirror_report = False
    if report_status in TERMINAL_STATUSES:
        new_status = report_status
        new_ended = report_end
    elif ticket_is_terminal and is_stale(data.get("started_at"), hours=stale_hours):
        new_status = "aborted"
        new_ended = None
        mirror_report = True
    else:
        return None

    data["status"] = new_status
    data["ended_at"] = new_ended
    data["status_backfilled_by"] = "TCK-2694"
    try:
        rj.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                      encoding="utf-8")
    except OSError:
        return None

    if mirror_report and report_text is not None:
        try:
            if report_text.startswith("---"):
                head, sep, tail = report_text[3:].partition("---")
                head = re.sub(r"(?m)^status:\s*.*$", f"status: {new_status}", head, count=1)
                report.write_text("---" + head + sep + tail, encoding="utf-8")
        except OSError:
            pass

    return new_status


def record_pause(run_dir: "Path", kind: str, reason: str = "") -> bool:
    """TCK-0529: evento DURÁVEL de pausa em run.json (`pauses: [...]`).

    `status`/`final_status` são transientes — o resume sobrescreve e o
    human_touch_rate sub-registra (auditoria 2026-07-03: 2 runs pausados na
    história, 0 contáveis). O evento append-only preserva o fato para o
    aggregate_autonomy. Fail-open: nunca propaga erro (pausar > contabilizar).
    """
    import json as _json
    from datetime import datetime as _dt, timezone as _tz
    rj = Path(run_dir) / "run.json"
    try:
        data = _json.loads(rj.read_text(encoding="utf-8"))
        data.setdefault("pauses", []).append({
            "at": _dt.now(_tz.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "kind": kind,
            "reason": reason[:200],
        })
        rj.write_text(_json.dumps(data, indent=2, ensure_ascii=False),
                      encoding="utf-8")
        return True
    except (OSError, ValueError):
        return False


if __name__ == "__main__":  # TCK-1129: finalize helper CLI (Fase-7 agent-driven)
    import argparse
    import sys
    import bootstrap as _bootstrap  # scripts/lib é sys.path[0] neste modo
    _bootstrap.ensure_scripts_on_path()  # p/ o lazy-import de lib.pipeline_loop
    _ap = argparse.ArgumentParser(
        description="runstate helpers — finalização de telemetria de loop")
    _ap.add_argument(
        "--finalize-run", metavar="RUN_DIR",
        help="Deriva telemetria real dos artefatos do run e preenche os campos "
             "null do run.json (nunca sobrescreve valores já medidos).")
    _ap.add_argument(
        "--backfill-lessons", metavar="RUNS_DIR",
        help="TCK-1232: percorre RUNS_DIR/*/run.json e garante lessons_consulted "
             "via consult_lessons_with_fallback (fail-open).")
    _ap.add_argument(
        "--force", action="store_true",
        help="Com --backfill-lessons: reconsulta mesmo se lista não-vazia.")
    _ns = _ap.parse_args()
    if _ns.finalize_run:
        _out = finalize_loop_telemetry(_ns.finalize_run)
        if not _out:
            print(f"erro: run.json ausente/ilegível em {_ns.finalize_run}",
                  file=sys.stderr)
            sys.exit(1)
        print(json.dumps({k: _out.get(k) for k in LOOP_TELEMETRY_FIELDS},
                         indent=2, ensure_ascii=False))
        sys.exit(0)
    if _ns.backfill_lessons:
        runs_root = Path(_ns.backfill_lessons)
        filled = 0
        nonempty = 0
        for rj in sorted(runs_root.glob("*/run.json")):
            before = None
            try:
                before = json.loads(rj.read_text(encoding="utf-8")).get(
                    "lessons_consulted")
            except (OSError, ValueError):
                continue
            after = ensure_lessons_consulted(rj.parent, force=_ns.force)
            filled += 1
            if after:
                nonempty += 1
            status = "nonempty" if after else "empty"
            changed = before != after
            print(f"{rj.parent.name}: {status} n={len(after)} "
                  f"{'changed' if changed else 'same'}")
        print(f"backfill done: {filled} runs, {nonempty} with lessons")
        sys.exit(0)
