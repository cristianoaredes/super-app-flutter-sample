#!/usr/bin/env python3
"""lesson_channel.py — TCK-1135/DES-0659: lesson CONSUMPTION channel helpers.

Diagnosis: the learning loop was write-only since ~2026-07-11. Both execute
entry points consulted lessons scoped to the CURRENT ticket id only
(`query_lessons*(ticket=<self>)`), so any FRESH ticket (zero own history —
the norm since 07-11) received no lessons and recorded
`lessons_consulted=[]`. The only cross-ticket fallback lived in the
autonomous orchestrator main (W3b) — the harness/agent-driven path had
none. Compounded by FND-0089 noise pollution (boilerplate verdicts turned
into "lessons").

This module provides the reconnection, shared by both entry points:

- ``consult_lessons_with_fallback()`` — same-ticket ranked consult, then a
  cross-ticket severity-ordered REAL-lesson fallback (NOISE_PATTERNS
  filtered — FND-0089 noise is never injected).
- ``cross_consult_lessons()`` — the fallback step alone (used by the
  ``execute_iteration`` push, which keeps its own same-ticket consult).
- ``probe_lesson_channel()`` — cheap liveness probe: how many consecutive
  recent runs recorded zero consulted lessons. Wired as an advisory
  (never a gate) into ``scripts/reflect.py --json``.

Fail-open throughout (framework convention): failures degrade to empty
results / an "alive" probe with an ``error`` note — never raise.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

__all__ = [
    "consult_lessons_with_fallback",
    "cross_consult_lessons",
    "probe_lesson_channel",
    "record_consult",
]

_SEVERITY_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3}


#: Candidatos puxados do store ANTES de rankear (TCK-2478). Era 12 — uma janela
#: de `1 critical + 11 high` que tornava 147 das ~195 lições inalcançáveis por
#: construção. O corte final continua sendo o `limit` do chamador.
LESSON_POOL_MAX = 400


def _memory_override_dir() -> Path | None:
    """CODEBASE_OPS_MEMORY_DIR override (hermetic tests / scoped consumers).

    When set, the lesson source is THIS directory (the canonical store),
    never the SQLite index of the ambient repo — otherwise the real store
    leaks into hermetic runs (regressão pós-TCK-1135)."""
    env = os.environ.get("CODEBASE_OPS_MEMORY_DIR")
    return Path(env) if env else None


def _lessons_from_memory_dir(mem: Path, *, limit: int) -> list:
    """Read lessons straight from the canonical store (lessons.json +
    verdicts/*.json), noise-filtered, severity-ordered. Fail-open → []."""
    rows: list[dict] = []
    try:
        # Consumidor deep-codebase-ops (TCK-0130): o escritor canônico (`db.add_lesson(memory_dir_override=mem)`)
        # grava em `mem/lessons/lessons.json` — o layout de 99-memory/. O leitor
        # só olhava `mem/lessons.json`: com CODEBASE_OPS_MEMORY_DIR apontando
        # para um 99-memory/ temporário, `teach` gravava e `consult` não via
        # (medido em 2026-08-17 num consumidor). Lê os dois; o canônico primeiro.
        vistos: set[str] = set()
        for lj in (mem / "lessons" / "lessons.json", mem / "lessons.json"):
            if not lj.is_file():
                continue
            data = json.loads(lj.read_text(encoding="utf-8"))
            items = data if isinstance(data, list) else data.get("lessons", [])
            for it in items:
                if isinstance(it, dict) and _is_real_lesson(it):
                    texto = str(it.get("lesson") or it.get("text") or "")
                    if texto in vistos:
                        continue
                    vistos.add(texto)
                    rows.append({"lesson": texto,
                                 "severity": str(it.get("severity", "low")),
                                 "ticket": str(it.get("ticket") or it.get("ticket_id") or "")})
        vdir = mem / "verdicts"
        if vdir.is_dir():
            for vf in sorted(vdir.glob("*.json")):
                try:
                    v = json.loads(vf.read_text(encoding="utf-8"))
                except Exception:
                    continue
                for it in (v.get("lessons") or []):
                    if isinstance(it, dict) and _is_real_lesson(it):
                        rows.append({"lesson": str(it.get("lesson") or it.get("text") or ""),
                                     "severity": str(it.get("severity", "low")),
                                     "ticket": str(v.get("ticket") or v.get("ticket_id") or "")})
    except Exception:
        return []
    rows.sort(key=lambda r: (_SEVERITY_ORDER.get(r["severity"], 4), r["lesson"]))
    return rows[: int(limit)]


def _is_real_lesson(lesson: object) -> bool:
    """True for a usable lesson row: has text, is not an error marker, and
    does not match the FND-0089 blind-era boilerplate (NOISE_PATTERNS —
    single source in lib/db, same list the write-time quarantine uses)."""
    if not isinstance(lesson, dict) or lesson.get("error"):
        return False
    text = str(lesson.get("lesson") or "").strip()
    if not text:
        return False
    try:
        from lib.db import NOISE_PATTERNS
        if any(p in text for p in NOISE_PATTERNS):
            return False
    except Exception:
        pass  # fail-open: if the noise list is unavailable, keep the row
    return True


# TCK-1945: stopwords mínimas PT/EN para o rank léxico do fallback. Curta de
# propósito — o objetivo é matar artigos/preposições, não fazer NLP.
_STOPWORDS = frozenset(
    "de da do das dos para por com sem que nao não uma umas uns como mais "
    "the of and to in is are for on with a o e em um os as no na ao aos à às"
    .split())


def _termos(texto: str) -> "set[str]":
    """Tokens >=4 chars, minúsculos, sem stopwords — o mesmo proxy da medição
    que expôs o banner (TCK-1945)."""
    import re as _re
    return {t for t in _re.findall(r"[0-9a-zA-Zçãõáéíóúâêô_-]{4,}",
                                   (texto or "").lower())
            if t not in _STOPWORDS}


def cross_consult_lessons(*, root=None, limit: int = 3,
                          title_hint: "str | None" = None) -> list:
    """Cross-ticket fallback: REAL lessons from the canonical SQLite index,
    noise-filtered — ranked by TITLE RELEVANCE when a hint is given.

    TCK-1945 (medido): sem o hint, este fallback devolvia o MESMO top-3 por
    severidade global para TODO ticket — 1 conjunto distinto em 12 tickets,
    overlap com o título 19% e acidental. Não era retrieval, era um banner, e
    `lessons_consulted` registrava consumo de lições que não tinham como
    ajudar (dado fabricado virando evidência — a classe do ADR-0029).

    Com `title_hint`, a janela larga é reordenada por interseção de termos
    título↔lição (desempate: a ordem severity/id que já vinha do SQL). Sem
    overlap nenhum, o comportamento antigo fica intacto — severidade continua
    sendo melhor que nada quando o léxico não discrimina.

    Returns [] on ANY failure (fail-open), including a corrupt index
    (LessonStoreError): a suspect index must not silently feed the executor
    either — same policy as the orchestrator's W3b fallback.
    """
    try:
        from lib.db import LessonStoreError, get_db, query_lessons
    except Exception:
        return []
    # TCK-2478: a janela ERA o defeito, não o ranking. `limit*4 or 12` puxava
    # 12 candidatos ordenados por `severity, id DESC` — e o `_rank` reordenava
    # só dentro deles. Medido em 2026-08-13: 481 citações em 280 runs usaram
    # **17 lições distintas** de ~195 no store; 147 nunca foram devolvidas, e
    # as três primeiras respondiam por 74,8%. Não é preferência do rank: as
    # outras não podiam sequer ser candidatas.
    #
    # O pool agora cobre o store; o `_rank` (overlap de termos com o título do
    # ticket) decide de verdade, e o `limit` continua cortando no fim.
    alvo = _termos(title_hint or "")

    def _rank(reais: list) -> list:
        if alvo:
            # sort estável: overlap decide; empate preserva a ordem que veio
            # da fonte (severity/id no SQL, severity/texto no override).
            reais = sorted(
                reais,
                key=lambda l: -len(alvo & _termos(str(l.get("lesson") or ""))))
        return reais[: int(limit)]

    mem = _memory_override_dir()
    if mem is not None and root is None:
        # janela larga TAMBÉM aqui: o rank precisa de candidatos para
        # reordenar — cortar antes de rankear reintroduziria o banner no
        # caminho hermético.
        return _rank(_lessons_from_memory_dir(mem, limit=max(int(limit) * 4, LESSON_POOL_MAX)))
    try:
        db = get_db(str(root)) if root else get_db()
        try:
            # Wider window: noise filtering shrinks it back to the top-K real
            # lessons even when the store is FND-0089-polluted.
            rows = query_lessons(db, limit=max(int(limit) * 4, LESSON_POOL_MAX))
        finally:
            db.close()
    except LessonStoreError:
        return []
    except Exception:
        return []
    return _rank([l for l in rows if _is_real_lesson(l)])


def consult_lessons_with_fallback(ticket: str, *, root=None, limit: int = 3,
                                  title_hint: "str | None" = None) -> dict:
    """Same-ticket ranked consult with a cross-ticket REAL-lesson fallback.

    Returns ``{"lessons": [...], "needles": [...], "source": ..., "error": ...}``
    where source is ``"ticket"`` (own history), ``"cross"`` (fallback) or
    ``"none"``; ``error`` carries a note on degraded outcomes (e.g.
    ``index_corrupt``) instead of raising. Needles follow the TCK-0889
    text-first contract (``lib.db.lesson_needles``) so a later
    ``mark_lessons_applied`` can actually match them.
    """
    out: dict = {"lessons": [], "needles": [], "source": "none", "error": None}
    mem = _memory_override_dir()
    if mem is not None and root is None:
        # Hermetic override (CODEBASE_OPS_MEMORY_DIR): a fonte é a store
        # canônica do override — o índice SQLite do repo ambiente NUNCA vaza.
        try:
            all_rows = _lessons_from_memory_dir(mem, limit=max(int(limit) * 4, LESSON_POOL_MAX))
            own = [r for r in all_rows if r.get("ticket") == ticket][: int(limit)]
            if own:
                lessons = own
            else:
                # TCK-1945: o fallback hermético usa o MESMO rank por título
                # do caminho SQLite — dois rankings divergentes fariam os
                # testes medirem um canal e a produção usar outro.
                alvo = _termos(title_hint or "")
                if alvo:
                    all_rows = sorted(
                        all_rows,
                        key=lambda l: -len(alvo & _termos(str(l.get("lesson") or ""))))
                lessons = all_rows[: int(limit)]
            out["lessons"] = lessons
            out["source"] = ("ticket" if own else "cross") if lessons else "none"
            out["needles"] = [str(l.get("lesson") or "").strip()[:80]
                              for l in lessons if l.get("lesson")]
        except Exception as e:
            out["error"] = str(e)
        return out
    try:
        from lib.db import LessonStoreError, get_db, lesson_needles, query_lessons_ranked
    except Exception as e:  # import failure: classic fail-open
        out["error"] = f"import: {e}"
        return out
    try:
        db = get_db(str(root)) if root else get_db()
    except LessonStoreError as e:
        out["error"] = f"index_corrupt: {e}"
        return out
    except Exception as e:
        out["error"] = str(e)
        return out
    try:
        lessons = [l for l in query_lessons_ranked(db, ticket=ticket, limit=limit,
                                                   root=root)
                   if _is_real_lesson(l)]
        source = "ticket"
        if not lessons:
            lessons = cross_consult_lessons(root=root, limit=limit,
                                            title_hint=title_hint)
            source = "cross"
        out["lessons"] = lessons
        out["source"] = source if lessons else "none"
        try:
            out["needles"] = lesson_needles(lessons)
        except Exception:
            out["needles"] = [str(l.get("lesson") or "").strip()[:80]
                              for l in lessons if l.get("lesson")]
        return out
    except LessonStoreError as e:
        out["error"] = f"index_corrupt: {e}"
        return out
    except Exception as e:
        out["error"] = str(e)
        return out
    finally:
        try:
            db.close()
        except Exception:
            pass


def probe_lesson_channel(root=None, *, runs_dir=None, max_scan: int = 100) -> dict:
    """Liveness probe for the lesson CONSUMPTION channel (TCK-1135).

    Scans recent runs (newest first) counting how many consecutive runs
    recorded an EMPTY ``lessons_consulted`` — the exact symptom of the dead
    channel (32 zero runs since ~2026-07-11). Advisory only, never a gate.

    Returns::

        {"alive": bool|None,           # False when the newest ELIGIBLE run consulted
                                       # nothing; None when nothing eligible was scanned
         "runs_since_consult": int|None,  # consecutive newest eligible runs, empty
         "runs_scanned": int,
         "n_runs_eligible": int,       # runs that went through the consult path
         "n_runs_not_eligible": int,   # runs structurally unable to consult
         "last_consult_run": str|None}    # newest run dir that DID consult (if any)

    Fail-open: no runs / unreadable dir / any error -> alive=True with
    runs_since_consult=None (absence of evidence is not evidence of death).

    TCK-2029 — segmentação por produtor. A v1 media TODO run da janela. Só o
    driver consulta (`pipeline-driver._record_lessons_consulted`); um RUN criado
    por `cbctl run create` para registrar o ciclo de um ticket não consulta e
    nunca vai — e `ensure_loop_telemetry` dá a ele `lessons_consulted: []`, igual
    a um consult que não achou nada. Medido em 2026-08-05: dos 13 runs mais
    recentes, 12 tinham lista vazia e nenhum era travessia do driver; o probe
    reportava `alive: false` com `runs_since_consult: 12`.

    Isso importa porque o outro produtor de consulta (o orchestrator) está
    DEPRECATED (ADR-0032). Sem segmentar, o denominador passa a ser dominado por
    runs incapazes de consultar e `alive: false` vira o estado PERMANENTE — um
    alarme que grita sempre não informa nada.

    A elegibilidade vem da marca `lesson_consult_attempted`, escrita pelo
    produtor. Não é inferível: consultar-e-não-achar e nunca-consultar produzem
    o mesmo `[]` no disco. Runs históricos (sem a marca) não são elegíveis, então
    o probe responde `None` — não-medido — até o driver rodar de novo. O limiar
    NÃO foi relaxado: entre elegíveis, `alive` segue exigindo `since == 0`.
    """
    result: dict = {"alive": True, "runs_since_consult": None,
                    "runs_scanned": 0, "n_runs_eligible": 0,
                    "n_runs_not_eligible": 0, "last_consult_run": None}
    try:
        if runs_dir is not None:
            rd = Path(runs_dir)
        else:
            base = (Path(root) if root
                    else Path(__file__).resolve().parent.parent.parent)
            rd = base / ".archagents" / "13-execution" / "runs"
        if not rd.is_dir():
            return result

        def _sort_key(d: Path):
            try:
                data = json.loads((d / "run.json").read_text(encoding="utf-8"))
                ts = str(data.get("started_at") or data.get("completed_at") or "")
            except Exception:
                ts = ""
            return (ts, d.name)

        runs = [d for d in rd.iterdir() if d.is_dir() and (d / "run.json").is_file()]
        runs.sort(key=_sort_key, reverse=True)
        runs = runs[: int(max_scan)]
        result["runs_scanned"] = len(runs)
        if not runs:
            return result
        since = 0
        n_eligible = 0
        n_not_eligible = 0
        for d in runs:
            try:
                data = json.loads((d / "run.json").read_text(encoding="utf-8"))
                lc = data.get("lessons_consulted") or []
                attempted = data.get("lesson_consult_attempted") is True
            except Exception:
                lc = []
                attempted = False
            # TCK-2029: um consult registrado é prova de tentativa mesmo em run
            # anterior à marca — retrocompatibilidade sem inferir o caso vazio.
            if not attempted and not (isinstance(lc, list) and lc):
                n_not_eligible += 1
                continue
            n_eligible += 1
            if isinstance(lc, list) and lc:
                result["last_consult_run"] = d.name
                break
            since += 1
        result["n_runs_eligible"] = n_eligible
        result["n_runs_not_eligible"] = n_not_eligible
        if n_eligible == 0:
            # Terceiro estado: nada elegível na janela. `None`, não False — o
            # próprio contrato deste módulo já diz que ausência de evidência não
            # é evidência de morte; faltava aplicá-lo à amostra vazia.
            result["alive"] = None
            result["runs_since_consult"] = None
            return result
        result["runs_since_consult"] = since
        result["alive"] = since == 0
        return result
    except Exception as e:  # fail-open: probe failure never breaks reflect
        result["error"] = str(e)
        return result


def record_consult(root, ticket: str, needles, *, run_hint: str | None = None,
                   run_dir=None) -> "Path | None":
    """Write-back canônico de `lessons_consulted` (TCK-2100 / DES-1041 D1).

    Existiam DUAS implementações deste write-back, e cada uma tinha algo que a
    outra não tinha:

    ==============================  ==================  ==================
    qualidade                       execute-with-learn  pipeline-driver
    ==============================  ==================  ==================
    resolve o run pelo TICKET       sim                 recebe pronto
    escreve sob lock + atomic       sim                 write_text direto
    preserva run.json corrompido    sim (TCK-0596)      sobrescrevia
    grava lesson_consult_attempted  não                 sim (TCK-2029)
    ==============================  ==================  ==================

    Esta função é a UNIÃO das quatro — não uma terceira cópia. `record_consult`
    é o produtor único; os dois chamadores antigos delegam.

    `lesson_consult_attempted` é o **terceiro estado do canal**: sem ele,
    "consultou e não achou nada" fica idêntico no disco a "nunca passou pela
    consulta" (`ensure_loop_telemetry` põe `lessons_consulted: []` em TODO run,
    inclusive num criado por `cbctl run create`), e o probe de liveness lê o
    segundo como canal morto. A tentativa é fato do PRODUTOR; nenhum leitor a
    infere — por isso é gravada mesmo quando a consulta volta vazia.

    Devolve o run dir escrito, ou ``None`` quando não há run alvo / o arquivo
    está corrompido. Nunca levanta: o canal é fail-open por contrato (TCK-1135).
    """
    from lib.artifacts import atomic_write
    from lib.runstate import ensure_loop_telemetry, resolve_run_for_ticket, runstate_lock

    root = Path(root)
    if run_dir is None:
        runs_dir = root / ".archagents" / "13-execution" / "runs"
        # NUNCA o "global newest" — era a wrong-attribution do F12.
        run_dir = resolve_run_for_ticket(runs_dir, ticket, run_hint)
    if run_dir is None:
        return None
    run_dir = Path(run_dir)

    consulted = [str(n).strip()[:80] for n in (needles or []) if str(n or "").strip()]
    rj = run_dir / "run.json"
    try:
        with runstate_lock(root):
            existed = rj.exists()
            try:
                rdata = json.loads(rj.read_text(encoding="utf-8")) if existed else {}
            except Exception as e:
                # TCK-0596: run.json EXISTE mas está corrompido — NÃO é o mesmo
                # caso de "ainda não há run.json". Sobrescrever destruiria o
                # arquivo que a investigação humana precisa intacto.
                if existed:
                    # E o aviso é parte do contrato, não enfeite: preservar em
                    # SILÊNCIO deixaria o operador sem saber que existe um
                    # run.json corrompido. A v1 desta consolidação perdeu o
                    # warning; `test_corrupt_run_json_is_not_overwritten` pegou.
                    import logging as _logging
                    _logging.getLogger("codebase-ops.lesson-channel").warning(
                        "run.json CORROMPIDO em %s — NÃO sobrescrevendo "
                        "(preservado intacto para investigação humana); "
                        "lessons_consulted NÃO registrado nesta chamada: %s",
                        rj, e)
                    return None
                rdata = {}
            rdata["lessons_consulted"] = list(dict.fromkeys(
                list(rdata.get("lessons_consulted") or []) + consulted))
            rdata["lesson_consult_attempted"] = True
            rdata = ensure_loop_telemetry(rdata)
            atomic_write(rj, json.dumps(rdata, indent=2, ensure_ascii=False),
                         overwrite=True)
    except Exception:
        return None  # fail-open: telemetria nunca derruba quem a produz
    return run_dir
