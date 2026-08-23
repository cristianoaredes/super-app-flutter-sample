#!/usr/bin/env python3
"""loop_controller.py — central loop health + strategy selection (SPC-0028 unit 4 / TCK-0229).

The Loop Controller is the single concept that owns loop accounting and turns the
per-unit signals into one observable health score:
  - lesson utility (unit 2, lib/lesson_utility)
  - strategy effectiveness (unit 3, lib/strategy)
  - loop stall (attempt_count vs cap; aligns with verify-run --check-attempts)
  => composite loop_quality in [0, 100].

It NEVER changes caps or policy on its own (SAFETY floor + ratchet P9): max_attempts
is bounded by the same absolute safe cap as the verify-run gate, and select_strategy
only *suggests* — adoption remains a human/ticket decision.
"""
from __future__ import annotations

import sys
from pathlib import Path

from lib.lesson_utility import aggregate_lesson_utility
from lib.strategy import compute_effectiveness, list_strategies, suggest

# TCK-0475: fonte única em lib/runstate.py (antes espelhado aqui e em verify-run).
from lib.runstate import ABSOLUTE_SAFE_MAX_ATTEMPTS  # noqa: F401
LOOP_ATTEMPT_CAP = 2  # default stall threshold (verify-run --check-attempts default)


def _as_int(value, default: int = 0) -> int:
    try:
        return int(value if value is not None else default)
    except (TypeError, ValueError):
        return default


def _as_float(value, default: float = 0.0) -> float:
    try:
        return float(value if value is not None else default)
    except (TypeError, ValueError):
        return default


#: Status finais que significam "o run CHEGOU lá" — bater o teto e completar é
#: convergência, não stall (TCK-2090).
_COMPLETED_STATUSES = frozenset({"completed", "done"})


def stall_retry_stats(run_datas) -> dict:
    """Fonte única de stall/retry sobre runs do loop (TCK-2090).

    Antes desta função o mesmo nome respondia TRÊS números (medido 2026-08-06):
    41,2% publicado (`aggregate_events`: retry contado como stall, sobre 17),
    3,6% aqui via glob (outro denominador: todos os 192 runs) e 0,0% via SQLite
    (a hidratação não carregava `attempt_count` — o predicado lia ausência).

    E o predicado antigo punia convergência: 6 dos 7 "travados" COMPLETARAM —
    quatro deles são as travessias autônomas mais bem-sucedidas do acervo
    (deltas +34/+27/+39/+36). Precisar da 2ª tentativa é o loop fazendo o que
    existe para fazer.

    Contrato:
      - ``n_looped``   — exerceu o loop (attempts>=1 OU ``paused-attempts``;
        TCK-1416: quem nunca entrou não dilui a taxa).
      - ``retried``    — precisou de >=2 tentativas (a semântica antiga, com
        nome honesto).
      - ``stalled``    — bateu o teto E não chegou a completed/done, OU
        ``paused-attempts``.
      - taxas em % sobre ``n_looped``; **None** sem denominador (nunca 0.0
        fingindo saúde medida).
    """
    n_looped = retried = stalled = 0
    for rd in (run_datas or []):
        rd = rd or {}
        raw = rd.get("attempt_count")
        # TCK-1416: `True` é `int` em Python — sem esta guarda um run com
        # `attempt_count: true` (JSON malformado) entra no denominador como se
        # tivesse iterado uma vez. A v1 desta função perdeu a guarda ao
        # consolidar os três produtores; `test_bool_is_not_counted_as_attempt`
        # pegou na suíte completa.
        attempts = 0 if isinstance(raw, bool) else _as_int(raw)
        status = str(rd.get("status") or "").lower()
        paused = status == "paused-attempts"
        if attempts < 1 and not paused:
            continue
        n_looped += 1
        if attempts >= 2:
            retried += 1
        if paused or (attempts >= LOOP_ATTEMPT_CAP
                      and status not in _COMPLETED_STATUSES):
            stalled += 1
    return {
        "n_looped": n_looped,
        "retried": retried,
        "stalled": stalled,
        "loop_stall_rate": round(stalled / n_looped * 100, 1) if n_looped else None,
        "loop_retry_rate": round(retried / n_looped * 100, 1) if n_looped else None,
    }


#: TCK-2231: RUN de LINHAGEM não exerceu o loop, logo não vota na QUALIDADE
#: dele. O predicado vive AQUI, no ponto onde os dois caminhos convergem — a
#: v1 filtrava só no SQL (`db.py`), e o caminho GLOB (que 11 de 14 índices do
#: acervo usam) movia `loop_quality` de 90.0 para 66.6 com 9 linhagens.
#: Dois filtros divergiriam pela unidade: TCK-1860, TCK-2178.
FORMATOS_FORA_DA_QUALIDADE = frozenset({"lineage", "flat-legacy"})


def exerceu_o_loop(rd: dict) -> bool:
    """O run participou do loop? `lineage`/`flat-legacy` existem, mas não."""
    return str((rd or {}).get("run_format") or "dir") not in FORMATOS_FORA_DA_QUALIDADE


def compute_loop_health(run_datas) -> dict:
    """Composite loop health across runs. loop_quality in [0, 100], neutral 50.

    quality = 50 + lesson_utility_avg*50 - loop_stall_rate*100, clamped — rewards
    runs where lessons helped, penalizes runs that hit the attempt cap.
    """
    todos = list(run_datas or [])
    # o filtro aplicado AQUI cobre os dois caminhos (SQLite e glob) de uma vez
    runs = [r for r in todos if exerceu_o_loop(r)]
    fora = len(todos) - len(runs)
    n = len(runs)
    lu = aggregate_lesson_utility(runs)

    strategy_effectiveness = {
        name: compute_effectiveness(runs, name)["effectiveness"] for name in list_strategies()
    }
    # TCK-2027: `None` = estratégia sem amostra medida pelo judge (não "efetividade
    # zero"). Antes o dict só continha floats e `max` sobre ele elegia qualquer um;
    # agora quem não foi medido está fora da eleição — do contrário `best_strategy`
    # apontaria para uma estratégia que nunca rodou. Sem nenhuma medida, o default
    # declarado é a resposta honesta.
    _medidas = {k: v for k, v in strategy_effectiveness.items() if v is not None}
    best_strategy = max(_medidas, key=_medidas.get) if _medidas else "default"

    # TCK-2090: fonte única — antes este bloco contava `attempts >= CAP` sobre
    # TODOS os runs (convergência punida como stall, denominador diluído) e o
    # caminho SQLite nem carregava attempt_count (taxa 0.0 eterna).
    sr = stall_retry_stats(runs)
    # loop_stall_rate aqui é FRAÇÃO (0..1) por contrato histórico deste dict;
    # as taxas percentuais vivem nas chaves *_rate do stats.
    loop_stall_rate = (sr["stalled"] / sr["n_looped"]) if sr["n_looped"] else 0.0
    loop_stall_rate = round(loop_stall_rate, 3)

    quality = 50.0 + lu["lesson_utility_avg"] * 50.0 - loop_stall_rate * 100.0
    quality = round(max(0.0, min(100.0, quality)), 1)

    # SPC-0033/F0.3: surface accumulated spend alongside the other signals.
    #
    # TCK-1958: a v1 somava `loop_cost_usd` de TODO run, e o total virou ficção.
    # Medido em 2026-08-05: 69 runs carregavam custo com **zero** volta
    # registrada (`attempt_count`/`loop_iterations` em 0 ou ausentes) e **zero**
    # `executor.log` — só dois valores, 78.55 e 0.01, repetidos. Soma: US$ 5.341
    # de semente contra US$ 17,46 realmente medidos, o que fazia
    # `cost_per_run_usd` sair 31,71 quando o custo real por travessia é 3–14.
    #
    # O critério é derivável do próprio run_data (sem tocar disco): custo só é
    # medição quando houve **volta registrada**. Sem volta não há dispatch, e
    # sem dispatch não há o que cobrar. Os dados históricos NÃO são apagados
    # (P6, append-only) — o LEITOR passa a desconsiderá-los, e o denominador
    # fica explícito em `n_runs_with_cost`.
    # TCK-2089: participante = satisfaz o MESMO predicado de participação que o
    # filtro de custo exige (volta registrada), SEM exigir o custo. É a
    # população contra a qual a cobertura de custo é honesta — comparar os
    # medidos com `runs_total` (192) dilui, e com nada (o estado anterior)
    # esconde que 2 medidos são 2 de 17.
    participantes = [
        rd for rd in runs
        if _as_int((rd or {}).get("attempt_count")) >= 1
        or _as_int((rd or {}).get("loop_iterations")) >= 1
    ]
    medidos = [
        _as_float(rd.get("loop_cost_usd"))
        for rd in participantes
        if _as_float(rd.get("loop_cost_usd"))
    ]
    cost_total = round(sum(medidos), 6)

    return {
        "runs_lineage": fora or None,   # cobertura: existiu, não votou
        "loop_quality": quality,
        "lesson_utility_avg": lu["lesson_utility_avg"],
        "n_runs_with_lessons": lu["n_runs_with_lessons"],  # outcome cohort
        "n_runs_consulted": lu.get("n_runs_consulted", lu["n_runs_with_lessons"]),
        # TCK-2178: o TRANSPORTE é onde a procedência declarada morre. O
        # agregado já produzia estes dois; sem repassá-los aqui o render caía no
        # terceiro estado ("não medida") e o operador via a média sem o n dela.
        # Mesma classe de `declared-provenance-beats-heuristic`: verifique o
        # transporte, não só o produtor.
        "runs_with_judge_outcome": lu.get("runs_with_judge_outcome"),
        "runs_excluded_proxy": lu.get("runs_excluded_proxy"),
        "runs_excluded_unknown_source": lu.get("runs_excluded_unknown_source"),
        "n_runs_no_outcome": lu.get("n_runs_no_outcome", 0),
        "strategy_effectiveness": strategy_effectiveness,
        "best_strategy": best_strategy,
        "loop_stall_rate": loop_stall_rate,
        # TCK-2090: a semântica antiga (precisou de >=2 tentativas) continua
        # medida — com o nome do que ela é.
        "loop_retry_rate": sr["loop_retry_rate"],
        "n_looped_runs": sr["n_looped"],
        "runs_total": n,
        "loop_cost_usd_total": cost_total,
        # TCK-1958: o denominador honesto do custo. `runs_total` conta TODO run;
        # este conta só os que têm custo MEDIDO. Sem ele, dividir 17,46 por 169
        # daria 0,10/run — errado na direção oposta, e igualmente inútil.
        "n_runs_with_cost": len(medidos),
        # TCK-2089: e a POPULAÇÃO desse denominador — 2 medidos são 2 de quê.
        "n_runs_loop_participants": len(participantes),
    }


class LoopController:
    """Owns loop accounting + strategy selection. Suggestion-only; never mutates policy."""

    def __init__(self, max_attempts: int = LOOP_ATTEMPT_CAP, budget_usd: float | None = None) -> None:
        # bound by the absolute safe cap — the controller can never widen past the floor
        self.max_attempts = min(int(max_attempts), ABSOLUTE_SAFE_MAX_ATTEMPTS)
        # SPC-0033/F0.3: advisory spend cap (None = no budget gate). Never widens
        # or bypasses the SAFETY attempt-cap floor — it is an ADDITIONAL paused-*.
        self.budget_usd = float(budget_usd) if budget_usd is not None else None

    def select_strategy(self, profile: dict) -> str:
        """Suggest (not adopt) a loop strategy for a ticket profile."""
        return suggest(profile)["strategy"]

    def check_budget(self, run_data: dict) -> dict:
        """SPC-0033/F0.3 (F22): advisory budget gate. Returns whether accumulated
        loop_cost_usd exceeds the cap, mapping to the EXISTING human-unlockable
        `paused-budget` run state — never auto-mutates policy (P9 ratchet). With no
        budget set, the gate NEVER trips."""
        spent = _as_float((run_data or {}).get("loop_cost_usd"))
        if self.budget_usd is None:
            return {"over_budget": False, "spent_usd": spent, "cap_usd": None,
                    "suggested_status": None}
        over = spent > self.budget_usd
        return {
            "over_budget": over,
            "spent_usd": spent,
            "cap_usd": self.budget_usd,
            "suggested_status": "paused-budget" if over else None,
        }

    def health(self, run_datas) -> dict:
        return compute_loop_health(run_datas)
