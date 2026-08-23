#!/usr/bin/env python3
"""council_tournament.py — Tournament mode: pairwise ranking of N candidates (FND-0054).

Extracted from council-orchestrator.py (TCK-0181 / SPC-0023). Contains the
Tournament class and helper functions for mock and real candidate ranking.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

# Py3.14 safety: self-register for importlib.util standalone loads.
if __name__ not in sys.modules:  # pragma: no cover
    import types as _types
    sys.modules[__name__] = _types.ModuleType(__name__)


# ---------------------------------------------------------------------------
# Tournament mode (TCK-0181 / SPC-0023): ranking pairwise de N candidatos competindo
# ---------------------------------------------------------------------------

class Tournament:
    """Ranking pairwise de candidatos. `compare(a, b)` retorna 'a', 'b' ou None.

    None = comparação inconclusiva → NENHUMA vitória é atribuída (fail-closed, reusa a doutrina
    do m1/SPC-0064: ausência de veredito claro nunca vira vitória silenciosa). Converge quando o
    ranking estabiliza entre rodadas (ou ao atingir max_rounds)."""

    def __init__(self, compare):
        self.compare = compare

    def run(self, candidates: list[str], max_rounds: int = 10) -> dict:
        prev = None
        converged = False
        rounds = 0
        wins: dict[str, int] = {c: 0 for c in candidates}
        for r in range(max_rounds):
            rounds = r + 1
            wins = {c: 0 for c in candidates}
            for i in range(len(candidates)):
                for j in range(i + 1, len(candidates)):
                    a, b = candidates[i], candidates[j]
                    w = self.compare(a, b)
                    if w == "a":
                        wins[a] += 1
                    elif w == "b":
                        wins[b] += 1
                    # None → fail-closed: par inconclusivo não pontua para ninguém
            ranking = sorted(candidates, key=lambda c: (-wins[c], c))
            if prev == ranking:
                converged = True
                break
            prev = ranking
        ranking = sorted(candidates, key=lambda c: (-wins[c], c))
        return {"ranking": ranking, "winner": ranking[0] if ranking else None,
                "converged": converged, "rounds": rounds, "wins": wins}


def _mock_compare(qualities: dict[str, int], seed: int):
    """Comparador determinístico (seedável) p/ mock: qualidade latente + ruído de sha256(seed:a:b).
    Empate exato de score → None (fail-closed)."""
    def compare(a: str, b: str):
        h = int(hashlib.sha256(f"{seed}:{a}:{b}".encode()).hexdigest(), 16)
        sa = qualities[a] * 10 + (h % 7)
        sb = qualities[b] * 10 + ((h // 7) % 7)
        if sa > sb:
            return "a"
        if sb > sa:
            return "b"
        return None
    return compare


def tournament_mock(n: int, seed: int) -> dict:
    """Tournament determinístico em modo mock: N candidatos sintéticos, qualidade derivada do seed."""
    candidates = [f"cand-{i}" for i in range(n)]
    qualities = {c: (seed * 31 + i * 17) %
                 100 for i, c in enumerate(candidates)}
    return Tournament(_mock_compare(qualities, seed)).run(candidates)


def _real_compare(a: str, b: str) -> str | None:
    """Lexicographic comparator for real-candidate mode (deterministic, fail-closed on tie)."""
    if a > b:
        return "a"
    if b > a:
        return "b"
    return None  # tie → fail-closed


def run_tournament(args) -> int:
    # --candidate-file branch: real candidates supplied by the caller (M1/TCK-0326).
    candidate_file = getattr(args, "candidate_file", None)
    if candidate_file is not None:
        try:
            raw = Path(candidate_file).read_text(encoding="utf-8")
        except OSError as exc:
            print(
                f"tournament: cannot read --candidate-file {candidate_file!r}: {exc}", file=sys.stderr)
            return 2
        candidates = [line.strip()
                      for line in raw.splitlines() if line.strip()]
        if len(candidates) < 2:
            print(
                "tournament: --candidate-file must contain at least 2 non-empty lines", file=sys.stderr)
            return 2
        result = Tournament(_real_compare).run(candidates)
        out = {"mode": "tournament", "candidates": len(candidates), "candidate_file": str(candidate_file),
               "ranking": result["ranking"], "winner": result["winner"],
               "converged": result["converged"], "rounds": result["rounds"], "wins": result["wins"]}
        if args.json:
            print(json.dumps(out, ensure_ascii=False, indent=2))
        else:
            print(
                f"Tournament ({len(candidates)} candidatos reais, arquivo={candidate_file}): winner={out['winner']}, converged={out['converged']}, rounds={out['rounds']}")
            for rank, c in enumerate(out["ranking"], 1):
                print(f"  {rank}. {c} (wins={result['wins'][c]})")
        return 0

    # Mock branch (byte-for-byte unchanged from original SPC-0023 contract).
    seed = args.seed if args.seed is not None else 0
    n = args.candidates
    if n < 2:
        print("tournament requer --candidates >= 2", file=sys.stderr)
        return 2
    if not args.mock:
        print("tournament: nesta versão só --mock é suportado (pairwise real reusando juízes = follow-up).", file=sys.stderr)
        return 2
    result = tournament_mock(n, seed)
    out = {"mode": "tournament", "candidates": n, "seed": seed,
           "ranking": result["ranking"], "winner": result["winner"],
           "converged": result["converged"], "rounds": result["rounds"], "wins": result["wins"]}
    if args.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(
            f"Tournament ({n} candidatos, seed {seed}): winner={out['winner']}, converged={out['converged']}, rounds={out['rounds']}")
        for rank, c in enumerate(out["ranking"], 1):
            print(f"  {rank}. {c} (wins={result['wins'][c]})")
    return 0
