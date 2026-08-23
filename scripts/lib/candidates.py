"""candidates.py — Candidate ranking library (M1/TCK-0325, SPC-0047).

Exposes two public functions:

  rank_candidates(candidates, compare=None) -> dict
      Runs the existing SPC-0023 Tournament primitive over a list of candidate
      identifiers (diffs/artifacts — NOT strategy.STRATEGIES loop policies).
      Returns the full Tournament result dict:
        {"ranking": [...], "winner": str|None, "converged": bool,
         "rounds": int, "wins": dict}

  select_winner(result) -> str | None
      Extracts result['winner'], returning None on any fail-closed path (a None
      comparison never yields a silent winner — mirrors council-orchestrator.py:597).

Pure and deterministic given a seeded comparator. Advisory only (SPC-0047 §Riscos):
scores inform selection and reflection; they never gate execution and never mutate
policy without a human-approved ticket.
"""
from __future__ import annotations

import sys
import os

# ---------------------------------------------------------------------------
# Import the Tournament class from council_tournament (FND-0054 decomposition).
# Tournament originates from council-orchestrator.py (SPC-0023); it now lives in
# lib/council_tournament.py and is re-exported from council-orchestrator.py for
# backward compatibility.
# ---------------------------------------------------------------------------
from lib.council_tournament import Tournament


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def _default_compare(a: str, b: str) -> str | None:
    """Lexicographic fallback comparator: deterministic, never returns None.

    Returns 'a' if a > b, 'b' if b > a, None on tie (fail-closed).
    This is a sensible default when the caller does not supply one.
    """
    if a > b:
        return "a"
    if b > a:
        return "b"
    return None  # tie → fail-closed, no silent winner


def rank_candidates(
    candidates: list[str],
    compare=None,
    max_rounds: int = 10,
) -> dict:
    """Rank *candidates* via the SPC-0023 Tournament primitive.

    Parameters
    ----------
    candidates:
        Ordered or unordered list of candidate identifiers (e.g. diff hashes,
        artifact paths, PR refs).  Must contain at least one element.
        Explicitly NOT strategy.STRATEGIES loop policies (see scripts/lib/strategy.py).
    compare:
        Callable(a: str, b: str) -> 'a' | 'b' | None.
        'a' → a wins the pair; 'b' → b wins; None → inconclusive (fail-closed,
        no win awarded to either side).  Defaults to lexicographic order.
    max_rounds:
        Maximum tournament rounds before forced termination (default 10).

    Returns
    -------
    dict with keys: ranking (list[str]), winner (str|None), converged (bool),
    rounds (int), wins (dict[str, int]).
    """
    if not candidates:
        return {
            "ranking": [],
            "winner": None,
            "converged": True,
            "rounds": 0,
            "wins": {},
        }

    comparator = compare if compare is not None else _default_compare
    tournament = Tournament(compare=comparator)
    return tournament.run(candidates, max_rounds=max_rounds)


def select_winner(result: dict) -> str | None:
    """Return the tournament winner, or None on any fail-closed path.

    A None comparison never yields a silent winner — this mirrors the doctrine
    from council-orchestrator.py:597 and SPC-0064: absence of a clear verdict
    never becomes a silent victory.

    Parameters
    ----------
    result:
        The dict returned by rank_candidates() (or Tournament.run() directly).

    Returns
    -------
    The winner identifier, or None if the tournament was inconclusive.
    """
    if not isinstance(result, dict):
        return None
    winner = result.get("winner")
    # Explicit None check: do not coerce empty string or falsy values to None
    # — but a genuine None (no winner determined) must stay None.
    return winner if winner is not None else None
