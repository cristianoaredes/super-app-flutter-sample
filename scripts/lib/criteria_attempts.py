#!/usr/bin/env python3
"""Série de tentativas do criteria gate (TCK-1417 / SPC-0092 módulo B).

O loop que de fato converge neste sistema não é o do orchestrator (que não
implementa) nem só o do driver: é **harness agent implementa → `criteria-check`
reprova → agente corrige → gate verde**. Ele foi exercido 7× nas sessões de
2026-07-30/31 e não aparecia em telemetria alguma.

Este módulo persiste a série, append-only (P6): uma linha por execução real do
gate. Derivadas: `criteria_retries_to_green` (quantas reprovas até o verde) e
`criteria_first_pass_rate`.

Contrato de honestidade: tickets sem execução registrada ficam **fora da
amostra**; a cobertura declara isso. Nunca assumir 1 tentativa para quem não
tem registro — foi exatamente esse tipo de suposição que produziu o falso-verde
do FND-0102.

Fail-open: falha de escrita nunca derruba o gate (o veredito é a evidência
primária; esta série é medição secundária).
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ATTEMPTS_RELPATH = Path("13-execution") / "criteria-attempts.jsonl"


def attempts_path(root: Path | str) -> Path:
    return Path(root) / ".archagents" / ATTEMPTS_RELPATH


def record_attempt(root: Path | str, ticket_id: str, *, verdict: str,
                   passed: int, total: int,
                   failed_checks: list[str] | None = None) -> bool:
    """Anexa uma execução do gate. Devolve True se gravou.

    Nunca levanta: chamador é um gate, e medição não pode alterar veredito.
    """
    try:
        path = attempts_path(root)
        # TCK-0498: writer de .archagents precisa da guarda de isolamento. Sem
        # ela a suíte contamina a store real — medido nesta própria entrega:
        # 110 linhas de TCK-9999 e 10 de TCK-0051 vazaram de fixtures antes da
        # guarda existir. IsolationError propaga (não é OSError/TypeError/Value)
        # para o teste falhar alto; o call-site no gate a trata como warning.
        from lib.artifactguard import ensure_test_isolation
        ensure_test_isolation(path, artifact="criteria-attempts")
        path.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "ticket": str(ticket_id),
            "verdict": str(verdict),
            "passed": int(passed),
            "total": int(total),
        }
        if failed_checks:
            entry["failed_checks"] = [str(c)[:200] for c in failed_checks[:10]]
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
        return True
    except (OSError, TypeError, ValueError):
        return False


def read_attempts(root: Path | str) -> list[dict]:
    """Lê a série tolerando linhas malformadas (nunca levanta)."""
    out: list[dict] = []
    try:
        path = attempts_path(root)
        if not path.is_file():
            return out
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(entry, dict) and entry.get("ticket"):
                out.append(entry)
    except (OSError, UnicodeDecodeError):
        return out
    return out


def aggregate(root: Path | str) -> dict:
    """Derivadas da série. Amostra vazia → métricas `None` + cobertura declarada.

    `criteria_retries_to_green`: mediana de reprovas ANTES do primeiro verde,
    contando só tickets que chegaram ao verde (quem nunca ficou verde não tem
    "retries até o verde" — incluí-lo inventaria um número).
    """
    entries = read_attempts(root)
    by_ticket: dict[str, list[dict]] = {}
    for e in entries:
        by_ticket.setdefault(str(e["ticket"]), []).append(e)

    retries: list[int] = []
    first_pass = 0
    reached_green = 0
    for _tid, series in by_ticket.items():
        fails_before_green = 0
        green = False
        for e in series:
            if str(e.get("verdict")) == "pass":
                green = True
                break
            fails_before_green += 1
        if green:
            reached_green += 1
            retries.append(fails_before_green)
            if fails_before_green == 0:
                first_pass += 1

    median = None
    if retries:
        ordered = sorted(retries)
        mid = len(ordered) // 2
        median = (float(ordered[mid]) if len(ordered) % 2
                  else (ordered[mid - 1] + ordered[mid]) / 2)

    return {
        "criteria_retries_to_green": median,
        "criteria_first_pass_rate": (round(first_pass / reached_green * 100, 1)
                                     if reached_green else None),
        "criteria_tickets_sampled": len(by_ticket),
        "criteria_tickets_green": reached_green,
        "criteria_attempts_total": len(entries),
        "criteria_attempts_coverage": "ok" if entries else "no_attempts_recorded",
    }
