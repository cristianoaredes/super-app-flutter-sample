#!/usr/bin/env python3
"""memstore.py — atomic + locked JSON writes for the .archagents/99-memory store.

SPC-0032/F0.2 (F17): the lesson/verdict writers used bare write_text() — a
lost-update race under --parallel and truncation on mid-write crash. This module
gives them the crash-safe primitive already used by lib/ticket.save_ticket_atomic
(tempfile + fsync + os.replace) plus a memory-dir-scoped flock so concurrent
writers serialize. fcntl is POSIX-only; the lock degrades to best-effort on a
non-POSIX harness while os.replace keeps the write atomic regardless.
"""
from __future__ import annotations

import json
import os
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import importlib.util as _ilu
fcntl = __import__("fcntl") if _ilu.find_spec("fcntl") else None  # POSIX-only; None elsewhere (F0.7-T2)


def atomic_write_json(path: "str | Path", obj: Any) -> None:
    """Serialize obj to path atomically (tempfile + fsync + os.replace).

    A crash mid-write leaves the original file intact (the rename is atomic),
    never a truncated JSON."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", delete=False,
            dir=path.parent, prefix=f".{path.name}.", suffix=".tmp",
        ) as fh:
            tmp_path = Path(fh.name)
            json.dump(obj, fh, indent=2, ensure_ascii=False)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp_path, path)
        tmp_path = None
    finally:
        if tmp_path is not None:
            tmp_path.unlink(missing_ok=True)


@contextmanager
def memory_lock(memory_dir: "str | Path") -> Iterator[None]:
    """Serialize 99-memory writes via a memory-dir-scoped flock.

    Scoped to memory_dir (not paths().locks) so it stays hermetic under
    CODEBASE_OPS_MEMORY_DIR — the same fcntl.flock pattern as lib.ids.id_lock."""
    md = Path(memory_dir)
    md.mkdir(parents=True, exist_ok=True)
    lock_path = md / ".memory.lock"
    with lock_path.open("a+", encoding="utf-8") as fh:
        if fcntl is not None:
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            if fcntl is not None:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
