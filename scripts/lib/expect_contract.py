#!/usr/bin/env python3
"""expect_contract.py — semântica única de `expect` nos runners (TCK-1349 / SPC-0086 N2).

O mesmo `acceptance[]` era interpretado de forma diferente por dois runners:

| Eixo | criteria-check (antes) | pipeline-verify (antes) |
|---|---|---|
| `expect` | `re.search` + exit code | **carregava e IGNORAVA** — só exit code |
| regex inválida | **crash** (`re.PatternError` subindo) | n/a |
| timeout | 120s configurável | 30s hardcoded |

Resultado medido: `echo 5` com `expect: "^0$"` falhava num e passava no outro —
evidência contraditória sobre o mesmo critério. E regex inválida era fail-**open**
por crash: um gate que morre de exceção é um gate desligado.

Este módulo é o dono da AVALIAÇÃO. Cada runner mantém seu próprio executor
(argv/shell/cwd são responsabilidade de quem executa) e delega o veredito aqui.
Nenhum consumidor deve reimplementar a regra — cópia órfã serve piso velho em
silêncio (memória do projeto: path-ownership-invariant).

Fail-closed em toda ambiguidade: timeout, regex inválida ou avaliação
impossível resultam em `ok=False`.
"""

from __future__ import annotations

import re

# Unificado. O pipeline-verify usava 30s hardcoded, o que produzia ERROR
# espúrio em checks legítimos (a suíte do repo passa de 30s com frequência).
DEFAULT_TIMEOUT_S = 120

# `expect` que significa "só o exit code importa". O pipeline-verify normaliza
# ausência para `True`; o criteria-check usa `None`. Ambos entram aqui.
_EXIT_CODE_ONLY = (None, True, "", "true", "True")


def evaluate(*, expect, exit_code: int | None, output: str = "",
             timed_out: bool = False) -> dict:
    """Veredito canônico de um critério já executado.

    Retorna ``{"ok", "status", "matched", "reason"}`` com
    ``status in {"pass","fail","timeout","error"}``. Nunca levanta.

    ``matched`` é ``None`` quando não houve regex a avaliar — distinto de
    ``False`` (avaliou e não bateu). Consumidores que reportam evidência
    dependem dessa diferença para não afirmar comparação que não ocorreu.
    """
    if timed_out:
        return {"ok": False, "status": "timeout", "matched": None,
                "reason": "execução excedeu o timeout"}

    rc_ok = exit_code == 0

    if expect in _EXIT_CODE_ONLY:
        return {"ok": rc_ok, "status": "pass" if rc_ok else "fail",
                "matched": None,
                "reason": "" if rc_ok else f"exit_code={exit_code}"}

    pattern = str(expect)
    try:
        matched = re.search(pattern, output or "",
                            re.IGNORECASE | re.MULTILINE) is not None
    except re.error as exc:
        # TCK-1349: antes isto subia e MATAVA o gate — fail-open por crash.
        return {"ok": False, "status": "error", "matched": None,
                "reason": f"expect não é regex válida ({pattern!r}): {exc}"}

    ok = rc_ok and matched
    if ok:
        reason = ""
    elif not rc_ok and not matched:
        reason = f"exit_code={exit_code} e expect {pattern!r} não bateu"
    elif not rc_ok:
        reason = f"exit_code={exit_code} (expect bateu)"
    else:
        reason = f"expect {pattern!r} não bateu na saída"
    return {"ok": ok, "status": "pass" if ok else "fail",
            "matched": matched, "reason": reason}
