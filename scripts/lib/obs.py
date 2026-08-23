#!/usr/bin/env python3
"""obs.py — observable warnings for advisory loop telemetry (SPC-0028).

Loop-telemetry metrics (lesson utility, strategy effectiveness, loop health) are
advisory and must never gate or crash the judge/reflect/dashboard. But swallowing
their failures silently lets a regression hide while grep-based acceptance still
passes — the green-but-broken gap behind the SPC-0028 phantom-done incident.
warn_telemetry surfaces the failure on stderr without raising.
"""
from __future__ import annotations

import sys


def warn_telemetry(label: str, exc: BaseException) -> None:
    """Emit a non-fatal warning to stderr that an advisory loop-telemetry step failed."""
    print(
        f"[loop-telemetry WARN] {label}: {type(exc).__name__}: {exc}",
        file=sys.stderr,
    )
