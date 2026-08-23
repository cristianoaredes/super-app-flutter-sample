"""scripts/lib/notifications.py — critical event notification hook (TCK-0377).

Sends structured event notifications for critical pipeline events:
- budget-exhausted: run budget cap exceeded
- verify-failed: verify failed after max retries
- stop-condition: SAFETY stop condition triggered

Config: .archagents/.notifications.json
  {
    "enabled": true,
    "webhook_url": "https://hooks.slack.com/services/...",
    "events": ["budget-exhausted", "verify-failed", "stop-condition"]
  }

Fail-open: notification errors are logged but never raise.
Stdout fallback when no webhook configured or webhook fails.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

VALID_KINDS = frozenset({
    "budget-exhausted",
    "verify-failed",
    "stop-condition",
})


def _load_config(root: str | Path | None = None) -> dict:
    """Load notification config. Returns empty dict on any error (fail-open)."""
    if root is None:
        root = Path(__file__).resolve().parent.parent.parent
    config_path = Path(root) / ".archagents" / ".notifications.json"
    try:
        text = config_path.read_text(encoding="utf-8")
        data = json.loads(text)
        if not isinstance(data, dict):
            return {}
        return data
    except Exception:
        return {}


def send_event(
    kind: str,
    payload: dict[str, Any],
    *,
    root: str | Path | None = None,
) -> bool:
    """Send a notification event.

    Args:
        kind: Event type (must be in VALID_KINDS).
        payload: Event data (ticket, run_dir, message, etc.).
        root: Repo root for config lookup.

    Returns:
        True if notification was sent (webhook or stdout), False on error.
        Never raises.
    """
    try:
        if kind not in VALID_KINDS:
            logger.warning("Unknown notification kind: %s", kind)
            return False

        config = _load_config(root)
        if not config.get("enabled", False):
            return _stdout_fallback(kind, payload)

        allowed_events = config.get("events", list(VALID_KINDS))
        if kind not in allowed_events:
            return False

        webhook_url = config.get("webhook_url")
        if not webhook_url:
            return _stdout_fallback(kind, payload)

        return _send_webhook(webhook_url, kind, payload)
    except Exception as exc:
        logger.warning("Notification send_event failed: %s", exc)
        return False


def _stdout_fallback(kind: str, payload: dict[str, Any]) -> bool:
    """Print event to stderr when no webhook is configured."""
    try:
        msg = f"[notify:{kind}] {json.dumps(payload, ensure_ascii=False, default=str)}"
        print(msg, file=sys.stderr)
        return True
    except Exception:
        return False


def _send_webhook(url: str, kind: str, payload: dict[str, Any]) -> bool:
    """POST event to webhook URL. Returns True on 2xx, False otherwise."""
    body = json.dumps({
        "kind": kind,
        "payload": payload,
    }, ensure_ascii=False, default=str).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            if 200 <= resp.status < 300:
                return True
            logger.warning("Webhook returned %d for %s", resp.status, kind)
            return _stdout_fallback(kind, payload)
    except (urllib.error.URLError, OSError, TimeoutError) as exc:
        logger.warning("Webhook failed for %s: %s — falling back to stdout", kind, exc)
        return _stdout_fallback(kind, payload)
