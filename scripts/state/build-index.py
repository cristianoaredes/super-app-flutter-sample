#!/usr/bin/env python3
"""build-index.py — Indexer SQLite para .archagents/ (SPC-0026, TCK-0197).

Lê artefatos canônicos (MD+YAML, JSON) → popula .archagents/.index.db.
MD permanece source of truth; SQLite é projeção derivada (regenerável, .gitignore).

Modos:
  build-index.py                    rebuild completo (default)
  build-index.py --check            verifica se índice está atualizado (exit 1 se drift)
  build-index.py --incremental      atualiza só arquivos modificados (mtime check)
  build-index.py --root PATH        raiz do projeto (default: cwd)

Idempotência: rebuild sempre reconstrói do filesystem (como archive-state.py).
Crash-safe: se falhar no meio, o .index.db antigo permanece (write em temp + rename).
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

# Ensure scripts/ is on sys.path for lib imports
SCRIPTS_DIR = Path(__file__).resolve().parent.parent

from lib.db import SCHEMA, INDEX_SCHEMA_VERSION, index_path, read_schema_version, lesson_identity, _matches_noise_pattern
from lib.frontmatter import FRONTMATTER_RE, parse_frontmatter, parse_frontmatter_file, _read_text_cached, read_json_cached
from lib.paths import paths, archived_tickets
from lib.runstate import ensure_loop_telemetry  # SPC-0034/F0.4: telemetry contract (single source)


# ---------------------------------------------------------------------------
# Readers (canônico → dict)
# ---------------------------------------------------------------------------

def _read_tickets(tickets_dir: Path) -> list[dict]:
    """Lê TCK-*.md → frontmatter → list[dict].

    Normaliza listas para string (alguns campos podem vir como lista do parser).
    """
    def _str(val: object) -> str:
        if isinstance(val, list):
            return ", ".join(str(v) for v in val)
        return str(val) if val is not None else ""

    rows = []
    for md in sorted(tickets_dir.glob("TCK-*.md")):
        fm = parse_frontmatter_file(md)
        if not fm.get("id"):
            continue
        rows.append({
            "id": _str(fm.get("id")),
            "slug": _str(fm.get("slug")),
            "title": _str(fm.get("title")),
            "status": _str(fm.get("status")),
            "priority": _str(fm.get("priority")),
            "kind": _str(fm.get("kind")),
            "effort": _str(fm.get("effort")),
            "source": _str(fm.get("source")),
            "linked_spec": _str(fm.get("linked_spec")),
            "created_at": _str(fm.get("created_at")),
            "done_at": _str(fm.get("done_at")),
        })
    return rows


def _read_runs(runs_dir: Path) -> list[dict]:
    """Lê RUN-*/run.json → list[dict]."""
    rows = []
    if not runs_dir.exists():
        return rows
    for run_dir in sorted(runs_dir.iterdir()):
        if not run_dir.is_dir():
            continue
        run_json = run_dir / "run.json"
        if not run_json.exists():
            continue
        try:
            data = read_json_cached(run_json)
        except (json.JSONDecodeError, OSError):
            continue
        # SPC-0034/F0.4: normalize via the single-source contract so legacy runs
        # (no telemetry keys; legacy "iterations") land on canonical defaults.
        tel = ensure_loop_telemetry(data)
        rows.append({
            # TCK-2174 (achado do verify): `get("id", default)` só dispara com
            # a chave AUSENTE — com `"id": null` o produtor gravava None
            # enquanto o check usava `or parent.name`. Dois runs null viravam
            # 1 linha contra 2 no sensor: DRIFT eterno sobrevivendo no caso
            # nulo. `or` nos DOIS lados alinha produtor e sensor.
            "id": data.get("id") or run_dir.name,
            "ticket": data.get("ticket", ""),
            "design": data.get("design", ""),
            # TCK-2477: status RECONCILIADO, não o cru. O run.json fica preso
            # em `running` quando o REPORT.md já é terminal (110 de 579 pares
            # divergem), e gravar o cru fazia `db.query_runs(stale=True)`
            # contar 81 zumbis que os leitores vivos já reconciliavam via
            # `effective_run_status`. A dívida era de TRANSPORTE, não de
            # história — por isso o conserto é aqui, não no acervo (P6).
            "status": _status_reconciliado(run_dir, data),
            "started_at": data.get("started_at", ""),
            "ended_at": data.get("ended_at", ""),
            "result": data.get("result", ""),
            "iterations": data.get("iterations") or data.get("current_step") or 0,
            "environment": data.get("environment", ""),
            "mode": data.get("mode", ""),
            # loop-telemetry projection; lessons_consulted JSON-encoded for TEXT column
            "loop_iterations": tel["loop_iterations"],
            "lessons_consulted": json.dumps(tel["lessons_consulted"]),
            "loop_cost_usd": tel["loop_cost_usd"],
            "loop_strategy": tel["loop_strategy"],
            "context_peak": tel["context_peak"],
            "final_judge_delta": tel["final_judge_delta"],
            # TCK-2027: a PROCEDÊNCIA viaja com o número. Sem ela o consumidor
            # (select_strategy_with_feedback) não distingue delta do judge de
            # delta `criteria-proxy`, e a coluna solta do valor fazia o filtro de
            # procedência barrar TODO run vindo do índice — feedback morto por
            # perda de campo no transporte, não por dado ruim.
            # Lido de `data`, não de `tel`: não é campo de LOOP_TELEMETRY_FIELDS
            # (aquele contrato de 7 é citado nominalmente em várias superfícies).
            "final_judge_delta_source": data.get("final_judge_delta_source") or "",
            # TCK-2090: idem procedencia — o predicado de stall/retry le attempt_count;
            # sem a projecao, o caminho SQLite hidrata ausencia e responde 0.0.
            "attempt_count": data.get("attempt_count"),
            "warmup": 1 if tel.get("warmup") else 0,
            # TCK-2231: RUN de LINHAGEM (ticket leve fechou pelo criteria gate,
            # sem execução). Ele DECLARA o que é; o agregador o exclui do
            # denominador de qualidade — como já faz com `flat-legacy` — e o
            # inclui na cobertura. O trabalho para de ser invisível sem inflar
            # `loop_quality` com runs que não exerceram o loop.
            "run_format": str(data.get("run_format") or "dir"),
        })
    # TCK-2080: RUN em formato PLANO (RUN-*.md, bootstraps antigos) — ~800
    # artefatos em 32 projetos não existiam para o índice. Entram com o que o
    # frontmatter realmente tem; campo ausente é None (terceiro estado), nunca
    # default — preencher seria fabricar evidência (a classe do ADR-0029).
    #
    # TCK-2168: DEDUP contra `runs.id TEXT PRIMARY KEY`. O 2º produtor nasceu
    # sem ele e o `INSERT` puro (não OR REPLACE) matava o build INTEIRO com
    # IntegrityError — medido em 2 projetos reais: `isenpcd` tem
    # `RUN-…-gemma-fallback/` e `RUN-…-gemma-fallback.md` (o .md declara
    # `run_id:`, então o fallback `md.stem` colide com o nome do dir), e
    # `atem-base-marketing` tem dois .md declarando `id: RUN-0016`.
    # O DIRETÓRIO vence: ele carrega run.json (contrato completo), o plano é
    # o legado. Colisão entre planos: o primeiro em ordem estável vence.
    vistos = {r["id"] for r in rows}
    for md in sorted(runs_dir.glob("RUN-*.md")):
        if not md.is_file():
            continue
        try:
            fm = parse_frontmatter_file(md) or {}
        except Exception:
            fm = {}
        def _join(v):
            if isinstance(v, list):
                return ", ".join(str(x) for x in v)
            return str(v) if v is not None else None
        rid = str(fm.get("id") or md.stem)
        if rid in vistos:
            # R3 do verify: descarte silencioso vira descarte DECLARADO. O
            # .md segue no corpus BM25 (retrieval_docs), só a linha de `runs`
            # é do vencedor — mas quem lê o índice merece saber que houve
            # colisão, não descobrir por ausência.
            print(f"    [aviso] RUN duplicado ignorado: {md.name} "
                  f"(id={rid} já indexado)", file=sys.stderr)
            continue  # TCK-2168: dedup — nunca deixe o INSERT explodir
        vistos.add(rid)
        rows.append({
            "id": rid,
            "ticket": _join(fm.get("ticket") or fm.get("tickets")) or "",
            "design": _join(fm.get("design") or fm.get("designs")) or "",
            "status": str(fm["status"]) if fm.get("status") is not None else None,
            "started_at": fm.get("started_at") or fm.get("start_time") or None,
            "ended_at": (fm.get("ended_at") or fm.get("finished_at")
                         or fm.get("end_time") or None),
            "result": fm.get("result") or None,
            "iterations": None,
            "environment": fm.get("environment") or None,
            "mode": fm.get("mode") or None,
            "loop_iterations": None,
            "lessons_consulted": json.dumps([]),
            "loop_cost_usd": None,
            "loop_strategy": None,
            "context_peak": None,
            "final_judge_delta": None,
            "final_judge_delta_source": "",
            "attempt_count": None,
            "warmup": 0,
            "run_format": "flat-legacy",
        })
    return rows


def _read_verifies(ver_dir: Path) -> list[dict]:
    """Lê VER-*.md → frontmatter → list[dict].

    Alguns VERs cobrem múltiplos tickets/runs (batch/epic) — campos vêm como
    listas. Normaliza para string (primeiro item ou join).
    """
    rows = []
    if not ver_dir.exists():
        return rows
    for md in sorted(ver_dir.glob("VER-*.md")):
        fm = parse_frontmatter(_read_text_cached(md)[:2000])
        if not fm.get("id"):
            continue

        def _str(val: object) -> str:
            if isinstance(val, list):
                return ", ".join(str(v) for v in val)
            return str(val) if val is not None else ""

        rows.append({
            "id": _str(fm.get("id")),
            "run": _str(fm.get("run")),
            "ticket": _str(fm.get("ticket")),
            "design": _str(fm.get("design")),
            "verdict": _str(fm.get("verdict")),
            "verified_at": _str(fm.get("verified_at")),
            "verifier": _str(fm.get("verifier")),
        })
    return rows


def _read_learning_records(memory_dir: Path) -> list[dict]:
    """Lê 99-memory/learnings/LRN-*.md → frontmatter + Recommendation → list[dict].

    TCK-0397: close the data pipeline — LRNs were being written by /ops-learn but
    never ingested into the SQLite lessons table, so consult_lessons() always
    returned [] and loop_health stayed at the neutral 50% baseline.

    Fail-open: malformed files are skipped with no exception; the rest of the
    index still builds. Frontmatter fields are best-effort (id falls back to
    the filename stem; linked_ticket defaults to "").
    """
    learn_dir = memory_dir / "learnings"
    if not learn_dir.exists():
        return []

    def _extract_recommendation(body: str) -> str:
        """Extract the text of the first Recommendation / Recomendação section."""
        import re
        m = re.search(
            r"^##\s+(?:Recommendation|Recomendação|Recomendacao)\s*\n+(.*?)(?=^##\s|\Z)",
            body,
            re.MULTILINE | re.DOTALL | re.IGNORECASE,
        )
        if not m:
            return ""
        text = m.group(1).strip()
        # Strip leading "- Ação proposta:" bullet prefix if present (Portuguese template)
        text = re.sub(r"^[-*]\s*(?:Ação proposta|Acao proposta):\s*", "", text, flags=re.IGNORECASE)
        return text

    rows: list[dict] = []
    for md in sorted(learn_dir.glob("LRN-*.md")):
        try:
            raw = _read_text_cached(md)
        except OSError:
            continue
        fm = parse_frontmatter(raw)
        # Split body (everything after the closing --- of frontmatter)
        body = raw
        if raw.startswith("---"):
            end = raw.find("\n---", 3)
            if end != -1:
                body = raw[end + 4:]

        lesson_text = _extract_recommendation(body)
        if not lesson_text:
            # Fallback: use the first non-empty paragraph after the H1 title.
            for para in body.split("\n\n"):
                stripped = para.strip()
                if stripped and not stripped.startswith("#"):
                    lesson_text = stripped
                    break
        if not lesson_text.strip():
            continue

        lid = fm.get("id") or md.stem
        ticket = fm.get("linked_ticket") or fm.get("ticket") or ""
        if isinstance(ticket, list):
            ticket = ", ".join(str(t) for t in ticket)
        ticket = str(ticket)

        rows.append({
            "ticket": ticket,
            "severity": str(fm.get("severity", fm.get("category", "medium"))),
            "lesson": lesson_text,
            "affected_tickets": ticket,
            "created_at": str(fm.get("created_at", "")),
            "source_verdict": str(lid),
        })
    return rows


def _read_lessons(memory_dir: Path) -> list[dict]:
    """Lê 99-memory/verdicts/*.json → extrai lições → list[dict].

    Cada verdict JSON tem campo `lessons: []` e `ticket`.
    Lições sem texto são puladas.
    """
    rows = []
    verdicts_dir = memory_dir / "verdicts"
    # SPC-0032/F0.2: do NOT early-return when verdicts/ is absent — lessons.json
    # (ingested below) may still exist as the canonical source.
    lesson_id = 0
    for vf in (sorted(verdicts_dir.glob("*.json")) if verdicts_dir.exists() else []):
        try:
            data = read_json_cached(vf)
        except (json.JSONDecodeError, OSError):
            continue

        ticket = data.get("ticket", "")
        timestamp = data.get("timestamp", "")
        source_verdict = vf.stem
        lessons = data.get("lessons", [])

        # Se não há lessons array, tenta extrair de what_went_wrong + root_causes
        if not lessons:
            for ww in data.get("what_went_wrong", []):
                lesson_id += 1
                rows.append({
                    "ticket": ticket,
                    "severity": "medium",
                    "lesson": ww,
                    "affected_tickets": ticket,
                    "created_at": timestamp,
                    "source_verdict": source_verdict,
                })
            for rc in data.get("root_causes", []):
                lesson_id += 1
                rows.append({
                    "ticket": ticket,
                    "severity": "low",
                    "lesson": rc,
                    "affected_tickets": ticket,
                    "created_at": timestamp,
                    "source_verdict": source_verdict,
                })
            continue

        for lesson in lessons:
            if isinstance(lesson, dict):
                lesson_text = lesson.get("lesson") or lesson.get("text") or str(lesson)
                severity = lesson.get("severity", "medium")
                affected = lesson.get("affected_tickets", ticket)
            elif isinstance(lesson, str):
                lesson_text = lesson
                severity = "medium"
                affected = ticket
            else:
                continue
            if not lesson_text.strip():
                continue
            lesson_id += 1
            rows.append({
                "ticket": ticket,
                "severity": severity,
                "lesson": lesson_text,
                "affected_tickets": affected,
                "created_at": timestamp,
                "source_verdict": source_verdict,
            })

    # SPC-0032/F0.2 (F4): also ingest the canonical 99-memory/lessons/lessons.json
    # (previously orphaned — written by add_lesson but never indexed).
    lessons_file = memory_dir / "lessons" / "lessons.json"
    if lessons_file.exists():
        try:
            entries = read_json_cached(lessons_file)
            if not isinstance(entries, list):
                entries = []
        except (json.JSONDecodeError, OSError):
            entries = []  # quarantine a truncated source instead of aborting
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            text = (entry.get("lesson") or "").strip()
            if not text:
                continue
            affected = entry.get("affected_tickets") or []
            primary = affected[0] if affected else ""
            rows.append({
                "ticket": primary,
                "severity": entry.get("severity", "medium"),
                "lesson": text,
                "affected_tickets": ", ".join(str(a) for a in affected) if isinstance(affected, list) else str(affected),
                "created_at": entry.get("timestamp", ""),
                "source_verdict": "lessons.json",
            })

    # TCK-0397: also ingest 99-memory/learnings/LRN-*.md (learning records
    # emitted by /ops-learn). Without this, lessons.json rarely exists in
    # practice and the SQLite lessons table stays empty → consult_lessons()
    # returns [] → loop_health stuck at 50% baseline.
    rows.extend(_read_learning_records(memory_dir))

    # SPC-0032/F0.2: dedup by stable lesson_id across BOTH sources so a lesson
    # present in lessons.json AND a verdicts/*.json is projected exactly once.
    deduped: list[dict] = []
    seen: set[str] = set()
    for r in rows:
        # TCK-1137 / DES-0660 (FND-0089): blind-era boilerplate must never
        # (re)enter the lessons table on rebuild. Uses the SAME matcher as the
        # write path (lib.db.add_lesson quarantine) so ingestion and write-time
        # agree on what is noise — historical verdicts/*.json still carry these
        # strings in lessons/what_went_wrong/root_causes.
        if _matches_noise_pattern(str(r.get("lesson", ""))):
            continue
        lid = lesson_identity(r.get("ticket"), r.get("lesson", ""))
        if lid in seen:
            continue
        seen.add(lid)
        deduped.append(r)
    return deduped


# TCK-1140/DES-0749 (FND-0093): unified FTS corpus — active + archived tickets,
# body content included (not just title+slug). Cap = first 2KB of body/doc:
# full bodies (12KB cap, BM25 parity) grew .index.db 7.6x (360KB→2.8MB) on the
# real corpus — over the DES-0749 5x budget. The 2KB cap lands at 2.5MB (6.9x),
# dominated by the 701 archived rows themselves (title+slug-only unified FTS ≈
# 0.39MB) — still 9x smaller than the 23MB bm25_index.json it replaces
# (SPC-0026). Terms beyond the cap stay invisible (same fail-closed trade-off
# BM25 makes at 12KB).
_FTS_BODY_MAX_BYTES = 2 * 1024


def _cap_fts_body(text: str, max_bytes: int = _FTS_BODY_MAX_BYTES) -> str:
    """Trunca ao teto em bytes (utf-8 safe) — mesmo bound do scanner BM25."""
    encoded = text.encode("utf-8")
    if len(encoded) <= max_bytes:
        return text
    return encoded[:max_bytes].decode("utf-8", errors="ignore")


def _read_ticket_fts_rows(p: paths) -> list[tuple[str, str, str]]:
    """(ticket_id, title, body) para tickets_fts — ATIVOS + ARQUIVADOS, com body.

    TCK-1140/DES-0749 (FND-0093): antes o FTS indexava só title+slug dos
    tickets ativos (~29), cego aos ~701 arquivados e a qualquer termo fora de
    title/slug. Aqui o corpus passa a cobrir os dois dirs e o corpo do ticket
    (frontmatter strippado, primeiros 2KB — ver _FTS_BODY_MAX_BYTES). A tabela
    relacional `tickets` NÃO muda (permanece active-only) — o FTS é standalone,
    então visibilidade de busca vive inteira em tickets_fts.

    Arquivado primeiro, ativo por último: em colisão de id, o ATIVO vence
    (dict sobrescreve). Arquivos sem `id` no frontmatter são pulados (mesma
    regra de _read_tickets).
    """
    def _str(val: object) -> str:
        if isinstance(val, list):
            return ", ".join(str(v) for v in val)
        return str(val) if val is not None else ""

    rows: dict[str, tuple[str, str, str]] = {}
    for base in (archived_tickets(p.root), p.tickets):
        if not base.exists():
            continue
        for md in sorted(base.glob("TCK-*.md")):
            try:
                raw = _read_text_cached(md)
            except OSError:
                continue
            fm = parse_frontmatter(raw)
            tid = _str(fm.get("id"))
            if not tid:
                continue
            title = _str(fm.get("title"))
            slug = _str(fm.get("slug"))
            body = FRONTMATTER_RE.sub("", raw, count=1)
            content = _cap_fts_body(f"{title} {slug} {body}")
            rows[tid] = (tid, title, content)
    return [rows[tid] for tid in sorted(rows)]


# ---------------------------------------------------------------------------
# BM25 retrieval store (TCK-1188/DES-0760, PLN-0017 S2)
# ---------------------------------------------------------------------------

def _load_context_query_module():
    """Carrega scripts/state/context-query.py (hífen no nome — importlib).

    O tokenizer/scanner BM25 (tokenize, scan_files, _read_and_tokenize,
    index_mtime) tem DONO: context-query. Reusar daqui garante que os tokens
    persistidos no SQLite são BIT-A-BIT os mesmos que o query time usaria —
    paridade de ranking por construção, não por convenção."""
    import importlib.util
    cq_path = SCRIPTS_DIR / "state" / "context-query.py"
    spec = importlib.util.spec_from_file_location(
        "codebase_ops_context_query_for_index", cq_path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {cq_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read_retrieval_doc_rows(p: paths) -> tuple[list[tuple[str, str, int]], float]:
    """(path, tokens space-joined, doc_len) + max mtime do corpus .md.

    Mesmo corpus do BM25 clássico: .archagents/**/*.md com as exclusões de
    context-query.scan_files (snapshots exportados etc.) e o cap de 12KB/doc
    de _read_and_tokenize (truncamento grita DEGRADED lá dentro)."""
    from concurrent.futures import ThreadPoolExecutor
    cq = _load_context_query_module()
    corpus = cq.scan_files(root=str(p.archagents))
    rows: list[tuple[str, str, int]] = []
    with ThreadPoolExecutor(max_workers=cq.NUM_WORKERS) as exe:
        for result in exe.map(cq._read_and_tokenize, corpus):
            if result is None:
                continue
            path, tokens = result
            rows.append((path, " ".join(tokens), len(tokens)))
    return rows, cq.index_mtime(corpus)


# ---------------------------------------------------------------------------
# Builder
# ---------------------------------------------------------------------------

def _dedup_por_chave(linhas: list[dict], tabela: str, chave: str = "id") -> list[dict]:
    """TCK-2174: dedup no PONTO DE INSERÇÃO — toda tabela com chave vinda de
    arquivo, não só `runs`.

    Achado no teste de fogo pós-merge do TCK-2168: consertei `runs` e o
    consumidor `atem-base-marketing` continuou morrendo, agora em
    `tickets.id` — dois tickets DIFERENTES (compliance-por-referencia e
    persistencia-dominio) reivindicando `TCK-0078`. Provado PREEXISTENTE por
    contraste com o código pré-drain: o índice daquele projeto nunca foi
    construível, e ninguém sabia porque o erro morria no terminal de quem
    rodava o build.

    Descarta declarando (nunca em silêncio) — quem lê o índice precisa saber
    que dois artefatos disputam um id; é sintoma de numeração quebrada, que o
    `check-duplicate-ids` persegue em outro eixo. `INSERT OR REPLACE` seria a
    saída errada: silencia a colisão e o vencedor vira acidente de ordenação.
    """
    vistos: set = set()
    limpas = []
    for linha in linhas:
        k = linha.get(chave)
        if k in vistos:
            print(f"    [aviso] {tabela}: id duplicado ignorado — {k!r} "
                  f"(dois artefatos disputam o mesmo id)", file=sys.stderr)
            continue
        vistos.add(k)
        limpas.append(linha)
    return limpas


def _status_reconciliado(run_dir, data: dict) -> str:
    """Status efetivo do run (TCK-2477). Fail-open: na dúvida, o cru."""
    try:
        from lib.runstate import effective_run_status
        return str(effective_run_status(run_dir).get("status") or data.get("status", ""))
    except Exception:  # noqa: BLE001 — índice nunca quebra por reconciliação
        return str(data.get("status", ""))


def _populate(conn: sqlite3.Connection, p: paths) -> dict[str, int]:
    """Popula todas as tabelas. Retorna contagens."""
    conn.executescript(SCHEMA)

    # Limpa tabelas (rebuild completo)
    for table in ("tickets", "runs", "verifies", "lessons", "retrieval_docs"):
        conn.execute(f"DELETE FROM {table}")

    # Tickets
    tickets = _dedup_por_chave(_read_tickets(p.tickets), "tickets")
    conn.executemany(
        """INSERT INTO tickets (id, slug, title, status, priority, kind, effort, source, linked_spec, created_at, done_at)
           VALUES (:id, :slug, :title, :status, :priority, :kind, :effort, :source, :linked_spec, :created_at, :done_at)""",
        tickets,
    )

    # SPC-0026/TCK-0201 + TCK-1140/DES-0749 (FND-0093): populate FTS5 index.
    # Unified corpus: active + archived tickets, title+slug+body (2KB cap/doc).
    # Rebuild FTS from scratch (DELETE + INSERT all rows).
    conn.execute("DELETE FROM tickets_fts")
    for ticket_id, title, body in _read_ticket_fts_rows(p):
        conn.execute(
            "INSERT INTO tickets_fts (ticket_id, title, body) VALUES (?, ?, ?)",
            (ticket_id, title, body),
        )

    # TCK-1188/DES-0760 (PLN-0017 S2): BM25 retrieval store — corpus .md
    # tokenizado persistido no SQLite (aposenta bm25_index.json). Query time
    # (context-query) lê estas rows e recompõe o BM25Index em memória.
    retrieval_rows, retrieval_mtime = _read_retrieval_doc_rows(p)
    conn.executemany(
        "INSERT INTO retrieval_docs (path, tokens, doc_len) VALUES (?, ?, ?)",
        retrieval_rows,
    )
    conn.execute(
        "INSERT OR REPLACE INTO meta (key, value) VALUES ('retrieval_mtime', ?)",
        (repr(retrieval_mtime),),
    )

    # Runs
    runs = _dedup_por_chave(_read_runs(p.runs), "runs")
    conn.executemany(
        """INSERT INTO runs (id, ticket, design, status, started_at, ended_at, result, iterations, environment, mode,
                             loop_iterations, lessons_consulted, loop_cost_usd, loop_strategy, context_peak, final_judge_delta,
                             final_judge_delta_source, attempt_count, warmup, run_format)
           VALUES (:id, :ticket, :design, :status, :started_at, :ended_at, :result, :iterations, :environment, :mode,
                   :loop_iterations, :lessons_consulted, :loop_cost_usd, :loop_strategy, :context_peak, :final_judge_delta,
                   :final_judge_delta_source, :attempt_count, :warmup, :run_format)""",
        runs,
    )

    # Verifies
    verifies = _dedup_por_chave(_read_verifies(p.verify_reports), "verifies")
    conn.executemany(
        """INSERT INTO verifies (id, run, ticket, design, verdict, verified_at, verifier)
           VALUES (:id, :run, :ticket, :design, :verdict, :verified_at, :verifier)""",
        verifies,
    )

    # Lessons
    lessons = _read_lessons(p.archagents / "99-memory")
    # TCK-0747-lessons-list: coerce list fields for SQLite TEXT binding
    for _row in lessons:
        aff = _row.get("affected_tickets")
        if isinstance(aff, (list, tuple)):
            _row["affected_tickets"] = ",".join(str(x) for x in aff)
        elif aff is None:
            _row["affected_tickets"] = ""
        else:
            _row["affected_tickets"] = str(aff)
    conn.executemany(
        """INSERT INTO lessons (ticket, severity, lesson, affected_tickets, created_at, source_verdict)
           VALUES (:ticket, :severity, :lesson, :affected_tickets, :created_at, :source_verdict)""",
        lessons,
    )

    # PLN-0012 / TCK-0832: deterministic knowledge graph (frontmatter + facts).
    from lib.knowledge_graph import rebuild_graph
    kg = rebuild_graph(conn, p.root)

    # SPC-0034/F0.4: stamp the schema version so get_db/check can detect a stale
    # schema (additive DDL) and force a rebuild instead of querying the old shape.
    conn.execute(
        "INSERT OR REPLACE INTO meta (key, value) VALUES ('schema_version', ?)",
        (str(INDEX_SCHEMA_VERSION),),
    )

    conn.commit()
    return {
        "tickets": len(tickets),
        "runs": len(runs),
        "verifies": len(verifies),
        "lessons": len(lessons),
        "retrieval_docs": len(retrieval_rows),
        "kg_nodes": kg.get("nodes", 0),
        "kg_edges": kg.get("edges", 0),
    }


# Um build honesto termina em segundos; uma hora é folga larga o bastante para
# que nenhum concorrente vivo seja confundido com resíduo.
IDADE_MINIMA_ORFAO_S = 3600


def _limpar_temp(tmp: Path) -> None:
    """Remove o temp E seus sidecars WAL (TCK-2245).

    `PRAGMA journal_mode=WAL` cria `-wal`/`-shm` ao lado do arquivo. A limpeza
    antiga removia só o `.db` e deixava os dois irmãos para trás — resíduo
    parcial é o pior dos dois mundos: some o dado e fica o lixo."""
    for p in (tmp, Path(str(tmp) + "-wal"), Path(str(tmp) + "-shm")):
        try:
            p.unlink(missing_ok=True)
        except OSError:
            pass


def _varrer_orfaos(diretorio: Path, exceto: Path | None = None) -> int:
    """Remove temporários de índice abandonados. Devolve quantos removeu.

    É função nomeada, e não código solto dentro de `build`, porque o teste
    precisa exercitar ESTA lógica — um teste que reimplementa a varredura vira
    proxy e fica verde enquanto produção diverge.

    Duas armadilhas cobertas aqui:
    - `_limpar_temp` apaga os sidecars `-wal`/`-shm`, que TAMBÉM estão no glob;
      o iterador fica com entradas já removidas e o `stat` levanta. Por isso o
      `try` por item, e não em volta do laço.
    - só varre por IDADE: temp recente é de build vivo (ver IDADE_MINIMA_ORFAO_S).
    """
    removidos = 0
    limite = time.time() - IDADE_MINIMA_ORFAO_S
    try:
        candidatos = list(diretorio.glob(".index.tmp.*"))
    except OSError:
        return 0
    for orfao in candidatos:
        if exceto is not None and orfao == exceto:
            continue
        try:
            if orfao.stat().st_mtime < limite:
                _limpar_temp(orfao)
                removidos += 1
        except OSError:
            continue      # já foi (sidecar do irmão) ou sumiu no meio
    return removidos


def build(root: str | Path | None = None) -> dict[str, int]:
    """Rebuild completo: escreve em temp + rename atômico (crash-safe)."""
    p = paths(root)
    db_path = index_path(root)

    # Write to temp file, then atomic rename
    fd, tmp_path = tempfile.mkstemp(
        suffix=".db", dir=str(db_path.parent), prefix=".index.tmp."
    )
    os.close(fd)
    tmp = Path(tmp_path)

    try:
        conn = sqlite3.connect(str(tmp))
        # TCK-1136/DES-0745 (FND-0088): WAL é setado SÓ AQUI, em build time —
        # journal_mode persiste no header do arquivo, então o índice entregue já
        # nasce WAL e o modo é ESTÁVEL. Readers (lib.db.get_db) NUNCA flipam o
        # modo por conexão: o flip antigo reescrevia o header sem escrever dado,
        # avançando o mtime do índice e envenenando o detector de staleness.
        conn.execute("PRAGMA journal_mode=WAL")
        counts = _populate(conn, p)
        # Flush do -wal para o arquivo principal ANTES do rename atômico — o
        # índice vivo deve ser single-file completo (sem sidecar -wal órfão).
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        conn.close()

        # Atomic rename (POSIX)
        tmp.replace(db_path)
    except Exception:
        _limpar_temp(tmp)
        raise

    # TCK-2245: varre temporários órfãos de builds mortos ANTES do except (OOM,
    # kill -9), que a limpeza acima nunca alcança. Eles ficavam untracked em
    # .archagents/ e — medido em fixture — faziam o guarda anti-clobber do
    # restore-snapshot.sh abortar TODO restore com rc 2. O .gitignore passou a
    # cobri-los; isto tira do disco.
    #
    # SÓ por IDADE. A v1 apagava todo `.index.tmp.*` do diretório, e não há lock
    # em `rebuild_index_if_stale` (chamado de reflect.py, db.get_db,
    # context-query, update-meta): a verificação adversarial mediu 4 builds
    # concorrentes e 1 morreu com FileNotFoundError porque o irmão apagou seu
    # temp antes do rename. Trocar um resíduo cosmético por uma corrida é
    # péssimo negócio — nenhum build honesto leva uma hora.
    _varrer_orfaos(db_path.parent, exceto=tmp)

    return counts


def check(root: str | Path | None = None) -> bool:
    """Verifica se o índice está atualizado vs filesystem.

    Compara contagens: se o número de tickets/runs/verifies/lessons no SQLite
    difere do filesystem, há drift.
    """
    p = paths(root)
    db_path = index_path(root)

    if not db_path.exists():
        return False

    # SPC-0034/F0.4: a stale schema version (or a legacy index with no meta
    # table = version 0) is drift even if row counts match — queries would hit
    # the old shape. This is the exact F10 trap a count-only check misses.
    if read_schema_version(db_path) != INDEX_SCHEMA_VERSION:
        return False

    conn = sqlite3.connect(str(db_path))
    try:
        # Conta no SQLite
        db_tickets = conn.execute("SELECT COUNT(*) FROM tickets").fetchone()[0]
        db_runs = conn.execute("SELECT COUNT(*) FROM runs").fetchone()[0]
        db_verifies = conn.execute("SELECT COUNT(*) FROM verifies").fetchone()[0]
        db_lessons = conn.execute("SELECT COUNT(*) FROM lessons").fetchone()[0]
    except sqlite3.OperationalError:
        conn.close()
        return False
    conn.close()

    # Conta no filesystem (mesma lógica dos readers: só conta se tiver id)
    import re
    fm_re = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
    # TCK-2174 (lição R1 do verify do TCK-2168, aplicada de novo): o check
    # conta ids ÚNICOS porque `_populate` DEDUPA. Contar arquivos deixava
    # `fs=87` contra `db=86` no atem-base-marketing (dois TCK-0078) — DRIFT
    # eterno e rebuild a cada invocação, o mesmo loop que o TCK-2168 fechou
    # para runs. Sensor que não conta a mesma população do produtor é sensor
    # saturado, e eu reintroduzi isso ao consertar outra tabela.
    fs_ticket_ids: set[str] = set()
    for md in p.tickets.glob("TCK-*.md"):
        fm = parse_frontmatter(md.read_text(encoding="utf-8"))
        if fm.get("id"):
            fs_ticket_ids.add(str(fm["id"]))
    fs_tickets = len(fs_ticket_ids)

    # TCK-2168: o check tem de contar a MESMA população que `_populate`
    # insere — senão `db_runs > fs_runs` sempre, o índice nasce DRIFT logo
    # após o rebuild e `rebuild_index_if_stale` reconstrói o corpus a cada
    # invocação, para sempre. Medido em 3 projetos (trello 0→56, uab 3→98,
    # elearning 4→49): OK antes do drain, DRIFT depois. Sensor saturado é
    # sensor morto — e este é o mesmo dedup do produtor, pela mesma razão.
    fs_run_ids: set[str] = set()
    if p.runs.exists():
        for rj in p.runs.glob("RUN-*/run.json"):
            try:
                # R1 do verify do TCK-2168: o produtor usa
                # `data.get("id", run_dir.name)` — usar `parent.name` aqui
                # criava assimetria NOVA (medido: 8 dirs no acervo declaram id
                # != nome do dir). Sem `.md` homônimo hoje, mas é o mesmo loop
                # de DRIFT eterno esperando um. O comentário anterior ("reader
                # usa dir.name") era factualmente falso.
                dados = json.loads(rj.read_text(encoding="utf-8"))
                fs_run_ids.add(str(dados.get("id") or rj.parent.name))
            except (json.JSONDecodeError, OSError):
                pass
        for md in p.runs.glob("RUN-*.md"):
            if not md.is_file():
                continue
            try:
                fm_run = parse_frontmatter(_read_text_cached(md)[:2000])
            except Exception:
                fm_run = {}
            fs_run_ids.add(str((fm_run or {}).get("id") or md.stem))
    fs_runs = len(fs_run_ids)

    fs_verify_ids: set[str] = set()   # TCK-2174: idem tickets — ids únicos
    if p.verify_reports.exists():
        for md in p.verify_reports.glob("VER-*.md"):
            fm = parse_frontmatter(_read_text_cached(md)[:2000])
            if fm.get("id"):
                fs_verify_ids.add(str(fm["id"]))
    fs_verifies = len(fs_verify_ids)

    # SPC-0032/F0.2: count via the same reader (verdicts + lessons.json, deduped)
    # so check() stays consistent with what _populate inserts (no false drift).
    fs_lessons = len(_read_lessons(p.archagents / "99-memory"))

    return (db_tickets == fs_tickets
            and db_runs == fs_runs
            and db_verifies == fs_verifies
            and db_lessons == fs_lessons)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Indexer SQLite para .archagents/ (SPC-0026)"
    )
    parser.add_argument("--root", default=None, help="Raiz do projeto (default: cwd)")
    parser.add_argument("--check", action="store_true", help="Verifica se índice está atualizado")
    parser.add_argument("--incremental", action="store_true", help="Atualiza só modificados (alias para rebuild por agora)")
    args = parser.parse_args()

    if args.check:
        if check(args.root):
            print("OK: index up to date")
            return 0
        else:
            print("DRIFT: index out of date — run build-index.py to rebuild")
            return 1

    counts = build(args.root)
    kg_bit = ""
    if counts.get("kg_nodes"):
        kg_bit = f", kg={counts['kg_nodes']}n/{counts.get('kg_edges', 0)}e"
    print(
        f"Built .index.db: {counts['tickets']} tickets, {counts['runs']} runs, "
        f"{counts['verifies']} verifies, {counts['lessons']} lessons, "
        f"{counts.get('retrieval_docs', 0)} retrieval-docs{kg_bit}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
