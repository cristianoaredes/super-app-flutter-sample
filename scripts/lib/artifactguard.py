#!/usr/bin/env python3
"""artifactguard.py — guarda de isolamento de teste para writers de .archagents (TCK-0498).

Classe de incidente recorrente: a suíte contamina o repo REAL com artefatos de
fixture — snapshots de 369GB (TCK-0499), VER-*.md por run de suíte e o
acceptance-lock.json rastreado poluído com TCK-9901/9999. Padrão comum: o
teste mocka o diretório em-processo, mas um SUBPROCESS re-importa o módulo e
resolve o root real.

Contrato (aplicar em TODO writer novo de artefato em .archagents):

    from lib.artifactguard import ensure_test_isolation
    ensure_test_isolation(target_path, artifact="VER report")

- Fora de pytest (sem PYTEST_CURRENT_TEST no env): inerte.
- Sob pytest, escrita alvo dentro do .archagents REAL deste repo: IsolationError
  — o teste deve injetar um root temporário (param --root / CBOPS_ARCHAGENTS_ROOT).
- Escape deliberado (e2e que PRECISA da árvore real): CBOPS_ALLOW_REAL_ARTIFACT_WRITES=1.

PYTEST_CURRENT_TEST é herdado por subprocessos — a guarda pega exatamente o
caso que o mock em-processo não pega.
"""

from __future__ import annotations

import os
from pathlib import Path

from lib.bootstrap import get_repo_root

ENV_ALLOW = "CBOPS_ALLOW_REAL_ARTIFACT_WRITES"
ENV_ROOT = "CBOPS_ARCHAGENTS_ROOT"


class IsolationError(RuntimeError):
    """Escrita de artefato no .archagents real a partir de contexto de teste."""


def resolve_archagents_root() -> Path:
    """Root do .archagents honrando injeção por env (ponto de override p/ subprocess).

    Default: <repo>/.archagents. Com CBOPS_ARCHAGENTS_ROOT setado, o valor é
    usado literalmente — é assim que um teste redireciona writers re-importados
    em subprocesso para um diretório temporário.
    """
    env = os.environ.get(ENV_ROOT, "").strip()
    if env:
        return Path(env).resolve()
    return get_repo_root() / ".archagents"


def ensure_test_isolation(target: str | Path, *, artifact: str = "artefato") -> None:
    """Levanta IsolationError se `target` cai no .archagents REAL sob pytest."""
    if not os.environ.get("PYTEST_CURRENT_TEST"):
        return
    if os.environ.get(ENV_ALLOW) == "1":
        return
    real = (get_repo_root() / ".archagents").resolve()
    t = Path(target).resolve()
    if t == real or real in t.parents:
        raise IsolationError(
            f"test-isolation guard (TCK-0498): escrita de {artifact} em "
            f"{t} — o .archagents REAL — durante pytest. Injete um root "
            f"temporário (--root / {ENV_ROOT}) ou exporte {ENV_ALLOW}=1 "
            f"se o e2e precisa deliberadamente da árvore real.")
