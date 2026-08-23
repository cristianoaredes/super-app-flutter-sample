#!/usr/bin/env python3
"""report_utils.py — Utilities for report generation and metric aggregation.

Used by: token-report.py, reflect.py, and any script generating summaries.
"""

from __future__ import annotations

import re
import warnings
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


CMD_RE = re.compile(r"<command-name>(/[\w/-]+)</command-name>")
INITIAL_PHASE = "(inicio)"


def parse_iso_ts(ts_str: str | None) -> datetime | None:
    """Parse ISO-8601 timestamp safely. Returns None on failure."""
    if not ts_str:
        return None
    try:
        s = ts_str.replace("Z", "+00:00")
        return datetime.fromisoformat(s)
    except (ValueError, TypeError):
        return None


def extract_phase_from_content(content: Any) -> str | None:
    """Detect <command-name> marker in a content block (string or list)."""
    if isinstance(content, str):
        m = CMD_RE.search(content)
        if m:
            return m.group(1)
    elif isinstance(content, list):
        for item in content:
            if isinstance(item, dict):
                text = item.get("text", "")
                if text:
                    m = CMD_RE.search(text)
                    if m:
                        return m.group(1)
    return None


def warn(msg: str) -> None:
    """Emit a warning to stderr."""
    warnings.warn(msg, stacklevel=2)
    print(f"  [WARN] {msg}", file=__import__("sys").stderr)


def parse_frontmatter_safe(path: Path) -> dict[str, Any]:
    """Read frontmatter from a markdown file. Returns {} and warns on failure."""
    try:
        text = path.read_text(encoding="utf-8")
        # Inline frontmatter parser
        m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
        if not m:
            return {}
        result: dict[str, Any] = {}
        for line in m.group(1).splitlines():
            line = line.strip()
            if not line or line.startswith("#") or ":" not in line:
                continue
            key, _, val = line.partition(":")
            val = val.strip().strip('"\'')
            result[key.strip()] = val
        return result
    except Exception as exc:
        warn(f"artefato malformado ignorado: {path.name} ({exc})")
        return {}


def now_iso() -> str:
    """Return current UTC time in ISO-8601 format."""
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def now_utc() -> datetime:
    """Return the current time as a timezone-aware UTC datetime (TCK-0559).

    Single source of "now" for report/verdict timestamps. pipeline_reports.py,
    pipeline-orchestrator.py, cognee-adapter.py and pipeline-judge.py each used
    a bare, argument-less `datetime.now` call (naive, LOCAL time) to name/stamp
    the same RUN-/VER- artifact that init-run.sh stamps in UTC — a 3rd
    recurrence of the naive/local datetime class. Call this (or
    now_utc_compact() for filenames) instead of the naive/bare form.
    """
    return datetime.now(tz=timezone.utc)


def now_utc_compact() -> str:
    """now_utc() formatted as YYYYMMDD-HHMMSS, for RUN-/VER- ids and other
    filename-safe compact timestamps (TCK-0559)."""
    return now_utc().strftime("%Y%m%d-%H%M%S")


def coalesce_str(val: Any) -> str:
    """Convert value to string, returning empty string for None."""
    if val is None:
        return ""
    return str(val).strip()
