#!/usr/bin/env python3
"""acceptance-lock.json runner-only (SPC-0057/C2.2, DES-0213 §3).

Anti-phantom-done do caminho paralelo (incidente SPC-0028): só os runners de
evidência — criteria-check.py e pipeline-verify.py, na sessão principal —
flipam `passes`. As tools de edição e a escrita shell são bloqueadas pelo
hook adapter; este módulo é o ÚNICO caminho de escrita legítimo.

Threat model honesto (DES-0213): mecanismo de FERRAMENTA, não criptografia —
elimina o caminho acidental/convencional do phantom-done, não resiste a um
ator com python arbitrário.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from lib.artifactguard import ensure_test_isolation
from lib.paths import paths

# Únicos escritores legítimos (DES-0213 §3.2). Qualquer outro valor é bug.
ALLOWED_WRITERS = frozenset({"criteria-check", "pipeline-verify"})


def lock_path(root: str | Path | None = None) -> Path:
    return paths(root).archagents / "13-execution" / "acceptance-lock.json"


def read_lock(root: str | Path | None = None) -> dict:
    path = lock_path(root)
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def set_passes(root: str | Path | None, ticket_id: str, passes: bool,
               updated_by: str) -> dict:
    """Grava `passes` para o ticket. Escrita atômica (tmp + os.replace)."""
    if updated_by not in ALLOWED_WRITERS:
        raise ValueError(
            f"updated_by inválido: {updated_by!r} — runner-only "
            f"(permitidos: {sorted(ALLOWED_WRITERS)}); ver DES-0213 §3")
    path = lock_path(root)
    ensure_test_isolation(path, artifact="acceptance-lock")  # TCK-0498
    path.parent.mkdir(parents=True, exist_ok=True)
    data = read_lock(root)
    data[ticket_id] = {
        "passes": bool(passes),
        "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updated_by": updated_by,
    }
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return data[ticket_id]


def count_active_worktrees(root: str | Path | None = None) -> int:
    """Worktrees ativos do repo em `root`; sem git (fixtures) conta 1."""
    base = paths(root).root
    try:
        out = subprocess.run(
            ["git", "worktree", "list", "--porcelain"],
            capture_output=True, text=True, cwd=str(base), timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return 1
    if out.returncode != 0:
        return 1
    n = sum(1 for line in out.stdout.splitlines() if line.startswith("worktree "))
    return n or 1
