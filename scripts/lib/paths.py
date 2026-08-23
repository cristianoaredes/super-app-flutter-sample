#!/usr/bin/env python3
"""Canonical filesystem paths for codebase-ops scripts."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


from lib.bootstrap import get_repo_root

REPO_ROOT = get_repo_root()


@dataclass(frozen=True)
class OpsPaths:
    root: Path
    archagents: Path
    tickets: Path
    backlog_csv: Path
    designs: Path
    playbooks: Path
    decisions: Path
    runs: Path
    verify_reports: Path
    locks: Path
    archive: Path
    telemetry_plans: Path
    telemetry: Path
    post_release_reports: Path
    learning_records: Path
    id_state: Path  # shared across worktrees for cross-WT ID safety (locks + runtime high-water)


def repo_root(root: str | Path | None = None) -> Path:
    """Return the repository root for ops scripts."""
    return Path(root).resolve() if root is not None else REPO_ROOT


def _git_common_dir_without_git(base: Path) -> Path:
    """Resolve the common dir by reading the filesystem, with no git subprocess.

    TCK-1368: in a LINKED worktree `<root>/.git` is a FILE holding
    ``gitdir: <main>/.git/worktrees/<name>``, so the old fallback returned a path
    whose every `mkdir` raises NotADirectoryError — the shared ID state simply
    could not be created. Follow the pointer and climb out of ``worktrees/<name>``
    to reach the common dir. Best-effort by contract: anything unparseable degrades
    to the historical ``<root>/.git``.
    """
    dotgit = base / ".git"
    if not dotgit.is_file():
        return dotgit
    try:
        text = dotgit.read_text(encoding="utf-8").strip()
    except OSError:
        return dotgit
    if not text.startswith("gitdir:"):
        return dotgit
    pointed = Path(text.split(":", 1)[1].strip())
    if not pointed.is_absolute():
        pointed = (base / pointed).resolve()
    # <common>/worktrees/<name> -> <common>; any other shape is used as-is.
    if pointed.parent.name == "worktrees":
        return pointed.parent.parent
    return pointed


def git_common_dir(root: str | Path | None = None) -> Path:
    """Return the git common dir (shared by all worktrees of the repo).

    Falls back to a git-free filesystem resolution when git is unavailable or the
    subprocess is unusable. This is the key for cross-worktree shared state (locks,
    ID high-water), so the fallback has to stay correct inside a linked worktree —
    see ``_git_common_dir_without_git``.
    """
    base = repo_root(root)
    try:
        res = subprocess.run(
            ["git", "-C", str(base), "rev-parse", "--git-common-dir"],
            capture_output=True, text=True, check=True, timeout=5,
        )
        p = Path(res.stdout.strip())
        if not p.is_absolute():
            p = base / p
        return p
    except Exception:
        return _git_common_dir_without_git(base)


def id_state_dir(root: str | Path | None = None) -> Path:
    """Shared ID state directory across worktrees (for locks + runtime high-water)."""
    return git_common_dir(root) / "codebase-ops" / "ids"


def paths(root: str | Path | None = None) -> OpsPaths:
    """Return canonical codebase-ops paths rooted at ``root``."""
    base = repo_root(root)
    archagents = base / ".archagents"
    backlog = archagents / "15-backlog"
    designs = archagents / "16-designs"
    id_state = id_state_dir(base)
    return OpsPaths(
        root=base,
        archagents=archagents,
        tickets=backlog / "tickets",
        backlog_csv=backlog / "backlog.csv",
        designs=designs,
        playbooks=designs / "playbooks",
        decisions=archagents / "09-decisions",
        runs=archagents / "13-execution" / "runs",
        verify_reports=archagents / "14-verify" / "reports",
        locks=archagents / ".locks",
        archive=archagents / "archive",
        telemetry_plans=archagents / "17-observability" / "telemetry-plans",
        telemetry=archagents / ".telemetry",
        post_release_reports=archagents / "17-observability" / "post-release",
        learning_records=archagents / "99-memory" / "learnings",
        id_state=id_state,
    )


def archived_tickets(root: str | Path | None = None) -> Path:
    return paths(root).archive / "15-backlog" / "tickets"


def archived_designs(root: str | Path | None = None) -> Path:
    return paths(root).archive / "16-designs"


def archived_decisions(root: str | Path | None = None) -> Path:
    return paths(root).archive / "09-decisions"
