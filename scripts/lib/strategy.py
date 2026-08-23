#!/usr/bin/env python3
"""strategy.py — loop strategy registry, scoring & suggestion (SPC-0028 unit 3 / TCK-0228).

A "loop strategy" is the named policy a loop ran under (recorded in run.json as
`loop_strategy`). This module:
  - registers the known strategies (list_strategies),
  - scores how effective a strategy was across the runs that used it
    (compute_effectiveness — higher judge delta, fewer iterations => higher score),
  - suggests a strategy for a ticket profile (suggest — DoR clarity, stall history).

Pure and deterministic. Advisory only (SPC-0028 §Riscos): the scores inform
selection and reflection; they never gate execution and never mutate policy
without a human-approved ticket (ratchet, P9).
"""
from __future__ import annotations

import re
from datetime import datetime, timezone

from lib.runstate import parse_iso_safe

ITERATION_PENALTY = 0.1
DEFAULT_STRATEGY = "default"

STRATEGIES = {
    "default": "Bounded retries under default caps; no profile-driven adaptation.",
    "lesson-guided": "Consult prior lessons before each attempt; bias toward known-good fixes.",
    "conservative": "Minimize iterations; escalate early when convergence is poor or stall history is high.",
    "exploratory": "Allow more iterations for ambiguous / low-DoR tickets before escalating.",
}


def _as_float(value, default: float = 0.0) -> float:
    try:
        return float(value if value is not None else default)
    except (TypeError, ValueError):
        return default


def _as_int(value, default: int = 0) -> int:
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default


def list_strategies() -> dict:
    """The registered loop strategies: {name: description}."""
    return dict(STRATEGIES)


def _run_score(run_data: dict) -> float:
    delta = _as_float(run_data.get("final_judge_delta"))
    iterations = _as_int(run_data.get("loop_iterations"))
    score = delta / 100.0
    if iterations > 1:
        score -= ITERATION_PENALTY * (iterations - 1)
    return max(-1.0, min(1.0, score))


# ---------------------------------------------------------------------------
# TCK-2027 / DES-1025 — procedência declarada vence heurística de valor
# ---------------------------------------------------------------------------

#: Procedências de ``final_judge_delta_source`` que representam MEDIÇÃO do judge.
#: Espelha lesson_utility._has_measured_judge_delta:63, mas aqui o teste é
#: ESTRITO: comparar estratégias exige delta do judge, e nada mais.
MEASURED_JUDGE_SOURCES = frozenset({"judge", "orchestrator", "escalation"})


def _has_judge_measured_delta(run_data) -> bool:
    """True só quando o delta foi MEDIDO pelo judge, por procedência declarada.

    TCK-2027. Medido em 2026-08-05 sobre 179 runs: ``criteria-proxy`` 86,
    procedência ausente 85, ``judge`` 8. Os 86 do proxy carregam dois valores
    fixos — 15.0 (55 runs) e 25.0 (31) — porque `artifacts.py:646` os deriva do
    VEREDITO (`approved` → 25, `approved-with-notes` → 15), não da estratégia.

    Daí o critério ser estrito, e não uma questão de "sinal fraco": num
    comparativo ENTRE estratégias o proxy é **constante por construção** — todo
    run aprovado recebe o mesmo número qualquer que tenha sido a estratégia.
    Ele não pode distinguir o que a métrica existe para distinguir; só dilui.

    O produtor é honesto (`artifacts.py:606`: *"never pretends to be judge"*) e
    grava a procedência. Quem errava era o leitor: em
    `lesson_utility._has_measured_judge_delta:72-75` a heurística *"delta
    não-zero é sempre medição, porque o default é exatamente 0.0"* readmitia o
    proxy DEPOIS de a procedência declarada já ter dito o contrário. Aqui a
    ordem se inverte: **declaração vence heurística**; sem declaração, não há
    medição (os 85 legados saem — não sabemos o que são, e supor é o defeito).

    Isto NÃO invalida o proxy no TCK-1235, que segue valendo para utilidade de
    lição por run. É escopo de leitor, não de produtor: nada é apagado (P6).
    """
    rd = run_data if isinstance(run_data, dict) else {}
    if rd.get("final_judge_delta") is None:
        return False
    return str(rd.get("final_judge_delta_source") or "") in MEASURED_JUDGE_SOURCES


# ---------------------------------------------------------------------------
# TCK-0622 — era segmentation (baseline was blind to the CmdExecutor bug)
# ---------------------------------------------------------------------------

#: Pre-TCK-0578 the judge's own CmdExecutor ran max_retries=0 as ZERO attempts
#: (`range(1, 0+1)` is empty) — every score produced during that era (verdicts,
#: lessons, strategy_effectiveness; n=175, quarantined by TCK-0588) was computed
#: against an EMPTY diff, not real output. TCK-0578 fixed the executor and was
#: marked done at 2026-07-03T22:43Z; this cutoff draws the era line a bit
#: earlier (22:00Z, comfortably before the fix landed) so compute_effectiveness
#: stops re-embedding the contaminated baseline on every subsequent judge
#: invocation. Overridable per call via the `era_cutoff` param — tests pin
#: behaviour without depending on the wall clock or a moving "now".
ERA_CUTOFF: str = "2026-07-03T22:00:00Z"

#: Candidate timestamp fields on a run_data dict, in preference order. Real
#: run.json schema drifted across eras (started_at/completed_at/ended_at/
#: finished_at all appear in the wild — see pipeline_reports.generate_run_report
#: and legacy hand-written RUN reports) — the first present + parseable one wins.
_RUN_TIMESTAMP_FIELDS = ("completed_at", "started_at", "ended_at", "finished_at", "timestamp")

#: TCK-0629/N6: dict keys that carry the RUN dir name itself (both observed in
#: the wild — generate_run_report writes "run_id", older hand-written reports
#: write "id"). RUN-YYYYMMDD-HHMMSS-<slug> is the standard shape; a handful of
#: legacy dirs drop the HHMMSS segment (e.g. RUN-20260629-tck0363-remediation).
_RUN_DIR_NAME_FIELDS = ("run_id", "id")
_RUN_DIR_TS_RE = re.compile(r"^RUN-(\d{8})(?:-(\d{6}))?(?:-|$)")


def _parse_run_dir_timestamp(name):
    """Best-effort UTC datetime parsed from a RUN dir name. None on no match
    or an out-of-range date/time (never raises)."""
    if not name or not isinstance(name, str):
        return None
    m = _RUN_DIR_TS_RE.match(name)
    if not m:
        return None
    date_part = m.group(1)
    time_part = m.group(2) or "000000"
    try:
        return datetime.strptime(date_part + time_part, "%Y%m%d%H%M%S").replace(
            tzinfo=timezone.utc)
    except ValueError:
        return None


def _run_timestamp(run_data: dict):
    """Best-effort parsed timestamp for era segmentation (TCK-0622).

    Returns None when no candidate field is present/parseable — never raises.
    A None result is NOT treated as pre-era by _is_pre_era (fail-open: no
    evidence to exclude on — preserves behaviour for synthetic/legacy run
    data that carries no timestamp at all, e.g. existing unit tests).

    TCK-0629/N6: 36 real runs carry none of _RUN_TIMESTAMP_FIELDS at all (an
    older run.json schema) but ARE datable — their RUN dir name is echoed
    back into run_id/id and encodes the timestamp (RUN-YYYYMMDD-HHMMSS-*).
    Tried as a last resort, before giving up and returning None, so these 36
    runs stop being silently dropped from the era-segmented baseline.
    """
    data = run_data or {}
    for key in _RUN_TIMESTAMP_FIELDS:
        dt = parse_iso_safe(data.get(key))
        if dt is not None:
            return dt
    for key in _RUN_DIR_NAME_FIELDS:
        dt = _parse_run_dir_timestamp(data.get(key))
        if dt is not None:
            return dt
    return None


def _is_pre_era(run_data: dict, era_cutoff: str) -> bool:
    """True only when run_data carries a parseable timestamp strictly before
    era_cutoff. A malformed/unparseable era_cutoff, or a run with no usable
    timestamp, both resolve to False (fail-open, TCK-0622)."""
    cutoff_dt = parse_iso_safe(era_cutoff)
    if cutoff_dt is None:
        return False
    run_dt = _run_timestamp(run_data)
    if run_dt is None:
        return False
    return run_dt < cutoff_dt


def compute_effectiveness(run_datas, strategy: str, era_cutoff: "str | None" = ERA_CUTOFF) -> dict:
    """Mean per-run score across runs that ran under `strategy` (missing field => default).

    TCK-0622: entries whose timestamp is strictly before `era_cutoff` (default
    ERA_CUTOFF) are dropped before the mean is taken — they were judged during
    the CmdExecutor zero-attempts era (TCK-0578) and carry no real signal.
    Excluded entries are still counted, via `n_pre_era_excluded` in the
    return, so a caller never mistakes a shrunk sample for the full one. A run
    with no parseable timestamp field is NOT excluded (fail-open — existing
    callers/tests that never set one keep working unchanged). Pass
    era_cutoff=None to disable segmentation entirely (legacy behaviour).
    """
    matching = [
        rd for rd in (run_datas or [])
        if (rd or {}).get("loop_strategy", DEFAULT_STRATEGY) == strategy
    ]
    if era_cutoff:
        after_era = [rd for rd in matching if not _is_pre_era(rd, era_cutoff)]
    else:
        after_era = matching
    n_pre_era_excluded = len(matching) - len(after_era)

    # TCK-2027: segundo filtro, independente da era — procedência do delta.
    runs = [rd for rd in after_era if _has_judge_measured_delta(rd)]
    n_unmeasured_excluded = len(after_era) - len(runs)

    if not runs:
        # `None`, não 0.0: zero é um resultado MEDIDO legítimo (judge neutro), e
        # colapsar os dois é o que fazia três estratégias jamais executadas
        # aparecerem como "efetividade 0.0" — indistinguível de medido-e-neutro.
        return {
            "strategy": strategy, "effectiveness": None, "n_runs": 0,
            "n_pre_era_excluded": n_pre_era_excluded,
            "n_unmeasured_excluded": n_unmeasured_excluded,
        }
    eff = sum(_run_score(rd) for rd in runs) / len(runs)
    return {
        "strategy": strategy, "effectiveness": round(eff, 3), "n_runs": len(runs),
        "n_pre_era_excluded": n_pre_era_excluded,
        "n_unmeasured_excluded": n_unmeasured_excluded,
    }


def suggest(profile: dict) -> dict:
    """Heuristic strategy choice from a ticket profile.

    profile keys (all optional): stall_rate [0..1], dor_score [0..1],
    has_lessons (bool). Conservative when stall history is high, exploratory when
    DoR is weak, lesson-guided when relevant lessons exist, else default.
    """
    p = profile or {}
    stall = _as_float(p.get("stall_rate"))
    dor = _as_float(p.get("dor_score"), 1.0)

    if stall >= 0.3:
        choice, why = "conservative", f"stall_rate {stall} >= 0.3 — escalate early"
    elif dor < 0.7:
        choice, why = "exploratory", f"dor_score {dor} < 0.7 — allow exploration"
    elif p.get("has_lessons"):
        choice, why = "lesson-guided", "relevant prior lessons available"
    else:
        choice, why = DEFAULT_STRATEGY, "clean profile — default caps suffice"

    return {"strategy": choice, "rationale": why}


def select_strategy(profile: dict) -> str:
    """Named, pure entrypoint for the loop strategy policy.

    Returns the strategy `suggest` recommends for a ticket profile as a bare string.
    This is the SAME policy as LoopController.select_strategy (loop_controller.py) —
    one policy, two callers (DSC-0008 / PLN-0005 contract: "chama strategy.select_strategy").
    Both delegate to suggest(), so they agree for every profile. It inherits suggest's
    deterministic branch order: a pure function of the profile alone, no clock, no RNG.
    """
    return suggest(profile)["strategy"]


# ---------------------------------------------------------------------------
# F1.4 — Evidence-gated feedback (TCK-0313 / SPC-0044)
# ---------------------------------------------------------------------------

#: Minimum number of signal runs a strategy must have to be eligible as an
#: override candidate. Strategies with fewer runs are never chosen over the
#: heuristic base — closes the self-contradiction of shifting toward no-evidence.
MIN_RUNS_FOR_FEEDBACK: int = 3

#: Minimum effectiveness advantage a candidate must hold over the heuristic
#: base before we override. Guards against noise-driven thrash on tight margins.
FEEDBACK_MARGIN: float = 0.05

#: The LOOP_TELEMETRY default value for final_judge_delta (runstate.py:165).
#: A run whose delta equals this constant carries no judge signal and is filtered.
_DEFAULT_JUDGE_DELTA: float = 0.0


def select_strategy_with_feedback(profile, run_datas) -> dict:
    """Evidence-gated strategy selection (pure, deterministic, I/O-free).

    Extends suggest() with historical run evidence. When the evidence is strong
    enough it overrides the heuristic base; otherwise it falls back gracefully.

    Algorithm (SPC-0044):
      1. base = suggest(profile)['strategy']
      2. Signal filter: drop runs whose final_judge_delta == _DEFAULT_JUDGE_DELTA
         (a failed/absent judge leaves the field at default — not real signal).
      3. effs[name] = compute_effectiveness(signal_runs, name) for every strategy.
      4. ELIGIBLE = strategies with n_runs >= MIN_RUNS_FOR_FEEDBACK.
      5. best = max(eligible by effectiveness).
         Override only when best != base AND best_eff - base_eff >= FEEDBACK_MARGIN.
      6. Return {strategy, rationale, source ('suggest'|'feedback'),
                 evidence:{n_runs, base_eff, chosen_eff}}.

    Fail-open: None/empty/malformed run_datas degrade to suggest base, source
    'suggest'. Never raises.

    Advisory only (strategy.py:11-13): never widens caps, never mutates policy,
    never bypasses ABSOLUTE_SAFE_MAX_ATTEMPTS.
    """
    # Step 1: heuristic base (fail-open on bad profile)
    try:
        base_result = suggest(profile)
        base = base_result["strategy"]
        base_rationale = base_result["rationale"]
    except Exception:
        base_result = suggest({})
        base = base_result["strategy"]
        base_rationale = base_result["rationale"]

    def _suggest_result(base_strategy: str, rationale: str) -> dict:
        return {
            "strategy": base_strategy,
            "rationale": rationale,
            "source": "suggest",
            "evidence": {"n_runs": 0, "base_eff": 0.0, "chosen_eff": 0.0},
        }

    # Step 2: validate and filter run_datas
    try:
        if not run_datas:
            return _suggest_result(base, base_rationale)

        # Filter to runs that carry real judge signal.
        #
        # TCK-2027: era `delta != _DEFAULT_JUDGE_DELTA`, que barrava só o default
        # 0.0 e deixava passar os 86 runs de `criteria-proxy` (delta 15/25 fixos,
        # derivados do veredito e não da estratégia — ver
        # _has_judge_measured_delta). O predicado de procedência é estritamente
        # mais forte: todo delta default também é não-medido, então este filtro
        # cobre o anterior.
        signal_runs = []
        for rd in run_datas:
            try:
                if _has_judge_measured_delta(rd):
                    signal_runs.append(rd)
            except Exception:
                continue

        if not signal_runs:
            return _suggest_result(base, base_rationale)

        # Step 3: compute effectiveness per strategy over signal_runs only
        effs = {
            name: compute_effectiveness(signal_runs, name)
            for name in STRATEGIES
        }

        # Step 4: eligible = strategies with n_runs >= MIN_RUNS_FOR_FEEDBACK
        #
        # TCK-2027: `effectiveness is None` marca ausência de amostra medida.
        # Quem não foi medido não pode ser "o melhor" — o teste de n_runs já
        # exclui esse caso (n_runs==0 <=> effectiveness None), e a checagem
        # explícita mantém o invariante mesmo se o contrato mudar.
        eligible = {
            name: effs[name]
            for name in STRATEGIES
            if effs[name]["n_runs"] >= MIN_RUNS_FOR_FEEDBACK
            and effs[name]["effectiveness"] is not None
        }

        if not eligible:
            return _suggest_result(base, base_rationale)

        # Step 5: find best among eligible
        best_name = max(eligible, key=lambda n: eligible[n]["effectiveness"])
        best_eff = eligible[best_name]["effectiveness"]
        base_eff_raw = effs[base]["effectiveness"]
        # Base sem amostra medida: trata como neutro na comparação, mas o
        # rationale DIZ que não havia evidência — nunca apresenta o 0.0 de
        # ausência como se fosse um valor observado.
        base_unmeasured = base_eff_raw is None
        base_eff = 0.0 if base_unmeasured else base_eff_raw

        if best_name != base and (best_eff - base_eff) >= FEEDBACK_MARGIN:
            return {
                "strategy": best_name,
                "rationale": (
                    f"Historical evidence favours '{best_name}' over '{base}' "
                    f"(eff {best_eff:.3f} vs "
                    f"{'no measured sample' if base_unmeasured else f'{base_eff:.3f}'}, "
                    f"margin {best_eff - base_eff:.3f} >= {FEEDBACK_MARGIN})"
                ),
                "source": "feedback",
                "evidence": {
                    "n_runs": eligible[best_name]["n_runs"],
                    "base_eff": base_eff,
                    "chosen_eff": best_eff,
                },
            }

        # Sub-threshold or tie: keep base
        n_runs_base = eligible.get(base, effs[base])["n_runs"]
        return {
            "strategy": base,
            "rationale": (
                base_rationale
                if not eligible
                else (
                    f"Evidence below threshold (best '{best_name}' eff {best_eff:.3f}, "
                    f"base '{base}' "
                    f"{'has no measured sample' if base_unmeasured else f'eff {base_eff:.3f}'}, "
                    f"margin {best_eff - base_eff:.3f} < {FEEDBACK_MARGIN})"
                    if best_name != base
                    else f"Base strategy '{base}' is already best (eff {base_eff:.3f})"
                )
            ),
            "source": "suggest",
            "evidence": {
                "n_runs": n_runs_base,
                "base_eff": base_eff,
                "chosen_eff": base_eff,
            },
        }

    except Exception:
        # Fail-open: any unexpected error returns suggest base
        return _suggest_result(base, base_rationale)
