#!/usr/bin/env python3
"""falsifier_evidence.py — o ticket declara o que reprova antes do fix (TCK-2482).

Escrever o teste que **falha antes da correção** é o que separa "o teste passou"
de "o teste prova alguma coisa". Medido em 2026-08-13 no corpo dos tickets
`done`, por faixa de ID:

    até TCK-1357 ....  0/100      (0%)
    TCK-1928..2163 .. 44/60    (73,3%)
    TCK-2164..2474 .. 31/61    (50,8%)   ← recuando

A prática nasceu do zero, chegou a 73% e caiu para metade. A causa tem nome no
repositório: **formalizar não tem mecanismo**. `## Falsificador` existia apenas
como prosa em `core/06-verify/VERIFY.md:36`, sem consumidor.

O dado que dispensa a objeção usual ("o gate vai punir quem faz certo"): exigir
**evidência conferível** junto da marca custa **2 de 44** na janela boa — 95,5%
do trabalho honesto já satisfaz. Medido antes de cabear (precondição, TCK-2178).

Este módulo é espelho estrutural de `lib/ver_evidence.py`, que já resolveu o
mesmo problema para os limites do VER: acha a marca, exige conteúdo real, e
rejeita preenchimento de template. O `_PLACEHOLDER_RE` de lá existe porque
`**Fora do escopo:** W` satisfazia o predicado de graça em 26 de 80 acertos.

Autorizado pelo ADR-0038 (gate bloqueante — advisory é o estado que recuou).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

BASELINE_PATH = ".archagents/.falsifier-baseline.json"

#: A marca. Aceita a seção formal e as formulações que o acervo já usa.
_MARCA_RE = re.compile(r"(?i)(falsificad\w*|o que reprova|refuta\w*)")

#: Evidência conferível: comando, caminho de arquivo do repo, ou `path:linha`.
#: É o que separa "declarei que existe falsificador" de "aqui está ele".
_CONFERIVEL_RE = re.compile(
    r"(?i)(`[^`]{4,}`|\bpytest\b|\bgit show\b|scripts/|tests/|\.py:\d+|:\d{2,})")

#: Preenchimento de template — copiado de ver_evidence._PLACEHOLDER_RE, mesma
#: razão: seção obrigatória sem conteúdo vira ritual, e ritual verde é pior que
#: ausência declarada.
_PLACEHOLDER_RE = re.compile(
    r"(?i)^\s*[-*•]?\s*(nenhum[ao]?|n/?a|nada|none|todo|tbd|a\s+definir|"
    r"[a-z]|\(.{0,12}\)|\.{2,})\s*[.!]?\s*$")


#: Comentário HTML — inclusive o do próprio template que este ticket adicionou
#: ao produtor. Achado F1 do verify: o comentário-guia contém `arquivo:linha`
#: entre backticks, então casava a regra de evidência e **todo ticket novo
#: nascia isento do gate**. É a classe `fixture-que-satisfaz-o-predicado-por-
#: construção`, reencenada pela afordância que o mesmo commit criou.
_COMENTARIO_HTML_RE = re.compile(r"<!--.*?-->", re.S)


def _sem_comentarios(texto: str) -> str:
    return _COMENTARIO_HTML_RE.sub(" ", texto)


#: Cabeçalho markdown: FRONTEIRA de seção, nunca conteúdo dela.
_CABECALHO_RE = re.compile(r"^\s{0,3}#{1,6}\s")


def _tem_conteudo(body: str, pos_fim: int) -> str | None:
    """Texto real depois da marca, ou None se for placeholder/comentário/vazio.

    TCK-2588. A v1 pegava as 3 próximas linhas não-vazias **sem parar na
    fronteira de seção**, e o `.lstrip(" :*—-_#")` logo abaixo removia o `#`.
    Efeito: o cabeçalho da SEÇÃO SEGUINTE virava "conteúdo real" da seção
    vazia.

    Medido no acervo: **25 tickets com `## Falsificador` vazio, 25 aprovados,
    zero reprovados**. O gate que a ADR-0038 tornou bloqueante para exigir
    "o teste tem de falhar antes do fix" nunca rejeitou essa classe — e um
    deles era o ticket que eu mesmo fechei declarando que o gate protegia.

    A varredura para no primeiro cabeçalho. Seção vazia devolve `None`, que é
    o que ela sempre deveria ter devolvido.
    """
    fim_linha = body.find("\n", pos_fim)
    if fim_linha == -1:
        fim_linha = len(body)
    candidatos = [body[pos_fim:fim_linha]]
    for linha in body[fim_linha + 1:].splitlines():
        if not linha.strip():
            continue
        if _CABECALHO_RE.match(linha):
            break          # acabou a seção; o que vem depois não é dela
        candidatos.append(linha)
        if len(candidatos) > 3:
            break
    for bruto in candidatos:
        primeira = bruto.strip().lstrip(" :*—-_#").rstrip("*_ ")
        if not primeira or (len(primeira) <= 3 and primeira.isalpha()):
            continue
        if not _PLACEHOLDER_RE.match(primeira):
            return primeira
    return None


def declara_falsificador(body: str) -> bool:
    """A marca existe, tem conteúdo real, e há evidência conferível por perto.

    Comentários HTML são removidos ANTES da análise: o template do produtor é
    um comentário, e contá-lo como declaração isentaria todo ticket novo.
    """
    body = _sem_comentarios(body)
    for m in _MARCA_RE.finditer(body):
        if _tem_conteudo(body, m.end()) is None:
            continue
        # a evidência pode estar na vizinhança da declaração, não coladinha
        janela = body[m.start(): m.start() + 1200]
        if _CONFERIVEL_RE.search(janela):
            return True
    return False


def carregar_baseline(root: str | Path | None = None) -> set[str]:
    """Tickets pré-gate. P6: só ticket NOVO é cobrado; a lista só encolhe."""
    f = Path(root or ".") / BASELINE_PATH
    if not f.is_file():
        return set()
    try:
        data = json.loads(f.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        # fail-CLOSED aqui, ao contrário do gate: a ausência é sobre O DADO
        # (quem está isento), não sobre a existência do medidor — mesma
        # assimetria documentada em ver_evidence.
        raise
    return set(data.get("tickets") or [])


def check_falsifier(body: str, *, ticket_id: str,
                    root: str | Path | None = None) -> list[str]:
    """Failures que impedem o ticket de fechar. Vazio = aceito.

    Nunca levanta por baseline ausente: sem baseline, todo ticket é cobrado —
    que é o estado correto para um repo novo.
    """
    try:
        baseline = carregar_baseline(root)
    except (OSError, ValueError):
        baseline = set()
    if ticket_id in baseline:
        return []
    if declara_falsificador(body):
        return []
    return [
        f"{ticket_id}: falta o FALSIFICADOR — declare o que reprova ANTES do "
        f"fix, com evidência conferível (o comando que fica vermelho hoje, ou "
        f"`arquivo:linha`). Teste que não consegue falhar não prova entrega "
        f"(ADR-0038). Use --force com justificativa se for exceção consciente."
    ]
