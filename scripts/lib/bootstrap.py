#!/usr/bin/env python3
"""bootstrap.py — single shared path bootstrap (SPC-0037/F0.7-T2, findings F6/F27).

Replaces the scattered per-file path-insert preambles and the obfuscated
aliased-sys bootstrap idiom (T3) with ONE idempotent helper.

Resolution model after F0.7:
  - tests collect via pyproject ``pythonpath = ["scripts"]``;
  - an editable install (`pip install -e .`) resolves `lib.*` via package metadata;
  - direct-CLI invocation (`python3 scripts/X.py`) already has scripts/ as sys.path[0].

``ensure_scripts_on_path()`` is the explicit belt-and-suspenders for arbitrary-cwd or
subdir-entrypoint invocation (e.g. scripts/ops/**, run as files via cbctl). It uses
slice-assignment (the single sanctioned mutation point) rather than a scattered
preamble, so the no-scattered-path-mutation invariant the CI guard enforces holds.
Stdlib-only; no side effects beyond the path.
"""
import os
import sys
from pathlib import Path

_SCRIPTS_DIR = str(Path(__file__).resolve().parent.parent)  # scripts/
_REPO_ROOT = str(Path(__file__).resolve().parent.parent.parent)  # repo root


def ensure_scripts_on_path() -> str:
    """Idempotently prepend scripts/ to sys.path so ``from lib.X`` resolves. Returns
    the scripts dir."""
    if _SCRIPTS_DIR not in sys.path:
        sys.path[:0] = [_SCRIPTS_DIR]
    return _SCRIPTS_DIR


def ensure_scripts_on_path_from(script_file: str) -> str:
    """Bootstrap for sub-scripts (e.g. scripts/ops/**) that don't have scripts/
    on sys.path yet.  Pass ``__file__`` and this will compute & prepend the
    scripts/ directory.  Idempotent.  Returns the scripts dir."""
    scripts_dir = str(Path(script_file).resolve().parent)
    # Walk up until we find the dir that contains lib/bootstrap.py
    p = Path(script_file).resolve().parent
    while p != p.parent:
        if (p / "lib" / "bootstrap.py").exists():
            scripts_dir = str(p)
            break
        p = p.parent
    if scripts_dir not in sys.path:
        sys.path[:0] = [scripts_dir]
    return scripts_dir


def get_repo_root() -> Path:
    """Return the repository root as a Path.

    TCK-2088 (DES-1038 D3): ``CBOPS_REPO_ROOT`` overrides, evaluated at CALL
    time. Without it, a script judged/invoked from another project resolves the
    root to where *this file lives* — the framework — and reads (or worse,
    writes) the framework's ``.archagents`` while believing it is looking at the
    caller's project (`worktree-root-resolution-trap`). The post-done hook sets
    the variable only in the subprocess it spawns; every other caller sees the
    historical behavior, byte-identical.
    """
    env = os.environ.get("CBOPS_REPO_ROOT", "").strip()
    if env:
        p = Path(env)
        if (p / ".archagents").is_dir():
            return p.resolve()
        # Raiz declarada mas sem acervo: honrar seria apontar o instrumento
        # para o nada; ignorar em silêncio esconderia o erro de quem setou.
        print(f"[bootstrap] CBOPS_REPO_ROOT={env} sem .archagents/ — ignorado",
              file=sys.stderr)
    _avisar_se_raiz_diverge()
    return Path(_REPO_ROOT)


def raiz_do_invocador(inicio: "Path | None" = None) -> "Path | None":
    """A raiz do projeto governado que contém o cwd, ou None.

    TCK-2334. Sobe procurando `.archagents/`. É a contraparte de `_REPO_ROOT`:
    aquele diz onde o CÓDIGO mora, este diz de onde ele foi CHAMADO. Quando as
    duas divergem, algum instrumento está apontado para o repositório errado.
    """
    d = (inicio or Path.cwd()).resolve()
    for cand in (d, *d.parents):
        if (cand / ".archagents").is_dir():
            return cand
    return None


#: Uma vez por processo — 43 scripts chamam `get_repo_root`, e alguns o fazem
#: em laço. Repetir o aviso viraria ruído, e ruído é o que faz o operador
#: parar de ler (foi assim que este defeito sobreviveu).
_JA_AVISOU = False


def _avisar_se_raiz_diverge() -> None:
    """Terceiro estado: nem "está tudo certo", nem falha — "isto pode não ser
    o que você quis".

    TCK-2334, medido em 2026-08-11: rodando `/ops-config docs` no projeto ipcd,
    o `sync-skills` regenerou o espelho do FRAMEWORK e imprimiu "✓" com rc 0.
    Cem por cento do efeito no repositório errado e nenhum sinal. O operador
    concluiu, razoavelmente, que era ruído a ignorar.

    Este aviso NÃO bloqueia: `get_repo_root` serve dezenas de leitores
    legítimos, e gerir o framework a partir de um cwd qualquer é uso normal. O
    fail-closed pertence aos caminhos de ESCRITA — `sync-skills.sh` já o tem.
    O que faltava aqui era o silêncio deixar de ser total.
    """
    global _JA_AVISOU
    if _JA_AVISOU or os.environ.get("CBOPS_SILENCIAR_AVISO_DE_RAIZ"):
        return
    try:
        invocador = raiz_do_invocador()
    except OSError:
        return                       # cwd apagado sob os pés: não é hora de opinar
    if invocador is None or str(invocador) == _REPO_ROOT:
        return
    _JA_AVISOU = True
    print(f"[bootstrap] atenção: você está em {invocador}, mas este script opera "
          f"sobre {_REPO_ROOT} (a raiz de onde ELE mora). Se esperava efeito no "
          f"seu projeto, pare e confira — exporte CBOPS_REPO_ROOT para escolher.",
          file=sys.stderr)


def get_scripts_dir() -> Path:
    """Return the scripts/ directory as a Path."""
    return Path(_SCRIPTS_DIR)
