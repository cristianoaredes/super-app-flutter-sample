#!/usr/bin/env python3
"""Hermeticidade de critérios de aceite (TCK-1419 / SPC-0092 módulo C, FND-0103).

Um `acceptance[].check` que depende de estado fora da árvore do repositório é
verificável **uma única vez** — no instante da execução. Depois vira afirmação
sem prova.

Caso que motivou o gate: `TCK-1180` tinha como critério `bash /tmp/accept-1180.sh`.
O arquivo não existe mais (`exit 127`), e esse ticket é a evidência do critério de
saída #1 do PLN-0017 ("1 ticket S E2E pelo orquestrador") — fechado em 2026-07-26
sobre uma prova que já não se sustenta.

Fonte única, consumida por dois gates com papéis distintos:
  - `gates/criteria-check.py` — **sinaliza** (`external_paths` no resultado), para
    não invalidar retroativamente o acervo existente;
  - `gates/dor-check.py` — **bloqueia** na entrada, onde o custo de corrigir é zero.

Este arquivo é o dono da regra. Nenhum consumidor deve reimplementá-la — cópia
órfã serve piso velho em silêncio.
"""

from __future__ import annotations

import re
from pathlib import Path

# Prefixos absolutos que NÃO tornam um critério dependente de estado externo:
# interpretadores, binários de sistema e o sumidouro padrão.
INERT_ABSOLUTE_PREFIXES = (
    "/dev/null", "/bin/", "/usr/bin/", "/usr/local/bin/",
    "/opt/homebrew/bin/", "/usr/sbin/", "/sbin/",
)

# O caminho tem que INICIAR um token: precedido por início-de-string, whitespace
# ou operador de shell. Sem essa fronteira, "tests/test_x.py" casaria "/test_x.py"
# e todo critério relativo viraria falso-positivo.
_PATH_TOKEN = re.compile(r"(?:^|[\s'\";|&(><=])((?:~|\$HOME)?/[^\s'\";|&)>]*)")


def external_paths(check: str, root: Path | str | None = None) -> list[str]:
    """Caminhos do `check` que apontam para fora da árvore de *root*.

    Devolve lista ordenada e deduplicada; vazia significa hermético. Nunca
    levanta — um gate que quebra por causa do próprio detector é pior que o
    defeito que ele procura.
    """
    found: list[str] = []
    if not check:
        return found
    root_resolved = ""
    if root is not None:
        try:
            root_resolved = str(Path(root).resolve())
        except (OSError, RuntimeError):
            root_resolved = ""
    for raw in _PATH_TOKEN.findall(check):
        token = raw.strip().rstrip(".,")
        if not token:
            continue
        if token.startswith("~") or token.startswith("$HOME"):
            found.append(token)
            continue
        if any(token.startswith(p) for p in INERT_ABSOLUTE_PREFIXES):
            continue
        if root_resolved:
            try:
                if str(Path(token).resolve()).startswith(root_resolved):
                    continue
            except (OSError, RuntimeError):
                pass
        found.append(token)
    return sorted(dict.fromkeys(found))
