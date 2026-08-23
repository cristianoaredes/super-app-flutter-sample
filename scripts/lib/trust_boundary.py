#!/usr/bin/env python3
"""trust_boundary.py — shared P11 trust/provenance boundary (SPC-0038/F0.8, finding F7).

A ticket's ``acceptance[].check`` entries are shell commands. They may only be
EXECUTED when the ticket has trusted-local provenance. Before F0.8 this rule lived
ONLY inside criteria-check.py (the manual Verify gate) while the autonomous path
— pipeline-orchestrator.py -> pipeline-verify.py:run_check -> subprocess.run(shell=)
— executed them with no control at all (a live RCE surface on L2/L3).

This module is the SINGLE enforcement point both callers route through, so the P11
boundary cannot be bypassed by reaching one entrypoint instead of the other.

Policy
------
- untrusted provenance + would-execute (not dry-run) + no operator allowlist
      -> REFUSED: forced dry-run-only, NO subprocess.
- in-tree/committed tickets default to TRUSTED so legitimate autonomous runs are
  not broken; only genuinely untrusted provenance (imported/dropped/out-of-tree
  artifacts) is refused.

Implemented with a typing.NamedTuple (not @dataclass) and WITHOUT
``from __future__ import annotations`` so it stays safe to import under the
Py3.14 standalone-importlib path used by the tests.
"""

from pathlib import Path
from typing import NamedTuple
import logging
import re
import shlex

logger = logging.getLogger(__name__)

# Moved out of criteria-check.py by F0.8-T3: this is now the ONE definition.
# (test_criteria_check.py still asserts stderr contains "origem não confiável".)
UNTRUSTED_REFUSAL = (
    "origem não confiável: acceptance[] é comando shell. "
    "Use --untrusted --dry-run para inspecionar sem executar; execute só após trust review/allowlist."
)


class TrustDecision(NamedTuple):
    execute: bool   # True = shell execution permitted
    dry_run: bool   # effective dry-run (no subprocess)
    refused: bool   # True = execution refused because untrusted provenance tried to run
    reason: str     # human note (UNTRUSTED_REFUSAL when refused, else "")


def evaluate(*, untrusted: bool, dry_run: bool = False,
             allow_untrusted: bool = False) -> TrustDecision:
    """Decide whether acceptance[] shell may run.

    untrusted and NOT dry_run and NOT allow_untrusted -> refuse (force dry-run-only).
    Otherwise execution follows the requested dry_run flag.
    """
    if untrusted and not allow_untrusted and not dry_run:
        return TrustDecision(execute=False, dry_run=True, refused=True,
                             reason=UNTRUSTED_REFUSAL)
    return TrustDecision(execute=not dry_run, dry_run=bool(dry_run),
                         refused=False, reason="")


def _trusted_dirs(root) -> list:
    root = Path(root).resolve()
    return [
        root / ".archagents" / "15-backlog" / "tickets",
        root / ".archagents" / "archive" / "15-backlog" / "tickets",
    ]


def in_tree_ticket(path, root) -> bool:
    """True if the ticket file lives under the repo's canonical tickets dir.

    In-tree = trusted provenance (committed OR a freshly-created working-tree ticket
    the operator/orchestrator authored). Uses pure path containment — NO subprocess —
    so it never interferes with a subprocess-monkeypatched test and never depends on
    git being available.
    """
    p = Path(path).resolve()
    for d in _trusted_dirs(root):
        try:
            p.relative_to(d.resolve())
            return True
        except ValueError:
            continue
    return False


def is_untrusted_ticket(path, root) -> bool:
    """Provenance signal: untrusted when the ticket is NOT in-tree (imported / dropped
    / externally-supplied artifact). The CI gate + branch protection guard the
    in-tree/PR path; this guards everything outside it."""
    return not in_tree_ticket(path, root)


# ---------------------------------------------------------------------------
# FND-0047: Shell command validation — reject injection patterns
# ---------------------------------------------------------------------------


def _mask_quotes(cmd: str, *, blank_double: bool) -> str:
    """Blank out (with spaces, preserving length) characters that a POSIX
    shell would treat as inert quoted text, so injection regexes only see
    characters that would actually be active/unquoted.

    Single-quoted text is always fully literal (blanked): no metacharacter
    is active inside ``'...'``. Double-quoted text is only blanked when
    ``blank_double=True`` — a real shell still expands backticks/``$(...)``/
    ``$VAR`` inside double quotes, so callers checking for those must pass
    ``blank_double=False`` to keep double-quoted regions visible/dangerous.
    """
    out = []
    quote = None  # None | "'" | '"'
    escaped = False
    for ch in cmd:
        if quote == "'":
            out.append(" ")
            if ch == "'":
                quote = None
            continue
        if quote == '"':
            if escaped:
                out.append(" ")
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                out.append(" ")
                continue
            if ch == '"':
                quote = None
                out.append(" ")
                continue
            out.append(" " if blank_double else ch)
            continue
        # unquoted
        if escaped:
            # a backslash-escaped quote outside any quoting is a LITERAL
            # character, not the start of a quoted region (TCK-0882 review
            # fix: without this, `echo \"; rm -rf /` was mis-parsed as
            # entering double-quote mode, silently masking the real ';').
            out.append(ch)
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            out.append(ch)
            continue
        if ch == "'":
            quote = "'"
            out.append(" ")
            continue
        if ch == '"':
            quote = '"'
            out.append(" ")
            continue
        out.append(ch)
    return "".join(out)


# Separator-class patterns: inert (literal, non-separator) inside BOTH
# single and double quotes in a real shell — checked against the
# blank_double=True mask.
_SEPARATOR_PATTERNS = [
    (re.compile(r";"), "semicolon (command chaining)"),
    (re.compile(r"\|\s*\b(curl|wget|nc|ncat|netcat|bash|sh|zsh|dash|ksh)\b"),
     "pipe to dangerous command"),
]

# Expansion-class patterns: still ACTIVE inside double quotes in a real
# shell (only single quotes make them inert) — checked against the
# blank_double=False mask.
_EXPANSION_PATTERNS = [
    (re.compile(r"`"), "backtick (command substitution)"),
    (re.compile(r"\$\("), "$( command substitution"),
]

# Back-compat name some callers/tests may reference; kept as the union for
# any code that still iterates the full list.
_SHELL_INJECTION_PATTERNS = _SEPARATOR_PATTERNS + _EXPANSION_PATTERNS

# Shell features that require wrapping in ["bash", "-c", ...] when present.
# These are legitimate in acceptance criteria but need explicit shell invocation.
_SHELL_FEATURES = re.compile(r"\|\||&&|\||>|<|>>|<<|\*|\?|\$")


class CommandValidationResult(NamedTuple):
    safe: bool           # True = command passed validation
    reason: str          # explanation when safe=False
    needs_shell: bool    # True = command contains shell features
    argv: list           # parsed argv when safe and not needs_shell


def validate_shell_command(cmd: str, *, allow_dangerous: bool = False) -> CommandValidationResult:
    """Validate a shell command for injection patterns.

    Returns a CommandValidationResult indicating whether the command is safe to
    execute and whether it requires shell features.

    Args:
        cmd: The command string to validate.
        allow_dangerous: If True, skip injection pattern checks (for explicit
                        operator allowlists). Default False.

    Policy:
        - Commands containing ; or backticks are REJECTED unless allow_dangerous.
        - Commands with pipes/redirects are flagged as needing shell mode.
        - Simple commands are parsed with shlex.split() for safe shell=False execution.
    """
    cmd = cmd.strip()
    if not cmd:
        return CommandValidationResult(safe=False, reason="empty command",
                                       needs_shell=False, argv=[])

    # Check for injection patterns — only characters a real shell would
    # treat as ACTIVE (unquoted, or expansion inside double quotes) can
    # trigger rejection; quoted-and-inert text is not scanned (TCK-0882).
    if not allow_dangerous:
        masked_separators = _mask_quotes(cmd, blank_double=True)
        for pattern, desc in _SEPARATOR_PATTERNS:
            if pattern.search(masked_separators):
                logger.warning("FND-0047: rejected command with %s: %.80s", desc, cmd)
                return CommandValidationResult(
                    safe=False,
                    reason=f"command contains {desc} — rejected by FND-0047 shell safety",
                    needs_shell=False,
                    argv=[]
                )
        masked_expansions = _mask_quotes(cmd, blank_double=False)
        for pattern, desc in _EXPANSION_PATTERNS:
            if pattern.search(masked_expansions):
                logger.warning("FND-0047: rejected command with %s: %.80s", desc, cmd)
                return CommandValidationResult(
                    safe=False,
                    reason=f"command contains {desc} — rejected by FND-0047 shell safety",
                    needs_shell=False,
                    argv=[]
                )

    # Detect shell features that need shell=True
    needs_shell = bool(_SHELL_FEATURES.search(cmd))

    # Parse argv for simple commands
    argv: list[str] = []
    if not needs_shell:
        try:
            argv = shlex.split(cmd)
        except ValueError as e:
            return CommandValidationResult(
                safe=False,
                reason=f"shlex parse error: {e}",
                needs_shell=False,
                argv=[]
            )

    return CommandValidationResult(safe=True, reason="", needs_shell=needs_shell, argv=argv)
