#!/usr/bin/env python3
"""ticket_commits.py — os commits de um ticket, com procedência (TCK-2479).

O judge caía em `working_tree_aggregate` em 198 de 216 vereditos — não por
escolha, mas porque **as três fontes acima do agregado não têm produtor**:

    diff-executor.txt ....  1 de 280 runs
    diff.txt ............   7 de 280 runs
    run.json.commits ....   0 de 280 runs  (o template nasce `[]`)

O `_capturar_diff` do driver só roda quando o DRIVER executa — e o implementador
real é o agente do harness. Classe `instrument-wired-to-nothing`: o TCK-1138
construiu o `ticket_range` e o ligou a um campo que ninguém preenche.

Este módulo é a **quarta fonte, e a única que resolve o acervo sem exigir
disciplina nova**: a convenção de commit já carrega o ID do ticket em 339 de
400 mensagens, e `git log --grep` resolve **175 de 198 (88,4%)** dos tickets
que hoje caem no agregado.

Fonte única de propósito — `check-scope.py` NÃO serve aqui: ele devolve *nomes
de arquivo* e mede `merge-base(base)..HEAD`, isto é, a história da branch e não
a entrega (o defeito que o TCK-1834 já corrigiu lá). Reusá-lo reimportaria o
erro.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

#: 4 dígitos + sufixo opcional. `\d+` aceitava `TCK-1`, que no `--grep`
#: casaria 477 commits (achado F3 do verify).
_TCK_RE = re.compile(r"^TCK-\d{4}[a-z]?$")


def _git(root: Path, *args: str, timeout: int = 60) -> str:
    try:
        proc = subprocess.run(["git", "-C", str(root), *args],
                              capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return proc.stdout if proc.returncode == 0 else ""


def commits_do_ticket(root: str | Path, ticket_id: str, *,
                      declarados: list[str] | None = None) -> tuple[list[str], str]:
    """SHAs do ticket e a PROCEDÊNCIA de onde vieram.

    Devolve `(shas, fonte)` — a fonte é declarada, nunca inferida pelo valor
    (lição `declared-provenance-beats-heuristic`, TCK-2027). Fontes, em ordem
    de confiança:

    - `run-declared` — o run registrou os commits; é o mais forte.
    - `git-log-grep` — a mensagem de commit cita o ticket (convenção do repo).
    - `ticket-branch`  — existe branch `*/TCK-NNNN-*` e ela diverge da base.
    - `""` com lista vazia — **não resolveu**. Quem chama decide o que fazer;
      este módulo nunca devolve "a árvore inteira" como consolo.
    """
    root = Path(root)
    if not _TCK_RE.match(str(ticket_id or "")):
        return [], ""

    if declarados:
        shas = [str(s).strip() for s in declarados if str(s).strip()]
        if shas:
            return shas, "run-declared"

    # ÂNCORA obrigatória: `--grep=TCK-247` casava 25 commits, nenhum deles do
    # TCK-247 — todos de TCK-2471..2476 (achado F3). E o pior não era o ruído:
    # o resolvedor devolvia `low_confidence=False` sobre escopo provadamente
    # largo, ou seja, PIOR que o agregado que ele substitui, que ao menos se
    # declara incerto. `[^0-9a-z]` fecha o sufixo; `$` fecha o fim de linha.
    # sem `\b`: o regex do git não o suporta e o padrão casaria ZERO (medido —
    # `TCK-2477` deixava de resolver). O sufixo negado já é a âncora efetiva.
    padrao = rf"TCK-{ticket_id.removeprefix('TCK-')}([^0-9A-Za-z]|$)"
    saida = _git(root, "log", "--all", "--format=%H", "--extended-regexp",
                 f"--grep={padrao}")
    shas = [l.strip() for l in saida.splitlines() if l.strip()]
    if shas:
        return shas, "git-log-grep"

    ramos = _git(root, "branch", "--all", "--format=%(refname:short)")
    alvo = [b.strip() for b in ramos.splitlines() if f"{ticket_id}-" in b]
    for branch in alvo:
        saida = _git(root, "log", "--format=%H", f"origin/develop..{branch}")
        shas = [l.strip() for l in saida.splitlines() if l.strip()]
        if shas:
            return shas, "ticket-branch"

    return [], ""
