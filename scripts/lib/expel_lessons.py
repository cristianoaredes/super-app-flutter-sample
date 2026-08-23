"""ExpeL-style lesson extraction by success×failure contrast (TCK-0836).

Stage 1 (deterministic): group verdicts by ticket category/module signals and
contrast outcomes. Stage 2 (optional LLM) is left to the harness — this module
emits evidence-backed lesson *proposals* without calling an API.
"""
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any


def _load_verdicts(memory_dir: Path) -> list[dict[str, Any]]:
    vdir = memory_dir / "verdicts"
    if not vdir.is_dir():
        return []
    out: list[dict[str, Any]] = []
    for p in sorted(vdir.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        if isinstance(data, dict):
            data["_path"] = p.name
            out.append(data)
    return out


def _outcome(v: dict[str, Any]) -> str:
    overall = str(v.get("overall") or v.get("verdict") or "").upper()
    score = v.get("score")
    if overall in ("PASS", "ACCEPTABLE", "SUCCESS", "APPROVED"):
        return "success"
    if overall in ("FAIL", "REJECTED", "FAILURE"):
        return "failure"
    try:
        if score is not None and float(score) >= 70:
            return "success"
        if score is not None and float(score) < 50:
            return "failure"
    except (TypeError, ValueError):
        pass
    return "unknown"


def _bucket_key(v: dict[str, Any]) -> str:
    ticket = str(v.get("ticket") or "")
    # coarse: first digit group of ticket / category field
    cat = str(v.get("category") or v.get("kind") or "")
    if cat:
        return cat.lower()
    if ticket.startswith("TCK-"):
        return ticket[:7]  # TCK-08x cohort-ish
    return "general"


def extract_contrast_lessons(
    memory_dir: Path | str,
    *,
    ticket_id: str | None = None,
    min_pairs: int = 1,
) -> list[dict[str, Any]]:
    """Return lesson dicts with evidence (verdict ids), severity, affected_tickets."""
    md = Path(memory_dir)
    verdicts = _load_verdicts(md)
    by_bucket: dict[str, dict[str, list]] = defaultdict(lambda: {"success": [], "failure": []})
    for v in verdicts:
        oc = _outcome(v)
        if oc not in ("success", "failure"):
            continue
        by_bucket[_bucket_key(v)][oc].append(v)

    lessons: list[dict[str, Any]] = []
    for bucket, groups in by_bucket.items():
        succ = groups["success"]
        fail = groups["failure"]
        if len(succ) < min_pairs or len(fail) < min_pairs:
            continue
        # Pick most recent of each
        s = succ[-1]
        f = fail[-1]
        s_id = str(s.get("id") or s.get("_path") or "success")
        f_id = str(f.get("id") or f.get("_path") or "failure")
        fail_causes = s.get("root_causes") if False else f.get("root_causes") or f.get("what_went_wrong") or []
        if isinstance(fail_causes, str):
            fail_causes = [fail_causes]
        cause_txt = "; ".join(str(c) for c in fail_causes[:3]) if fail_causes else "unspecified failure mode"
        tickets = []
        for v in (s, f):
            t = str(v.get("ticket") or "")
            if t and t not in tickets:
                tickets.append(t)
        if ticket_id and ticket_id not in tickets:
            tickets.append(ticket_id)
        lessons.append({
            "lesson": (
                f"[{bucket}] Prefer patterns from successful runs over "
                f"failure mode '{cause_txt[:120]}' (contrast {s_id} vs {f_id})"
            ),
            "severity": "medium",
            "affected_tickets": tickets or ([ticket_id] if ticket_id else []),
            "evidence": [s_id, f_id],
            "extraction": "expel-contrast",
            "confidence": "medium",
        })
    return lessons


def extract_lessons_hybrid(
    verify_report: dict,
    root_causes: list,
    ticket_id: str,
    *,
    memory_dir: Path | str | None = None,
) -> list[dict[str, Any]]:
    """Drop-in replacement for pipeline-judge.extract_lessons.

    Prefers ExpeL contrast lessons when verdict history exists; falls back to
    evidence-tagged heuristic lessons (not bare regex templates without evidence).
    """
    lessons: list[dict[str, Any]] = []
    if memory_dir is not None:
        lessons.extend(extract_contrast_lessons(memory_dir, ticket_id=ticket_id)[:3])

    if not verify_report:
        return lessons

    failed = [c for c in verify_report.get("checks", []) if c.get("status") == "FAIL"]
    errors = [c for c in verify_report.get("checks", []) if c.get("status") == "ERROR"]
    if failed:
        checks = ", ".join(str(c.get("check", ""))[:60] for c in failed[:2])
        lessons.append({
            "lesson": f"Acceptance failed for: {checks}. Harden pre-flight or criteria.",
            "severity": "medium",
            "affected_tickets": [ticket_id],
            "evidence": [f"verify-fail:{len(failed)}"],
            "extraction": "verify-evidence",
            "confidence": "low",
        })
    if errors:
        lessons.append({
            "lesson": "Acceptance checks errored (timeout/path). Make checks robust and absolute-path safe.",
            "severity": "high",
            "affected_tickets": [ticket_id],
            "evidence": [f"verify-error:{len(errors)}"],
            "extraction": "verify-evidence",
            "confidence": "low",
        })
    if root_causes:
        lessons.append({
            "lesson": f"Root cause signal: {str(root_causes[0])[:160]}",
            "severity": "medium",
            "affected_tickets": [ticket_id],
            "evidence": ["root_causes"],
            "extraction": "root-cause",
            "confidence": "low",
        })
    return lessons
