#!/usr/bin/env python3
"""artifact_lineage.py — lineage SEMÂNTICA, não só grafo de IDs (TCK-1355 / SPC-0090 N7).

"Um grafo de IDs sintaticamente válido não demonstra que o conteúdo verificado
corresponde ao que será entregue."

A cadeia `SPC → TCK → DES → RUN → VER` já é validada estruturalmente: os IDs
existem e apontam uns para os outros (`cbctl validate: ticket linked artifacts
exist`). Isso prova que os arquivos existem — não que o VER avaliou ESTE
ticket, nem que o RUN executou ESTE design.

Três formas de quebra que o grafo válido não pega, todas medidas neste repo:

1. **Stub** — VER cujo corpo é "Relatorio criado por create_report.py": 71 no
   acervo, todos `approved` (FND-0104). ID válido, conteúdo vazio.
2. **Stale** — VER anterior ao baseline `executing` do ticket: verificou uma
   árvore que não é a entregue. A catraca SPC-0058 já cobre por tempo; aqui a
   régua é de CONTEÚDO.
3. **Cross-ticket** — VER que referencia OUTRO ticket. O link existe, o
   conteúdo fala de outra entrega.

Esta régua é sobre CONTEÚDO. Não substitui a catraca (tempo) nem o
`cbctl validate` (existência) — soma a elas.
"""

from __future__ import annotations

import re
from pathlib import Path

STUB_MARKERS = (
    "relatorio criado por",
    "relatório criado por",
    "report created by",
    "criado por scripts/ops/",
)

# Linhas de conteúdo (fora de headings/negrito/template) que separam um VER
# real de um stub. Calibrado no VER que o driver emite: escopo do gate +
# resultado + o que não foi coberto.
MIN_SUBSTANTIVE_LINES = 3

_TICKET_RE = re.compile(r"\bTCK-\d{4,}\b")
_FM_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


def split_frontmatter(text: str) -> tuple[str, str]:
    m = _FM_RE.match(text or "")
    return (m.group(1), m.group(2)) if m else ("", text or "")


def tickets_mentioned(text: str) -> set[str]:
    return set(_TICKET_RE.findall(text or ""))


def check_lineage(ver_text: str, *, ticket_id: str,
                  design_ids: list[str] | None = None,
                  run_ids: list[str] | None = None) -> list[str]:
    """Failures de lineage semântica de um VER. Vazio = cadeia sustentada.

    Nunca levanta: entrada ilegível já foi tratada por quem leu o arquivo.
    """
    failures: list[str] = []
    frontmatter, body = split_frontmatter(ver_text)
    lowered = (body or "").lower()

    # Stub = marcador do gerador E nada de substancial em volta. A presença do
    # marcador SOZINHA não basta: o driver (TCK-1420) emite o corpo do template
    # e ANEXA o escopo real da verificação — medido, 22 falhas na suíte quando
    # a régua olhava só o marcador. O que distingue stub de VER real é o
    # conteúdo que o acompanha, não o texto herdado do template.
    if any(marker in lowered for marker in STUB_MARKERS):
        substantive = [
            ln.strip() for ln in (body or "").splitlines()
            if ln.strip()
            and not ln.strip().startswith(("#", "**", "---"))
            and not any(marker in ln.lower() for marker in STUB_MARKERS)
        ]
        if len(substantive) < MIN_SUBSTANTIVE_LINES:
            failures.append(
                f"lineage: VER de {ticket_id} é stub auto-gerado "
                f"({len(substantive)} linha(s) de conteúdo além do template) — "
                f"ID válido, conteúdo vazio; o grafo passa e a verificação não "
                f"aconteceu")

    mentioned = tickets_mentioned(f"{frontmatter}\n{body}")
    if mentioned and ticket_id not in mentioned:
        failures.append(
            f"lineage: VER vinculado a {ticket_id} fala de {sorted(mentioned)[:3]} "
            f"— evidência cross-ticket: o link existe, o conteúdo é de outra entrega")

    # O VER precisa ancorar em ALGO da cadeia: o próprio ticket, um design ou
    # um run vinculado. Sem âncora, é texto solto com frontmatter correto.
    anchors = {ticket_id, *(design_ids or []), *(run_ids or [])}
    combined = f"{frontmatter}\n{body}"
    if not any(a and a in combined for a in anchors):
        failures.append(
            f"lineage: VER não referencia {ticket_id} nem design/run vinculado "
            f"— nada liga o conteúdo verificado ao que será entregue")
    return failures


def read_text(path: str | Path) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""
