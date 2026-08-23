#!/usr/bin/env python3
"""judge_gate.py — o verdict do Judge vira autoridade bloqueante (TCK-1348 / SPC-0086 N1).

Lacuna medida: `pipeline-judge.py` persiste o verdict em
`.archagents/99-memory/verdicts/TCK_NNNN.json` e **nenhum caminho de fechamento
o lia** — um `REJECTED` atravessava `verifying→done` (que é o gate de ship do
driver, `handoff.py`). A classe de decisão chamava-se `judge-verdict` sem
consultar verdict algum: fallback otimista puro.

Contrato (fail-closed sobre o verdict PRESENTE):
  - ``overall == "REJECTED"``            → bloqueia;
  - verdict ilegível/malformado/enum inválido → bloqueia (erro de Judge é
    rejeição, não passe — T5 do threat model DES-0822);
  - ``dimensions.safety.score < 70``     → bloqueia. Piso calibrado na
    distribuição real de 159 verdicts: 70 = um achado heurístico isolado
    (dominado por falso-positivo de fixture; ex. TCK-1336, shipped);
    50 = git destrutivo no diff ou acumulação; 20 = crítico. Subir o piso é
    livre (P9); descer exige ADR;
  - verdict AUSENTE → NÃO bloqueia. O judge ainda não é obrigatório em todo
    caminho; ausência-bloqueia quebraria todo ticket não-judgeado e é decisão
    de posicionamento (ADR), não de implementação — residual T2 documentado
    no DES-0822.

Segurança: ``ticket_id`` é validado (``^TCK-\\d{4,}$``) antes de compor path
(T3 — traversal). Conteúdo do verdict é dado, nunca instrução (P11).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

VALID_OVERALL = frozenset(
    {"EXCELLENT", "ACCEPTABLE", "NEEDS_IMPROVEMENT", "REJECTED"})
BLOCKING_OVERALL = frozenset({"REJECTED"})
JUDGE_SAFETY_FLOOR = 70

_TICKET_RE = re.compile(r"^TCK-\d{4,}$")


def verdict_path(ticket_id: str, root: str | Path | None = None) -> Path:
    """Caminho do verdict. `root=None` resolve para o cwd.

    TCK-1636: a v1 exigia `root` e fazia `Path(root)` direto. `transition_ticket`
    passa o `root` do CLI **sem resolver**, que é `None` quando ninguém digita
    `--root` — então `cbctl ticket transition TCK-NNNN --to done` **sempre**
    estourava `TypeError`. O `handoff.py` passava `Path` já resolvido e por isso
    o caminho dele funcionava: o mesmo gate, vivo num chamador e morto no outro
    (a reincidência que [[gate-only-in-handoff-is-decorative]] registra).
    """
    return (Path(root or ".") / ".archagents" / "99-memory" / "verdicts"
            / f"{ticket_id.replace('-', '_')}.json")


def check_judge_verdict(ticket_id: str, root: str | Path) -> list[str]:
    """Failures que impedem fechamento/ship. Lista vazia = caminho livre.

    Nunca levanta: exceção inesperada vira failure (fail-closed) — um gate que
    morre de exceção é um gate desligado.
    """
    failures: list[str] = []
    if not _TICKET_RE.match(str(ticket_id or "")):
        return [f"judge-gate: ticket_id inválido ({ticket_id!r}) — refuso compor path"]

    # TCK-1636: a composição do path ficava FORA do try, então a promessa da
    # docstring ("nunca levanta") valia para tudo menos para a primeira linha
    # que faz trabalho. `Path(None)` estourava TypeError e derrubava o CLI —
    # um gate que morre de exceção é um gate desligado, e este morria antes de
    # chegar na proteção escrita para impedir exatamente isso.
    try:
        path = verdict_path(ticket_id, root)
    except Exception as exc:  # fail-closed, como o resto da função
        return [f"judge-gate: não consegui compor o path do verdict ({exc})"]
    try:
        if not path.is_file():
            return []  # sem verdict = judge não exercido; ver docstring/DES-0822
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return [f"judge-gate: verdict de {ticket_id} não é objeto JSON "
                    f"(erro de Judge bloqueia — fail-closed)"]

        if "overall" not in data:
            # Contêiner de lições, não decisão: o canal de lições armazena
            # lessons dentro do arquivo de verdict SEM emitir julgamento
            # (seed do lesson_channel; 0 de 160 decisões reais vêm sem
            # `overall`). Sem decisão não há o que vincular — mesma classe do
            # residual T2 (remover a chave = deletar o verdict; documentado).
            return []
        overall = str(data.get("overall") or "").strip().upper()
        if overall not in VALID_OVERALL:
            failures.append(
                f"judge-gate: verdict de {ticket_id} com decisão inválida "
                f"({data.get('overall')!r}) — fora do enum "
                f"{sorted(VALID_OVERALL)}; erro de Judge bloqueia")
        elif overall in BLOCKING_OVERALL:
            failures.append(
                f"judge-gate: Judge REJECTED para {ticket_id} "
                f"(score={data.get('score')}) — fechamento/ship bloqueado; "
                f"re-execute a entrega e um novo judge, ou decisão humana")

        safety = ((data.get("dimensions") or {}).get("safety") or {})
        score = safety.get("score")
        if not isinstance(score, (int, float)) or isinstance(score, bool):
            failures.append(
                f"judge-gate: verdict de {ticket_id} sem dimensions.safety.score "
                f"numérico ({score!r}) — erro de Judge bloqueia")
        elif score < JUDGE_SAFETY_FLOOR:
            failures.append(
                f"judge-gate: safety {score} < piso {JUDGE_SAFETY_FLOOR} para "
                f"{ticket_id} ({str(safety.get('notes') or '')[:120]}) — "
                f"fechamento/ship bloqueado")
    except Exception as exc:  # noqa: BLE001 — fail-CLOSED por contrato (T5)
        failures.append(
            f"judge-gate: falha lendo verdict de {ticket_id} ({exc.__class__.__name__}: "
            f"{exc}) — erro de Judge bloqueia (fail-closed)")
    return failures
