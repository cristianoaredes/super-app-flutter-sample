#!/usr/bin/env python3
"""pipeline_loop.py — Loop control, budget, and strategy-selection functions (FND-0054).

Extracted from pipeline-orchestrator.py.  Functions accept their dependencies as
optional parameters (dependency injection) so callers and tests can pass mocks
directly.  Each parameter falls back to a sensible default when omitted.
"""

import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

from lib.bootstrap import get_repo_root

REPO_ROOT = get_repo_root()


# ---------------------------------------------------------------------------
# INTERNAL DEFAULTS
# ---------------------------------------------------------------------------

def _default_consult_lessons(ticket_id: str) -> list:
    """Fallback: import and call consult_lessons from pipeline_stages."""
    from lib.pipeline_stages import consult_lessons as _cl
    return _cl(ticket_id)


def _default_build_loop_profile(ticket_id: str, repo_root: "Path | None" = None) -> dict:
    """Fallback: call the module-local build_loop_profile."""
    return build_loop_profile(ticket_id, repo_root=repo_root)


def _as_int(value, default: int = 0) -> int:
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default


# ---------------------------------------------------------------------------
# BUDGET / COST FUNCTIONS
# ---------------------------------------------------------------------------

def budget_gate_or_halt(run_dir, *, _logger=None) -> bool:
    """Halt-the-loop-before-iteration gate (F1.3/TCK-0311).

    Wraps budget.enforce_or_pause so it is unit-drivable without the full
    subprocess preflight chain (independently monkeypatchable seam).

    Returns True  -> spend OK, loop continues.
    Returns False -> over budget, loop must break (paused-budget).

    FND-0050: narrowed fail-open contract:
    - FileNotFoundError (no budget file) -> continue (no budget configured).
    - json.JSONDecodeError (corrupt file) -> HALT (data integrity issue;
      a corrupt budget file must not silently allow unbounded spending).
    - Other unexpected exceptions -> HALT with error log (defensive: an
      unknown failure in the budget subsystem is not safe to ignore).
    """
    _log = _logger if _logger is not None else logger
    try:
        from lib import budget as _budget
        result = _budget.enforce_or_pause(run_dir)
        if not result:
            from lib.notifications import send_event
            send_event("budget-exhausted", {"run_dir": str(run_dir)})
        return result
    except FileNotFoundError:
        # No budget file configured -> no cap -> continue (expected path)
        _log.info("No budget file found — running without budget cap")
        return True
    except json.JSONDecodeError as e:
        # FND-0050 critical fix: corrupt budget data MUST halt the loop.
        _log.error(
            "CORRUPT budget file detected in budget gate: %s — HALTING to prevent unbounded spend", e)
        return False
    except Exception as e:
        # Unexpected error in the budget subsystem — halt defensively.
        _log.error("Unexpected error in budget gate (halt-defensive): %s", e)
        return False


def reconcile_loop_cost(run_dir, in_process_cost: float) -> float:
    """TCK-0362 (F3 + FND-LE-005): reconcile in-process cost proxy with durable
    budget.json spend (which includes cross-process council/judge cost) AND the
    council-cost.json per-judge breakdown written by council-orchestrator.

    Returns the MAX of in_process_cost, budget.json spent_usd, and
    council-cost.json council_cost_usd so that run.json loop_cost_usd
    reflects real spend when council ran as a separate process.
    Fail-open: any error returns in_process_cost unchanged.

    FND-0050: corrupt data (JSONDecodeError) is now logged as a warning
    rather than silently swallowed.
    """
    best = in_process_cost
    from lib import budget as _budget  # stdlib-puro; hoisted p/ o except abaixo (TCK-0456)
    try:
        b = _budget.read_budget(run_dir)
        if b and isinstance(b, dict):
            durable = float(b.get("spent_usd", 0.0) or 0.0)
            best = max(best, durable)
    except FileNotFoundError:
        pass  # No budget file -> no durable spend to reconcile
    except _budget.BudgetCorruptError as e:
        # TCK-0456: read_budget agora levanta em corrupção — o branch FND-0050
        # deixa de ser morto; contabilidade segue (o GATE é quem pausa).
        logger.warning("Corrupt budget.json during cost reconciliation: %s", e)
    except json.JSONDecodeError as e:
        logger.warning("Corrupt budget.json during cost reconciliation: %s", e)
    except Exception as e:
        logger.warning("Budget reconciliation failed (fail-open): %s", e)
    # TCK-0362: also read council-cost.json
    try:
        import json as _json
        _council_cost_path = Path(run_dir) / "council-cost.json"
        if _council_cost_path.exists():
            _cc = _json.loads(_council_cost_path.read_text(encoding="utf-8"))
            if isinstance(_cc, dict):
                council_total = float(_cc.get("council_cost_usd", 0.0) or 0.0)
                best = max(best, in_process_cost + council_total)
    except FileNotFoundError:
        pass
    except json.JSONDecodeError as e:
        logger.warning(
            "Corrupt council-cost.json during cost reconciliation: %s", e)
    except Exception as e:
        logger.warning("Council-cost reconciliation failed (fail-open): %s", e)
    return best


# ---------------------------------------------------------------------------
# STRATEGY / PROFILE FUNCTIONS
# ---------------------------------------------------------------------------

# TCK-0415/SPC-0053: evidence floor before stall_rate/dor_score move off the
# neutral defaults — mirrors the evidence-gating philosophy of
# strategy.MIN_RUNS_FOR_FEEDBACK (SPC-0044) without coupling to it (different
# semantics: this gates the PROFILE derivation, not a per-strategy override).
MIN_RUNS_FOR_PROFILE = 3


def _derive_profile_signals(run_datas: list) -> "tuple":
    """TCK-0415/SPC-0053: derive (stall_rate, dor_score) from real run history.

    - stall_rate: fraction of ALL recorded iterations (across the ticket's runs)
      that were NOT the run's terminal iteration — i.e. sum(loop_iterations - 1)
      / sum(loop_iterations). A run needing more than one iteration is exactly
      the "iteration without PASS" signal the loop already records.
    - dor_score: fraction of runs that passed on the FIRST attempt
      (loop_iterations == 1) — a proxy for acceptance-criteria clarity already
      available on the run (no new field, no new call).

    Returns (None, None) when there is not enough usable history
    (< MIN_RUNS_FOR_PROFILE runs with a positive loop_iterations) — the caller
    keeps the neutral defaults in that case (cold start ⇒ unchanged behavior).
    Pure / never raises.
    """
    usable = []
    for rd in (run_datas or []):
        if not isinstance(rd, dict):
            continue
        li = _as_int(rd.get("loop_iterations"))
        if li > 0:
            usable.append(li)
    if len(usable) < MIN_RUNS_FOR_PROFILE:
        return None, None
    total_iterations = sum(usable)
    no_pass_iterations = sum(max(0, li - 1) for li in usable)
    first_try_passes = sum(1 for li in usable if li == 1)
    stall_rate = round(no_pass_iterations / total_iterations, 3) if total_iterations else 0.0
    dor_score = round(first_try_passes / len(usable), 3)
    return stall_rate, dor_score


def build_loop_profile(ticket_id: str, consult_lessons_fn=None,
                       repo_root: "Path | None" = None) -> dict:
    """Advisory ticket profile for loop-strategy selection (F0.1/TCK-0238).

    Failure-open: any error degrades to a neutral profile. has_lessons is
    derived from consult_lessons_fn (or the default import from pipeline_stages).

    TCK-0415/SPC-0053: stall_rate/dor_score are no longer hardcoded constants —
    they are derived from real run history (query_runs(ticket_id), see
    _derive_profile_signals) when there is enough evidence
    (>= MIN_RUNS_FOR_PROFILE usable runs). Without enough history the profile
    stays neutral (stall_rate=0.0, dor_score=1.0) — the SAME behavior as before
    this ticket, preserved on purpose (no evidence ⇒ no divergence).
    """
    profile = {"stall_rate": 0.0, "dor_score": 1.0, "has_lessons": False}
    try:
        _consult = consult_lessons_fn if consult_lessons_fn is not None else _default_consult_lessons
        raw_lessons = _consult(ticket_id) or []
        # TCK-0455: o marcador de índice corrompido ({"error": "index_corrupt"})
        # NÃO é lição — não pode promover a estratégia para lesson-guided.
        profile["has_lessons"] = any(
            not (isinstance(l, dict) and l.get("error")) for l in raw_lessons)
    except Exception as e:
        logger.warning(
            "build_loop_profile failed (advisory, fail-open): %s", e)

    _root = repo_root if repo_root is not None else REPO_ROOT
    try:
        from lib.db import get_db, query_runs
        db = get_db(str(_root))
        try:
            run_datas = query_runs(db, ticket=ticket_id)
        finally:
            db.close()
        stall_rate, dor_score = _derive_profile_signals(run_datas)
        if stall_rate is not None:
            profile["stall_rate"] = stall_rate
        if dor_score is not None:
            profile["dor_score"] = dor_score
    except Exception as e:
        logger.warning(
            "build_loop_profile history derivation failed (advisory, fail-open): %s", e)
    return profile


def select_loop_strategy(ticket_id: str, repo_root: "Path | None" = None,
                         build_loop_profile_fn=None,
                         consult_lessons_fn=None) -> str:
    """F1.4/TCK-0315: testable seam for evidence-gated loop strategy selection.

    Fail-open: any error degrades to LoopController().select_strategy(profile).
    Uses build_loop_profile_fn (or the module-local default) to build the profile.
    Forwards consult_lessons_fn to build_loop_profile when the default profile
    builder is used.
    """
    _root = repo_root if repo_root is not None else REPO_ROOT
    if build_loop_profile_fn is not None and build_loop_profile_fn is not build_loop_profile:
        # Explicit override from caller (e.g. a test mock) — use as-is
        # (single-arg contract; an override may not accept repo_root).
        _build_profile = build_loop_profile_fn
    elif consult_lessons_fn is not None:
        # No override (or same as default): thread consult_lessons_fn AND
        # repo_root through the real build_loop_profile so lesson mocks AND a
        # seeded tmp run-history root both propagate correctly (TCK-0415).
        def _build_profile(tid):
            return build_loop_profile(tid, consult_lessons_fn=consult_lessons_fn, repo_root=_root)
    else:
        # Covers build_loop_profile_fn is None, and the case where the caller
        # passed back the REAL build_loop_profile explicitly — both resolve to
        # the real function with repo_root threaded (TCK-0415: without this,
        # build_loop_profile's own history derivation would silently query the
        # wrong root when repo_root is a seeded tmp dir).
        def _build_profile(tid):
            return build_loop_profile(tid, repo_root=_root)
    try:
        from lib.db import get_db, query_runs
        from lib.strategy import select_strategy_with_feedback
        db = get_db(str(_root))
        try:
            run_datas = query_runs(db, ticket=ticket_id)
        finally:
            db.close()
        profile = _build_profile(ticket_id)
        result = select_strategy_with_feedback(profile, run_datas)
        return result["strategy"]
    except Exception as e:
        logger.warning(
            "select_loop_strategy failed (fail-open, degrading to heuristic): %s", e)
        from lib.loop_controller import LoopController
        return LoopController().select_strategy(_build_profile(ticket_id))


def effective_max_iterations(requested_max: int, loop_strategy: str) -> int:
    """TCK-0415/SPC-0053: loop_strategy modulates the REAL iteration ceiling.

    Ratchet-safe (P9 — only tightens, never widens; SAFETY floor):
      - The result NEVER exceeds min(requested_max, ABSOLUTE_SAFE_MAX_ATTEMPTS).
      - 'conservative' further REDUCES the ceiling (escalate earlier when
        stall history is high).
      - Every other strategy (including 'exploratory', any unrecognised string,
        or None) gets the ratchet ceiling UNCHANGED — never wider than what the
        operator requested via --max-iterations, and never above the absolute
        safe cap. This is a pure, deterministic function — never raises.
    """
    from lib.loop_controller import ABSOLUTE_SAFE_MAX_ATTEMPTS
    base = _as_int(requested_max, default=1)
    if base < 1:
        base = 1
    # Ratchet ceiling: the hard floor no strategy may ever exceed.
    ratchet_ceiling = min(base, ABSOLUTE_SAFE_MAX_ATTEMPTS)
    if loop_strategy == "conservative":
        # Escalate earlier: halve the ceiling (floor division), never below 1.
        return max(1, ratchet_ceiling // 2)
    return ratchet_ceiling


def select_candidate_advisory(candidates: list) -> "str | None":
    """M1/TCK-0327: advisory winner selection via the council tournament.

    Contract: ADVISORY and FAILURE-OPEN.  Returns None on < 2 candidates,
    any exception, or no winner elected.
    """
    if len(candidates) < 2:
        return None
    try:
        from lib.candidates import rank_candidates, select_winner
        result = rank_candidates(candidates)
        return select_winner(result)
    except Exception as e:
        logger.warning("select_candidate_advisory failed (fail-open): %s", e)
        return None
