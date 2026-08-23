#!/usr/bin/env python3
"""lesson_utility.py — measure whether consulted lessons helped (SPC-0028 unit 2 / TCK-0225).

After a run, lesson utility correlates the lessons that were consulted before
execution (run.json `lessons_consulted`) with the run's outcome:
  - higher final_judge_delta (judge score improvement) => higher utility
  - more loop_iterations despite consulting lessons    => lower utility

Pure and deterministic so it is trivially testable and side-effect free.
Advisory only (SPC-0028 §Riscos): treat the score as a signal for strategy
selection / reflection, never as a hard gate. Runs that consulted no lessons
return neutral utility 0.0 (the metric is undefined, not "bad").

Normalization (ADR-0018 / TCK-0795): final_judge_delta = judge_score − 50
(fixed baseline), so its reachable range is [−50, +50]. Utility divides by
DELTA_SCALE=50 — "fraction of the path from baseline to ceiling" — making
utility 1.0 = perfect judge score, 0.6 = score 80, 0.5 = score 75. The old
/100 normalization made the 0.50 target require a *perfect* score on every
run (rubric ceiling ≈ 0.31 observed), which was a calibration bug, not an
ambitious target.
"""
from __future__ import annotations

from datetime import datetime, timezone

ITERATION_PENALTY = 0.1  # utility lost per extra loop iteration beyond the first
DELTA_SCALE = 50.0  # ADR-0018: delta range is ±50 (judge score − baseline 50)

# TCK-0838: utility decay — reinforcement (TCK-0837) alone only grows the
# score; without decay, a lesson that stopped being useful (or stopped being
# consulted) keeps its old high utility_score forever. Half-life default of
# 90 days means an untouched lesson loses half its utility_score every 90
# days, nudging stale entries toward the neutral 0.0 baseline (never below
# -1.0/above 1.0 — see clamp_utility).
DEFAULT_HALF_LIFE_DAYS = 90.0


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


def _has_measured_judge_delta(rd: dict) -> bool:
    """True when final_judge_delta is a real measurement (not scaffold default).

    TCK-1234: ``None``/absent = not measured. A bare ``0.0`` without judge
    attach evidence (``lesson_utility`` written by pipeline-judge, or explicit
    ``final_judge_delta_source``) is treated as unmeasured — ``ensure_loop_telemetry``
    used to coerce null→0.0 and dilute utility after consult backfills.
    """
    if "final_judge_delta" not in rd or rd.get("final_judge_delta") is None:
        return False
    src = rd.get("final_judge_delta_source")
    if src in ("judge", "orchestrator", "escalation"):
        return True
    # TCK-1235 + TCK-2178: o proxy É medição AQUI, deliberadamente — este é o
    # sinal POR RUN, e o veredito do criteria-check é a melhor evidência que
    # existe quando o judge não rodou. A decisão fica em CÓDIGO e não em
    # comentário porque o gate `check-provenance-consumers` não distingue
    # "admite de propósito" de "esqueceu": quem admite, declara.
    # Quem NÃO pode admitir é o denominador agregado — `is_judge_measured`.
    if src == "criteria-proxy":
        return True
    # Judge attach always writes lesson_utility alongside the delta.
    if isinstance(rd.get("lesson_utility"), dict):
        return True
    try:
        fjd = float(rd.get("final_judge_delta"))
    except (TypeError, ValueError):
        return False
    # Non-zero deltas are always measurements (can't come from int default alone
    # without a writer — default is exactly 0.0).
    if abs(fjd) > 1e-9:
        return True
    # Bare zero with no judge evidence → unmeasured.
    return False


MEASURED_JUDGE_SOURCES = frozenset({"judge", "orchestrator", "escalation"})


def is_judge_measured(rd: dict) -> bool:
    """Procedência ESTRITA: o delta veio de um juiz, declarado pelo produtor.

    TCK-2178. Distinta de `_has_measured_judge_delta`, que é o predicado do
    sinal POR RUN e admite `criteria-proxy` de propósito (TCK-1235: o proxy é
    utilidade por run derivada do veredito). Aqui é o predicado do
    DENOMINADOR AGREGADO, onde o proxy é constante por construção — todo run
    aprovado recebe 25.0 e todo approved-with-notes 15.0, qualquer que tenha
    sido a lição. Ele não distingue o que a métrica existe para distinguir.

    Medido em 2026-08-08 sobre 218 runs: 36 dos 50 do denominador (72%) eram
    proxy; a média ia de 0.410 para 0.684 sem eles, cruzando dois gates.

    Espelha `strategy._has_judge_measured_delta` (TCK-2027) — os dois leem o
    mesmo campo e agora selecionam a mesma população. Esta duplicação é
    deliberada: `strategy` não importa `lesson_utility`, e o gate
    `check-provenance-consumers.py` vigia que não divirjam de novo.

    A rejeição do verify que produziu esta função: a v1 punha a guarda dentro
    de `_has_measured_judge_delta`, o que mudava o sinal por run E o produtor
    (`artifacts.py` gravaria `no-outcome` em todo run carimbado), regredindo
    `test_criteria_proxy_delta`. Escopo agregado, não per-run.
    """
    if not _has_measured_judge_delta(rd):
        return False
    return str(rd.get("final_judge_delta_source") or "") in MEASURED_JUDGE_SOURCES


def compute_lesson_utility(run_data: dict) -> dict:
    """Per-run lesson utility in [-1.0, 1.0]. Neutral 0.0 when no lessons consulted.

    TCK-1234: when lessons were consulted but ``final_judge_delta`` is missing
    (``None`` / absent — not measured), return signal ``no-outcome``. Utility is
    undefined without an outcome signal; callers that average must exclude these
    so retroactive ``lessons_consulted`` backfills do not dilute the mean to ~0.
    Explicit ``final_judge_delta: 0`` remains a measured neutral outcome.
    """
    rd = run_data or {}
    lessons = rd.get("lessons_consulted") or []
    if not isinstance(lessons, list):
        lessons = list(lessons) if lessons else []
    n = len(lessons)
    if n == 0:
        return {"utility": 0.0, "n_lessons": 0, "lessons_consulted": [], "signal": "no-lessons"}

    # Distinguish "not measured" from measured 0.0.
    if not _has_measured_judge_delta(rd):
        return {
            "utility": 0.0,
            "n_lessons": n,
            "lessons_consulted": list(lessons),
            "signal": "no-outcome",
        }

    delta = _as_float(rd.get("final_judge_delta"))
    iterations = _as_int(rd.get("loop_iterations"))

    utility = delta / DELTA_SCALE
    if iterations > 1:
        utility -= ITERATION_PENALTY * (iterations - 1)
    utility = max(-1.0, min(1.0, utility))

    return {
        "utility": round(utility, 3),
        "n_lessons": n,
        "lessons_consulted": list(lessons),
        "signal": "computed",
    }


def _is_synthetic_warmup(run_data: dict) -> bool:
    """TCK-0747: exclude consult-only warm-ups from utility averages.

    Only runs explicitly tagged ``warmup: true`` or ``judge_skipped: true``
    are filtered — never a magic ``final_judge_delta==14`` heuristic (that
    would erase real empty-diff judge scores).
    """
    rd = run_data or {}
    if rd.get("warmup") is True or rd.get("judge_skipped") is True:
        return True
    # Nested report metadata (warm-up REPORT path)
    meta = rd.get("meta") if isinstance(rd.get("meta"), dict) else {}
    if meta.get("warmup") is True or meta.get("judge_skipped") is True:
        return True
    return False


def aggregate_lesson_utility(run_datas) -> dict:
    """Average per-run utility across runs that consulted lessons **and** have
    a measured outcome (``final_judge_delta`` not null).

    Runs without consulted lessons are excluded (utility undefined, not zero).
    TCK-1234: runs with lessons but no measured judge delta (signal
    ``no-outcome``) are excluded from the average so retroactive consult
    backfills do not collapse utility toward 0. They still count in
    ``n_runs_consulted`` for coverage metrics.

    TCK-0747: synthetic warm-ups (``warmup`` / ``judge_skipped``) are also
    excluded so consult-path smoke runs do not freeze utility at the empty-diff
    baseline (delta=14 → 0.14).

    TCK-2178: runs whose delta was stamped ``criteria-proxy`` are excluded too
    (the producer declared it is not a judge measurement), and the size of both
    the surviving denominator (``runs_with_judge_outcome``) and the exclusion
    (``runs_excluded_proxy``) travel with the average — measured 2026-08-08,
    the exclusion moved the population from 50 to 14 and the mean from 0.410
    to 0.684, which crosses the reflect gate. A number that changes a gate must
    carry its own n.
    """
    utilities = []
    n_consulted = 0
    n_no_outcome = 0
    excluded_warmups = 0
    excluded_proxy = 0          # TCK-2178: cobertura declarada, não silêncio
    excluded_unknown = 0        # procedência ausente ≠ proxy: causas distintas
    for rd in run_datas or []:
        if _is_synthetic_warmup(rd):
            excluded_warmups += 1
            continue
        u = compute_lesson_utility(rd)
        if u["n_lessons"] <= 0:
            continue
        n_consulted += 1
        if u.get("signal") == "no-outcome":
            n_no_outcome += 1
            continue
        # TCK-2178: o denominador exige procedência de JUIZ. O proxy segue
        # válido como sinal por run (TCK-1235) — só não vota na média.
        if not is_judge_measured(rd):
            # Ressalva do verify: um contador só para as duas exclusões faria o
            # rótulo sobre-afirmar. São causas diferentes e remédios diferentes:
            # proxy = o produtor declarou que não é juiz; ausente = ninguém
            # declarou nada (legado). Separadas.
            if rd.get("final_judge_delta_source") == "criteria-proxy":
                excluded_proxy += 1
            else:
                excluded_unknown += 1
            continue
        utilities.append(u["utility"])
    if not utilities:
        return {
            "lesson_utility_avg": 0.0,
            # Backward-compat: n_runs_with_lessons = outcome cohort (used by
            # loop_quality / reflect utility rec). Coverage uses n_runs_consulted.
            "n_runs_with_lessons": 0,
            "n_runs_consulted": n_consulted,
            "n_runs_no_outcome": n_no_outcome,
            "n_warmup_excluded": excluded_warmups,
            # TCK-2178: o denominador REAL e o que ficou de fora, sempre.
            "runs_with_judge_outcome": 0,
            "runs_excluded_proxy": excluded_proxy,
            "runs_excluded_unknown_source": excluded_unknown,
        }
    return {
        "lesson_utility_avg": round(sum(utilities) / len(utilities), 3),
        "n_runs_with_lessons": len(utilities),
        "n_runs_consulted": n_consulted,
        "n_runs_no_outcome": n_no_outcome,
        "n_warmup_excluded": excluded_warmups,
        # TCK-2178: uma media sobre 14 runs apresentada igual a uma sobre 50
        # mente por omissao. O n do denominador REAL viaja junto do numero.
        "runs_with_judge_outcome": len(utilities),
        "runs_excluded_proxy": excluded_proxy,
        "runs_excluded_unknown_source": excluded_unknown,
    }


# ---------------------------------------------------------------------------
# TCK-0837/TCK-0838: reinforcement + decay — pure math, no I/O.
#
# Reads/writes to the lessons.json store live in lib/db.py (the canonical
# write API, SPC-0032/F0.2); this module stays a pure/deterministic math
# library so both the writer (lib/db.py) and tests can exercise the formulas
# without touching the filesystem.
# ---------------------------------------------------------------------------

REINFORCE_SUCCESS_DELTA = 0.1  # TCK-0837: utility bump on a successful consulted run
REINFORCE_FAILURE_DELTA = -0.05  # TCK-0837: utility penalty on a failed consulted run
UTILITY_MIN = -1.0
UTILITY_MAX = 1.0


def clamp_utility(value: float, lo: float = UTILITY_MIN, hi: float = UTILITY_MAX) -> float:
    """Clamp a utility_score into [lo, hi]. Never raises on bad input (fail-open 0.0)."""
    v = _as_float(value, 0.0)
    return max(lo, min(hi, v))


def reinforce_utility(current: float, *, success: bool) -> float:
    """Q-value-style incremental utility update (TCK-0837): +0.1 on success,
    -0.05 on failure, clamped to [-1, 1]. Pure — no I/O, no side effects."""
    delta = REINFORCE_SUCCESS_DELTA if success else REINFORCE_FAILURE_DELTA
    return round(clamp_utility(_as_float(current, 0.0) + delta), 4)


def compute_decay_factor(days_since: float, half_life_days: float = DEFAULT_HALF_LIFE_DAYS) -> float:
    """Exponential decay factor in (0, 1] for ``days_since`` days of inactivity.

    factor = 0.5 ** (days_since / half_life_days) — after one half_life_days
    period the factor is 0.5; after two, 0.25; etc. Fail-open: a non-positive
    or unparsable half_life_days falls back to DEFAULT_HALF_LIFE_DAYS so a
    caller can never accidentally produce a zero-division or negative-inf.
    Negative days_since (clock skew) is clamped to 0 (factor == 1.0, no decay).
    """
    hl = _as_float(half_life_days, DEFAULT_HALF_LIFE_DAYS)
    if hl <= 0:
        hl = DEFAULT_HALF_LIFE_DAYS
    days = max(0.0, _as_float(days_since, 0.0))
    return 0.5 ** (days / hl)


def decayed_utility(score: float, days_since: float,
                     half_life_days: float = DEFAULT_HALF_LIFE_DAYS) -> float:
    """Apply compute_decay_factor to ``score``, clamped. Pure, fail-open."""
    factor = compute_decay_factor(days_since, half_life_days)
    return round(clamp_utility(_as_float(score, 0.0) * factor), 4)


def days_since_iso(timestamp_iso: "str | None", now: "datetime | None" = None) -> float:
    """Days elapsed between an ISO-8601 timestamp and ``now`` (default: current UTC).

    Fail-open: missing/unparsable/future timestamps return 0.0 (no decay
    applied) rather than raising — a malformed timestamp must never crash
    the decay job or silently over-decay a lesson.
    """
    if not timestamp_iso:
        return 0.0
    try:
        ts = datetime.fromisoformat(str(timestamp_iso).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return 0.0
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    delta_days = (now - ts).total_seconds() / 86400.0
    return max(0.0, delta_days)
