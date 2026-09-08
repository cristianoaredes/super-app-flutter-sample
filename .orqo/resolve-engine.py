#!/usr/bin/env python3
"""engine_resolver.py — resolve ONDE está o motor (engine.pyz).

TCK-2819 fase 2: os futuros stubs finos (~20 linhas) não carregam o motor;
resolvem-no. A ordem é a mesma do `resolve-scripts.sh` para scripts — quem
bootstrapou manda; override explícito vence default implícito; falha visível
com instrução, nunca silêncio:

  1. pyz LOCAL do projeto: `.orqo/engine.pyz`, procurado do diretório inicial
     PARA CIMA (semântica git — stub roda de qualquer subdiretório/worktree);
  2. instalação GLOBAL por override explícito: `$CODEBASE_OPS_ENGINE_DIR`
     (aceita o caminho do .pyz ou do diretório que o contém);
  3. instalação GLOBAL padrão: `~/.orqo/engine.pyz` (cenário air-gap:
     artefato offline instalável);
  4. nada → erro instruído, rc 3.

Uso:
    python3 scripts/lib/engine_resolver.py [--root DIR]   # imprime o caminho
Biblioteca:
    from engine_resolver import resolve_engine, EngineNotFoundError
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

ENGINE_NAME = "engine.pyz"
ORQO_DIR = ".orqo"
ENV_ENGINE_DIR = "CODEBASE_OPS_ENGINE_DIR"


class EngineNotFoundError(RuntimeError):
    """Nenhum engine.pyz nos três degraus de resolução."""


def instrucao_de_instalacao() -> str:
    return (
        "[codebase-ops] nenhum engine.pyz encontrado.\n"
        f"Procurado em: ./{ORQO_DIR}/{ENGINE_NAME} (e acima), "
        f"${ENV_ENGINE_DIR}, ~/{ORQO_DIR}/{ENGINE_NAME}.\n"
        "Remédios:\n"
        "  1) no repo do codebase-ops: bash scripts/build-engine.sh\n"
        "     e copie dist/engine.pyz para <projeto>/.orqo/engine.pyz;\n"
        "  2) instale a versão desejada em ~/.orqo/engine.pyz;\n"
        f"  3) ou aponte {ENV_ENGINE_DIR} para o engine.pyz (ou o diretório dele).")


def _do_env(env: dict[str, str] | None) -> Path | None:
    bruto = (env or {}).get(ENV_ENGINE_DIR, "") or \
        os.environ.get(ENV_ENGINE_DIR, "")
    bruto = bruto.strip()
    if not bruto:
        return None
    p = Path(bruto).expanduser()
    if p.is_file():
        return p.resolve()
    candidato = p / ENGINE_NAME
    if candidato.is_file():
        return candidato.resolve()
    return None


def resolve_engine(start: Path | None = None,
                   env: dict[str, str] | None = None,
                   home: Path | None = None) -> Path:
    """Devolve o caminho do engine.pyz na ordem local → env → ~/.orqo.

    Levanta EngineNotFoundError com instrução quando não há motor em lugar
    nenhum — o chamador decide imprimir e sair 3.
    """
    inicio = (start or Path.cwd()).resolve()
    for cand in (inicio, *inicio.parents):
        pyz_local = cand / ORQO_DIR / ENGINE_NAME
        if pyz_local.is_file():
            return pyz_local.resolve()

    por_env = _do_env(env)
    if por_env is not None:
        return por_env

    lar = home or Path.home()
    pyz_global = lar / ORQO_DIR / ENGINE_NAME
    if pyz_global.is_file():
        return pyz_global.resolve()

    raise EngineNotFoundError(instrucao_de_instalacao())


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    root: Path | None = None
    if "--root" in argv:
        i = argv.index("--root")
        root = Path(argv[i + 1]).resolve()
        del argv[i:i + 2]
    try:
        print(resolve_engine(start=root))
        return 0
    except EngineNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
