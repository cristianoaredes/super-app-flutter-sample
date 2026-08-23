#!/usr/bin/env python3
"""recursion_guard.py — Detect tool recursion and delegation loops (Phase 7.4 / T6).

Prevents:
- Agent invoking itself (direct recursion)
- Agent A invokes B invokes A (indirect recursion)
- Delegation chain exceeding depth limit

Integration: Called by pipeline-orchestrator before each delegation.

Contract
--------
- Fail-open: guard never raises — internal errors return allowed=True with a warning.
- Advisory + enforcement: logs warning on every check; blocks when threshold exceeded.
- Pure stdlib; harness-agnostic (no external provider SDK required).

Threat model reference: .archagents/07-security-compliance.md T6.
SAFETY.md circuit breaker: Tool recursion row.

P9 ratchet: this is a safety mechanism — it may be strengthened but NEVER removed
or weakened without an ADR approved by a human operator.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Defaults — aligned with pipeline-orchestrator max_iterations (3) and
# loop_controller.ABSOLUTE_SAFE_MAX_ATTEMPTS (5).
# ---------------------------------------------------------------------------

# Maximum agents in a delegation chain before refusal.
DEFAULT_MAX_DELEGATION_DEPTH = 5

# Maximum times the same agent may appear in a chain (not necessarily consecutive).
DEFAULT_MAX_SAME_AGENT = 2


# ---------------------------------------------------------------------------
# Result dataclass — mirrors TrustDecision shape (lib/trust_boundary.py)
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class RecursionDecision:
    """Outcome of a delegation check.

    allowed:  True if the delegation may proceed.
    reason:   Human-readable explanation (always populated).
    depth:    Current chain length at the time of the check.
    agent:    The agent being added to the chain.
    """
    allowed: bool
    reason: str
    depth: int
    agent: str


# ---------------------------------------------------------------------------
# Guard implementation
# ---------------------------------------------------------------------------

class RecursionGuard:
    """Stateless guard — checks a proposed delegation against a chain.

    The guard itself holds no mutable state between calls. The delegation
    chain is passed in explicitly by the caller (the orchestrator), so this
    class is safe to share across threads and processes.

    Configuration is injected via constructor; defaults match framework-wide
    limits documented in SAFETY.md and loop_controller.py.
    """

    MAX_DELEGATION_DEPTH: int = DEFAULT_MAX_DELEGATION_DEPTH
    MAX_SAME_AGENT_TOTAL: int = DEFAULT_MAX_SAME_AGENT

    def __init__(
        self,
        max_depth: Optional[int] = None,
        max_same_agent: Optional[int] = None,
    ) -> None:
        # Allow overrides but clamp to sane minimums (never allow 0 — would
        # break all delegation).  Fail-open on bad input: use defaults.
        try:
            self.max_depth = max(1, int(max_depth)) if max_depth is not None else self.MAX_DELEGATION_DEPTH
        except (TypeError, ValueError):
            self.max_depth = self.MAX_DELEGATION_DEPTH

        try:
            self.max_same = max(1, int(max_same_agent)) if max_same_agent is not None else self.MAX_SAME_AGENT_TOTAL
        except (TypeError, ValueError):
            self.max_same = self.MAX_SAME_AGENT_TOTAL

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def check_delegation(
        self,
        agent_name: str,
        chain: list[str],
    ) -> RecursionDecision:
        """Check if adding *agent_name* to *chain* would cause recursion.

        Parameters
        ----------
        agent_name:
            Name of the agent the orchestrator intends to delegate to next.
        chain:
            Ordered list of agent names already in the current delegation path.
            An empty list means this is the first delegation.

        Returns
        -------
        RecursionDecision with ``allowed=True`` and reason ``"ok"`` when the
        delegation is safe, or ``allowed=False`` with a human-readable reason
        when a limit is exceeded.

        Fail-open contract: if *agent_name* is empty/None or *chain* is not a
        list, returns ``allowed=True`` (a guard bug must never block legitimate
        orchestration).  A warning is always logged so the anomaly surfaces in
        logs.
        """
        # --- Input validation (fail-open) ---
        if not agent_name:
            logger.warning(
                "[recursion_guard] empty agent_name — fail-open (allowed)"
            )
            return RecursionDecision(
                allowed=True,
                reason="empty agent_name — fail-open",
                depth=len(chain) if isinstance(chain, list) else 0,
                agent=agent_name or "",
            )

        if not isinstance(chain, list):
            logger.warning(
                "[recursion_guard] chain is not a list (%s) — fail-open",
                type(chain).__name__,
            )
            return RecursionDecision(
                allowed=True,
                reason=f"chain type {type(chain).__name__} — fail-open",
                depth=0,
                agent=agent_name,
            )

        current_depth = len(chain)

        # --- Depth limit ---
        if current_depth >= self.max_depth:
            reason = (
                f"delegation depth {current_depth} meets or exceeds limit "
                f"{self.max_depth} — chain: {chain}"
            )
            logger.warning("[recursion_guard] BLOCKED: %s", reason)
            return RecursionDecision(
                allowed=False,
                reason=reason,
                depth=current_depth,
                agent=agent_name,
            )

        # --- Same-agent recurrence ---
        appearances = chain.count(agent_name)
        if appearances >= self.max_same:
            reason = (
                f"agent '{agent_name}' appears {appearances} time(s) in chain "
                f"(max {self.max_same}) — chain: {chain}"
            )
            logger.warning("[recursion_guard] BLOCKED: %s", reason)
            return RecursionDecision(
                allowed=False,
                reason=reason,
                depth=current_depth,
                agent=agent_name,
            )

        # --- Allowed ---
        logger.info(
            "[recursion_guard] allowed: agent='%s' depth=%d/%d",
            agent_name,
            current_depth,
            self.max_depth,
        )
        return RecursionDecision(
            allowed=True,
            reason="ok",
            depth=current_depth,
            agent=agent_name,
        )

    # ------------------------------------------------------------------
    # Convenience helpers
    # ------------------------------------------------------------------

    def is_safe(self, agent_name: str, chain: list[str]) -> bool:
        """Boolean shortcut — True if the delegation is permitted."""
        return self.check_delegation(agent_name, chain).allowed

    def summary(self) -> dict:
        """Return the guard's current configuration as a JSON-serializable dict.

        Useful for run metadata and audit logs.
        """
        return {
            "max_delegation_depth": self.max_depth,
            "max_same_agent": self.max_same,
            "module": "lib/recursion_guard.py",
            "threat_model_ref": "T6",
        }
