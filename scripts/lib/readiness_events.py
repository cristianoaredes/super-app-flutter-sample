#!/usr/bin/env python3
"""Bounded opt-in JSONL readiness telemetry (TCK-1347 / TLP-0002).

The emitter is deliberately local and fail-open. It writes only to stderr when
``CODEBASE_OPS_READINESS_TELEMETRY=stderr`` and never creates a telemetry
store. Consumers keep stdout byte-compatible with their existing contracts.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any, Optional


SCHEMA_VERSION = "1"
MAX_EVENTS = 64
MAX_TOKEN_BYTES = 64
MAX_LIST_ITEMS = 16
MAX_EVENT_BYTES = 4 * 1024
TRUNCATION_MARKER = "diagnostic-truncated"

_EVENT_FIELDS = {
    "worktree_resolution": {
        "ticket",
        "branch",
        "action",
        "target_rel",
    },
    "dependency_readiness": {
        "ticket",
        "module",
        "eligible",
        "dependency_ids",
        "issue_codes",
        "consumer",
    },
    "transition_dependency_gate": {
        "ticket",
        "from",
        "to",
        "mutated",
    },
    "plan_readiness": {
        "plan",
        "module",
        "approved",
        "eligible",
        "next_action",
        "issue_codes",
        "consumer",
    },
    "downstream_probe": {
        "blocker",
        "blocker_status",
        "dependent",
        "dependent_readiness",
        "before",
        "after",
        "mutation",
    },
}
_WINDOWS_DRIVE_PATH_RE = re.compile(
    r"(?i)(?<![A-Za-z0-9])[A-Z]:[\\/][^,\s;]+"
)
_UNC_PATH_RE = re.compile(
    r"(?<![A-Za-z0-9_])\\\\[^\\/\s,;]+[\\/][^,\s;]+"
)
_ABSOLUTE_PATH_RE = re.compile(r"(?<![A-Za-z0-9._-])/(?:[^,\s;]+)")
_event_count = 0


def _bounded_text(value: object) -> str:
    text = "".join(
        " " if ord(character) < 32 or ord(character) == 127 else character
        for character in str(value)
    )
    text = " ".join(text.split())
    home = os.environ.get("HOME", "")
    username = os.environ.get("USER", "")
    if home:
        text = text.replace(home, "<redacted-path>")
    text = _WINDOWS_DRIVE_PATH_RE.sub("<redacted-path>", text)
    text = _UNC_PATH_RE.sub("<redacted-path>", text)
    text = _ABSOLUTE_PATH_RE.sub("<redacted-path>", text)
    if username and len(username) >= 2:
        text = text.replace(username, "<redacted-user>")

    encoded = text.encode("utf-8")
    if len(encoded) <= MAX_TOKEN_BYTES:
        return text
    marker = b"~truncated"
    prefix = encoded[: MAX_TOKEN_BYTES - len(marker)]
    while prefix:
        try:
            return prefix.decode("utf-8") + marker.decode("ascii")
        except UnicodeDecodeError:
            prefix = prefix[:-1]
    return marker.decode("ascii")


def _bounded_value(value: Any) -> object:
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, (int, float)):
        return value
    if isinstance(value, (list, tuple, set, frozenset)):
        items = (
            sorted(value, key=lambda item: str(item))
            if isinstance(value, (set, frozenset))
            else list(value)
        )
        projected = [_bounded_text(item) for item in items[:MAX_LIST_ITEMS]]
        if len(items) > MAX_LIST_ITEMS:
            projected = projected[: MAX_LIST_ITEMS - 1] + [TRUNCATION_MARKER]
        return projected
    return _bounded_text(value)


def emit_readiness_event(
    event: str,
    *,
    correlation_id: object = "",
    outcome: object = "",
    reason: object = "",
    **fields: Any,
) -> bool:
    """Emit one allowlisted event, returning whether a line was written."""
    global _event_count

    if os.environ.get("CODEBASE_OPS_READINESS_TELEMETRY") != "stderr":
        return False
    if event not in _EVENT_FIELDS or _event_count >= MAX_EVENTS:
        return False

    payload: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "event": event,
        "correlation_id": _bounded_text(correlation_id),
        "outcome": _bounded_text(outcome),
        "reason": _bounded_text(reason),
    }
    for key in sorted(_EVENT_FIELDS[event]):
        if key in fields:
            payload[key] = _bounded_value(fields[key])
    if _event_count == MAX_EVENTS - 1:
        # The 64th line announces that the process reached its telemetry
        # capacity; later calls are suppressed, so the hard cap remains 64.
        payload["telemetry_marker"] = TRUNCATION_MARKER

    serialized = json.dumps(
        payload,
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    )
    if len(serialized.encode("utf-8")) > MAX_EVENT_BYTES:
        payload = {
            "schema_version": SCHEMA_VERSION,
            "event": event,
            "correlation_id": _bounded_text(correlation_id),
            "outcome": _bounded_text(outcome),
            "reason": "payload-truncated",
        }
        serialized = json.dumps(
            payload,
            ensure_ascii=True,
            sort_keys=True,
            separators=(",", ":"),
        )
    try:
        print(serialized, file=sys.stderr, flush=True)
    except Exception:  # noqa: BLE001 - telemetry never changes producer outcome
        return False
    _event_count += 1
    return True


def _worktree_cli(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("ticket")
    parser.add_argument("branch")
    parser.add_argument("action")
    parser.add_argument("target_rel")
    parser.add_argument("outcome")
    parser.add_argument("reason")
    args = parser.parse_args(argv)
    emit_readiness_event(
        "worktree_resolution",
        correlation_id=args.ticket,
        outcome=args.outcome,
        reason=args.reason,
        ticket=args.ticket,
        branch=args.branch,
        action=args.action,
        target_rel=args.target_rel,
    )
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args.pop(0) != "worktree":
        return 2
    try:
        return _worktree_cli(args)
    except SystemExit:
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
