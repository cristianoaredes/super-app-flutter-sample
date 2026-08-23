#!/usr/bin/env python3
"""ticketstate.py — Contrato CANÔNICO de status terminais de TICKET (TCK-0103).

Ticket ≠ run (não confundir com lib/runstate.py):
  - RUN é uma execução: seu ciclo termina em completed/aborted
    (lib/runstate.TERMINAL_STATUSES).
  - TICKET é a demanda: seu ciclo termina em done/closed/rejected — é este
    conjunto que decide elegibilidade de archive (archive-state.py, ADR-0004)
    e o estágio "done" do cockpit (ops-cockpit-snapshot.py).

Antes deste módulo o mesmo conjunto vivia duplicado como `ELIGIBLE` em
archive-state.py e `TERMINAL_STATUSES` em ops-cockpit-snapshot.py — divergência
silenciosa era questão de tempo (FND-20260612-21). Fonte única, padrão TCK-0029.
"""

from __future__ import annotations

TICKET_TERMINAL_STATUSES = frozenset({"done", "closed", "rejected"})
