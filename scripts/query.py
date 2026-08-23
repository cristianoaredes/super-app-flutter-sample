#!/usr/bin/env python3
"""Compatibility shim (TCK-1057 / DES-0195) — implementation: scripts/state/query.py

Keep `python3 scripts/query.py` working. Prefer domain path for new call sites.

Import-safe: when loaded as a module (`from X import …`), re-export the
implementation without executing CLI main (ship suite-green).
"""
from __future__ import annotations

from pathlib import Path
import importlib.util
import runpy
import sys

_TARGET = Path(__file__).resolve().parent / "state" / "query.py"
if not _TARGET.is_file():
    sys.stderr.write(f"shim error: missing {_TARGET}\n")
    sys.exit(127)


def _load_impl():
    name = 'codebase_ops_shim_query'
    spec = importlib.util.spec_from_file_location(name, _TARGET)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {_TARGET}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


if __name__ == "__main__":
    sys.argv[0] = str(_TARGET)
    runpy.run_path(str(_TARGET), run_name="__main__")
else:
    _mod = _load_impl()
    for _name in dir(_mod):
        if _name.startswith("_"):
            continue
        globals()[_name] = getattr(_mod, _name)
