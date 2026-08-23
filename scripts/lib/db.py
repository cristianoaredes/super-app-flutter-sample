#!/usr/bin/env python3
"""db.py — SQLite derived index for .archagents/ (SPC-0026, TCK-0197).

Projeção derivada dos artefatos canônicos (MD+YAML, JSON) em SQLite single-file.
MD permanece source of truth; SQLite é índice regenerável (.gitignore).

Schema:
  - tickets:  projeção do frontmatter de TCK-*.md
  - runs:     projeção dos run.json
  - verifies: projeção do frontmatter de VER-*.md
  - lessons:  projeção das lições extraídas de 99-memory/verdicts/*.json

Uso:
  from lib.db import get_db, query_tickets, query_runs, query_lessons, get_stats
  db = get_db(root)  # auto-build se .index.db ausente
  ready = query_tickets(db, status="ready")
"""

from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# FND-0059: consolidated bootstrap via lib.bootstrap (was per-module inline).
# FND-6005 / TCK-0388: NO module-level ensure_scripts_on_path() — importing
# lib.db must not mutate sys.path. Bootstrap is handled by pyproject.toml
# pythonpath (pytest), direct CLI (scripts/ is sys.path[0]), or ops/
# scripts (which bootstrap themselves via ensure_scripts_on_path_from).

from lib.frontmatter import parse_frontmatter
from lib.paths import paths

import importlib.util as _ilu
fcntl = __import__("fcntl") if _ilu.find_spec("fcntl") else None  # POSIX-only; None elsewhere (F0.7-T2)


# ---------------------------------------------------------------------------
# Schema DDL
# ---------------------------------------------------------------------------

# SPC-0034/F0.4: explicit index schema version. Additive DDL changes (new columns)
# must bump this so a live .index.db built against an older schema is rebuilt
# instead of being queried with a stale shape. A pre-existing index with NO meta
# table is treated as version 0 (legacy) and forces a full rebuild.
# v2 = loop-telemetry columns on runs + meta(schema_version) table.
# v3 = knowledge-graph tables kg_nodes / kg_edges (PLN-0012 / TCK-0832).
# v4 = retrieval_docs table (TCK-1188/DES-0760, PLN-0017 S2): BM25 corpus
#      tokenizado vive no SQLite — aposenta o cache paralelo bm25_index.json.
# v5 = runs.final_judge_delta_source (TCK-2027/DES-1025): a procedência do
#      delta viaja com o valor. Bump obrigatório — um índice v4 devolve o delta
#      sem procedência, e o filtro de procedência barraria todos os runs.
INDEX_SCHEMA_VERSION = 7  # TCK-2080: runs.run_format (dir vs flat-legacy — ~800 planos invisíveis)

SCHEMA = """
CREATE TABLE IF NOT EXISTS tickets (
    id          TEXT PRIMARY KEY,
    slug        TEXT,
    title       TEXT,
    status      TEXT,
    priority    TEXT,
    kind        TEXT,
    effort      TEXT,
    source      TEXT,
    linked_spec TEXT,
    created_at  TEXT,
    done_at     TEXT
);

CREATE TABLE IF NOT EXISTS runs (
    id          TEXT PRIMARY KEY,
    ticket      TEXT,
    design      TEXT,
    status      TEXT,
    started_at  TEXT,
    ended_at    TEXT,
    result      TEXT,
    iterations  INTEGER,
    environment TEXT,
    mode        TEXT,
    -- SPC-0034/F0.4: loop-telemetry contract = LOOP_TELEMETRY_FIELDS in runstate.py.
    -- `iterations` kept for back-compat; loop_iterations is the canonical copy.
    -- lessons_consulted is a JSON-encoded list: json.dumps on write / loads on read.
    loop_iterations   INTEGER,
    lessons_consulted TEXT,
    loop_cost_usd     REAL,
    loop_strategy     TEXT,
    context_peak      INTEGER,
    final_judge_delta REAL,
    -- TCK-2027: procedência do delta ("judge"/"orchestrator"/"escalation" =
    -- medição; "criteria-proxy" = derivado do veredito). Sem esta coluna o
    -- número chegava ao consumidor sem dizer de onde veio.
    final_judge_delta_source TEXT,
    -- TCK-2080: "dir" (moderno, run.json) vs "flat-legacy" (RUN-*.md plano de
    -- bootstraps antigos). ~800 planos em 32 projetos NÃO EXISTIAM para o
    -- índice; agora entram com o que realmente têm (ausente = NULL, nunca
    -- default fabricado) e ficam distinguíveis na consulta.
    run_format  TEXT,
    -- TCK-2090: o predicado de stall/retry lê attempt_count; sem a coluna, o
    -- caminho SQLite hidratava ausência e respondia 0.0 para sempre — enquanto
    -- o glob respondia outro número. Campo perdido no transporte, de novo
    -- (mesma classe do TCK-2027).
    attempt_count    INTEGER,
    warmup           INTEGER DEFAULT 0  -- TCK-0747: 1=synthetic warm-up
);

-- SPC-0034/F0.4: index schema-version sidecar. build-index writes
-- key='schema_version' so get_db / build-index.check can detect a stale
-- schema (additive DDL) and force a rebuild instead of querying it.
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS verifies (
    id          TEXT PRIMARY KEY,
    run         TEXT,
    ticket      TEXT,
    design      TEXT,
    verdict     TEXT,
    verified_at TEXT,
    verifier    TEXT
);

CREATE TABLE IF NOT EXISTS lessons (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket           TEXT,
    severity         TEXT,
    lesson           TEXT,
    affected_tickets TEXT,
    created_at       TEXT,
    source_verdict   TEXT
);

-- SPC-0026/TCK-0201: FTS5 virtual table for full-text search (substitui bm25_index.json)
-- Standalone FTS5 (não external content) — mais robusto e portável
CREATE VIRTUAL TABLE IF NOT EXISTS tickets_fts USING fts5(
    ticket_id UNINDEXED,
    title,
    body
);

-- TCK-1188/DES-0760 (PLN-0017 S2): BM25 retrieval store — corpus .md de
-- .archagents/ tokenizado (tokenizer do context-query: NFKD fold + stopwords),
-- persistido como tokens space-joined. Substitui o cache bm25_index.json:
-- query time lê daqui e recompõe o BM25Index em memória (paridade exata de
-- ranking — mesmos tokens, mesmo scorer). Frescor via meta(retrieval_mtime).
CREATE TABLE IF NOT EXISTS retrieval_docs (
    path    TEXT PRIMARY KEY,
    tokens  TEXT NOT NULL,
    doc_len INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tickets_status   ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_priority ON tickets(priority);
CREATE INDEX IF NOT EXISTS idx_runs_status      ON runs(status);
CREATE INDEX IF NOT EXISTS idx_runs_ticket      ON runs(ticket);
CREATE INDEX IF NOT EXISTS idx_verifies_ticket  ON verifies(ticket);
CREATE INDEX IF NOT EXISTS idx_lessons_ticket   ON lessons(ticket);
"""


def index_path(root: str | Path | None = None) -> Path:
    """Caminho canônico do SQLite derivado."""
    return paths(root).archagents / ".index.db"


class LessonStoreError(sqlite3.DatabaseError):
    """SPC-0032/F0.2 (F16): raised on TRUE index corruption so the lesson read
    path fails CLOSED (loud) instead of silently returning [] — a missing/
    rebuildable index stays silent (auto-build).

    TCK-1136/DES-0745: now subclasses ``sqlite3.DatabaseError`` so it doubles
    as the marked error for ALL wrapped query helpers (query_tickets/runs/
    verifies/get_stats) without breaking consumers that catch
    ``sqlite3.Error`` (e.g. lib/reflect_prune.py glob fallback) — they keep
    catching it, while ``except LessonStoreError`` / ``pytest.raises``
    contracts are unchanged. Consumers that don't catch (state/query.py)
    surface a clear corruption marker instead of a raw OperationalError."""


def _is_valid_sqlite(db_path: str | Path) -> bool:
    """True if db_path opens as a readable SQLite database (sqlite_master query
    succeeds). A garbage/truncated file returns False → treated as corruption."""
    try:
        conn = sqlite3.connect(str(db_path))
        try:
            conn.execute("SELECT count(*) FROM sqlite_master").fetchone()
        finally:
            conn.close()
        return True
    except sqlite3.Error:
        return False


def read_schema_version(db_path: str | Path) -> int:
    """Stored index schema version, or 0 (legacy/unreadable).

    A pre-existing index with NO meta table predates SPC-0034 and is treated as
    version 0 — forcing a full rebuild. Never raises (best-effort)."""
    try:
        conn = sqlite3.connect(str(db_path))
        try:
            row = conn.execute(
                "SELECT value FROM meta WHERE key='schema_version'"
            ).fetchone()
        finally:
            conn.close()
        return int(row[0]) if row and row[0] is not None else 0
    except (sqlite3.Error, ValueError, TypeError):
        return 0


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

def get_db(root: str | Path | None = None) -> sqlite3.Connection:
    """Abre .index.db; auto-build via build-index.py se ausente OU se o schema
    indexado está defasado (SPC-0034: meta.schema_version != INDEX_SCHEMA_VERSION,
    incl. o caso legado sem tabela meta = versão 0). Sem isso, DDL aditiva deixaria
    queries batendo num schema velho.

    TCK-1136/DES-0745: readers NEVER flip journal_mode — WAL é setado UMA vez
    pelo builder (state/build-index.py) para o modo ser estável. O flip
    per-connect antigo reescrevia o header do arquivo sem escrever dado,
    avançando o mtime do índice e envenenando o detector de staleness por
    mtime (FND-0088: "fresh" para sempre)."""
    db_path = index_path(root)
    rebuilt = False
    if not db_path.exists():
        _auto_build(root)  # missing -> rebuildable, stays silent (F16)
        rebuilt = True
    elif not _is_valid_sqlite(db_path):
        # F0.2/F16: a file that exists but is not valid SQLite is TRUE corruption.
        # Do NOT silently rebuild over it (that would mask the failure) — fail closed.
        raise LessonStoreError(f"corrupt index (not a valid SQLite db): {db_path}")
    elif read_schema_version(db_path) != INDEX_SCHEMA_VERSION:
        _auto_build(root)  # valid sqlite, stale schema -> rebuild (F0.4)
        rebuilt = True
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    # TCK-1136: busy_timeout explícito (5s) — o builder escreve num TEMP file e
    # renomeia, então o índice vivo quase nunca está lockado; isto é cinto-e-
    # suspensórios para writers externos. Connection-level: não toca o arquivo.
    conn.execute("PRAGMA busy_timeout=5000")
    conn.execute("PRAGMA foreign_keys=ON")
    if rebuilt:
        _integrity_check_fresh_build(conn, db_path)
    return conn


def _integrity_check_fresh_build(conn: sqlite3.Connection, db_path: Path) -> None:
    """TCK-1136/DES-0745 (FND-0097): cheap ``PRAGMA integrity_check`` — ONLY on
    the just-created/rebuilt open path. Per-connect cost on ordinary reads
    stays ~zero (102 pages is fast, but not free). A build that produces a
    corrupt file fails CLOSED here instead of poisoning every consumer."""
    try:
        row = conn.execute("PRAGMA integrity_check").fetchone()
    except sqlite3.Error as exc:
        conn.close()
        raise LessonStoreError(
            f"freshly built index failed integrity_check ({db_path}): {exc}"
        ) from exc
    if not row or row[0] != "ok":
        conn.close()
        raise LessonStoreError(
            f"freshly built index failed integrity_check ({db_path}): "
            f"{row[0] if row else 'no result'}")


def _auto_build(root: str | Path | None = None) -> None:
    """(Re)build via build-index.py quando o índice falta OU está defasado.

    O script vive COM o framework (irmão de lib/, em scripts/), enquanto `--root`
    aponta para o data root — que pode ser externo (target/tests), não só o repo
    onde o script reside. Antes, procurar o script sob <data-root>/scripts/ falhava
    para qualquer root externo (SPC-0034: o rebuild por mismatch de get_db nunca
    encontrava o script)."""
    script = Path(__file__).resolve().parent.parent / "build-index.py"
    if not script.exists():
        return
    target = paths(root).root
    # F0.2/F16: bound the auto-build so a hung indexer can't block the caller.
    subprocess.run(
        [sys.executable, str(script), "--root", str(target)],
        check=True,
        capture_output=True,
        timeout=120,
    )


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

def _rows_to_dicts(rows: list[sqlite3.Row]) -> list[dict[str, Any]]:
    return [dict(r) for r in rows]


def query_tickets(
    db: sqlite3.Connection,
    status: str | None = None,
    priority: str | None = None,
    kind: str | None = None,
) -> list[dict[str, Any]]:
    sql = "SELECT id, slug, title, status, priority, kind, effort, source, linked_spec, created_at, done_at FROM tickets WHERE 1=1"
    params: list[Any] = []
    if status:
        sql += " AND status = ?"
        params.append(status)
    if priority:
        sql += " AND priority = ?"
        params.append(priority)
    if kind:
        sql += " AND kind = ?"
        params.append(kind)
    sql += " ORDER BY id"
    try:
        return _rows_to_dicts(db.execute(sql, params).fetchall())
    except sqlite3.DatabaseError as exc:
        # TCK-1136/DES-0745: same fail-closed envelope as query_lessons —
        # OperationalError ⊂ DatabaseError. Corrupção NUNCA vira lista vazia.
        raise LessonStoreError(f"ticket query failed (corrupt index?): {exc}") from exc


def query_runs(
    db: sqlite3.Connection,
    status: str | None = None,
    ticket: str | None = None,
    stale: bool = False,
    stale_hours: int = 24,
) -> list[dict[str, Any]]:
    sql = (
        "SELECT id, ticket, design, status, started_at, ended_at, result, iterations, "
        "environment, mode, loop_iterations, lessons_consulted, loop_cost_usd, "
        "loop_strategy, context_peak, final_judge_delta, final_judge_delta_source "
        "FROM runs WHERE 1=1"
    )
    params: list[Any] = []
    if status:
        sql += " AND status = ?"
        params.append(status)
    if ticket:
        sql += " AND ticket = ?"
        params.append(ticket)
    if stale:
        from datetime import datetime, timedelta, timezone
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=stale_hours)).isoformat()
        sql += " AND status = 'running' AND started_at < ?"
        params.append(cutoff)
    sql += " ORDER BY started_at DESC"
    try:
        rows = _rows_to_dicts(db.execute(sql, params).fetchall())
    except sqlite3.DatabaseError as exc:
        # TCK-1136/DES-0745: fail-closed envelope (vide query_lessons).
        raise LessonStoreError(f"run query failed (corrupt index?): {exc}") from exc
    return [_decode_lessons(r) for r in rows]


def _decode_lessons(row: dict[str, Any]) -> dict[str, Any]:
    """SPC-0034/F0.4: lessons_consulted is TEXT/JSON in SQLite → list on read."""
    lc = row.get("lessons_consulted")
    if isinstance(lc, str):
        try:
            row["lessons_consulted"] = json.loads(lc)
        except (json.JSONDecodeError, TypeError):
            row["lessons_consulted"] = []
    # TCK-0747: SQLite INTEGER → bool for lesson_utility filter
    if "warmup" in row:
        row["warmup"] = bool(row["warmup"])
    return row


def query_loop_health(db: sqlite3.Connection) -> dict[str, Any]:
    """SPC-0034/F0.4: loop health from the SQLite index.

    DESIGN: HYDRATES per-run rows from SQLite and REUSES
    loop_controller.compute_loop_health — SQLite is only the data source; the
    cross-run scoring math (loop_quality/best_strategy) stays single-source in
    loop_controller. Return shape == compute_loop_health's."""
    from lib.loop_controller import compute_loop_health

    # TCK-1327: build the dicts from the column names WE select, instead of
    # `dict(row)`. That form only works when the caller happens to have set
    # `row_factory = sqlite3.Row`; with the default factory the rows are plain
    # tuples and `dict(tuple)` raises TypeError. The dashboard opened its own
    # connection without the factory, so the primary source raised, the caller
    # swallowed it into a DEGRADED warning, and the fallback answered instead —
    # a metric silently served by the backup path for who knows how long.
    columns = (
        "loop_iterations", "lessons_consulted", "loop_cost_usd", "loop_strategy",
        "context_peak", "final_judge_delta", "final_judge_delta_source", "warmup",
        # TCK-2090: o predicado de stall/retry lê estes dois. Sem eles a
        # hidratação entregava dicts onde attempt_count/status não existiam e o
        # caminho SQLite respondia stall 0.0 enquanto o glob respondia 3.6 — o
        # mesmo nome, dois números, escolhidos pelo transporte.
        "attempt_count", "status",
    )
    # TCK-2170: FILTRA os runs planos (legado). O TCK-2080 os trouxe para o
    # índice — corretamente, eles existem — mas eles não têm telemetria de
    # loop nenhuma (todos os campos são None por contrato anti-fabricação).
    # Incluí-los aqui inflava o denominador com runs que NUNCA exerceram o
    # loop: medido, `loop_health.runs_total`=98 contra `orchestration`=1 no
    # mesmo relatório, e o /ops-reflect de projeto legado passou a emitir 2
    # recomendações `→ ticket` fabricadas, com remédio invertido ("rebuild do
    # índice" era o que agravava). Mesma lição do TCK-1416/2089: o denominador
    # é quem EXERCEU o loop, e o gêmeo — `aggregate_orchestration`
    # (reflect_aggregators.py:676) — globa só dirs.
    #
    # CORREÇÃO do verify (era afirmação FALSA minha): índice de schema ANTERIOR
    # não é coberto por `IS NULL` — ele não tem a coluna e o SELECT estoura
    # `OperationalError`. O comportamento REAL e seguro é outro: os dois
    # consumidores capturam e caem no glob, que CONCORDA (medido 0/0, 218/218,
    # 7/7). 11 de 14 índices vivos do acervo tomam esse caminho hoje.
    # O `IS NULL` fica como hedge para preenchimento parcial — sem produtor
    # hoje (0 linhas NULL no acervo), declarado como hedge, não como cobertura.
    rows = db.execute(
        f"SELECT {', '.join(columns)} FROM runs "
        f"WHERE run_format = 'dir' OR run_format IS NULL").fetchall()
    # TCK-2231: `lineage` fica fora daqui pelo mesmo critério do `flat-legacy` —
    # não exerceu o loop, logo não vota na QUALIDADE dele. Mas ele existe e é
    # contado na COBERTURA (abaixo), porque o trabalho aconteceu.
    run_datas = [_decode_lessons(dict(zip(columns, row))) for row in rows]
    saude = compute_loop_health(run_datas)
    # Ressalva do verify (TCK-2170): o zero não pode ser mudo. Num projeto com
    # 56 RUN-*.md legítimos o relatório passa a dizer "0 runs", e o leitor não
    # distingue "não há run" de "56 foram filtrados" — a classe
    # sensor-cego-ao-produtor da memória do repo. O número da exclusão viaja
    # junto com o denominador.
    try:
        excluidos = db.execute(
            "SELECT COUNT(*) FROM runs WHERE run_format = 'flat-legacy'"
        ).fetchone()[0]
    except sqlite3.Error:
        excluidos = None       # não medido — NUNCA leia como zero
    saude["runs_excluded_flat_legacy"] = excluidos
    # cobertura: quantos runs de LINHAGEM existem (trabalho real, sem loop)
    try:
        linhagem = db.execute(
            "SELECT COUNT(*) FROM runs WHERE run_format = 'lineage'").fetchone()[0]
    except sqlite3.Error:
        linhagem = None      # não medido — NUNCA leia como zero
    saude["runs_lineage"] = linhagem
    return saude


def query_verifies(
    db: sqlite3.Connection,
    status: str | None = None,
    ticket: str | None = None,
) -> list[dict[str, Any]]:
    sql = "SELECT id, run, ticket, design, verdict, verified_at, verifier FROM verifies WHERE 1=1"
    params: list[Any] = []
    if status:
        sql += " AND verdict = ?"
        params.append(status)
    if ticket:
        sql += " AND ticket = ?"
        params.append(ticket)
    sql += " ORDER BY verified_at DESC"
    try:
        return _rows_to_dicts(db.execute(sql, params).fetchall())
    except sqlite3.DatabaseError as exc:
        # TCK-1136/DES-0745: fail-closed envelope (vide query_lessons).
        raise LessonStoreError(f"verify query failed (corrupt index?): {exc}") from exc


def query_lessons(
    db: sqlite3.Connection,
    ticket: str | None = None,
    severity: str | None = None,
    limit: int = 10,
) -> list[dict[str, Any]]:
    sql = "SELECT id, ticket, severity, lesson, affected_tickets, created_at, source_verdict FROM lessons WHERE 1=1"
    params: list[Any] = []
    if ticket:
        sql += " AND (ticket = ? OR affected_tickets LIKE ?)"
        params.append(ticket)
        params.append(f"%{ticket}%")
    if severity:
        sql += " AND severity = ?"
        params.append(severity)
    # TCK-0487/SPC-0057-C1.5: lição de FALHA severa chega primeiro no top-K
    # que C1.6 injeta — antes era puramente cronológico.
    sql += (" ORDER BY CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 "
            "WHEN 'medium' THEN 2 ELSE 3 END, id DESC LIMIT ?")
    params.append(limit)
    try:
        return _rows_to_dicts(db.execute(sql, params).fetchall())
    except (sqlite3.DatabaseError, sqlite3.OperationalError) as exc:
        # F0.2/F16: fail CLOSED on a corrupt index — never a silent empty list.
        raise LessonStoreError(f"lesson query failed (corrupt index?): {exc}") from exc


def _lesson_utility_map(root: str | Path | None = None,
                         memory_dir_override: str | Path | None = None) -> dict[str, float]:
    """TCK-0837 §3: lesson-text -> utility_score lookup sourced from
    99-memory/lessons/lessons.json. Fail-open: any read/parse error (missing
    file, corrupt JSON, non-list payload) returns {} — callers treat that as
    "no utility signal available" and keep the existing severity/id order."""
    try:
        md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
        lessons_file = md / "lessons" / "lessons.json"
        if not lessons_file.exists():
            return {}
        data = json.loads(lessons_file.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            return {}
        out: dict[str, float] = {}
        for entry in data:
            if not isinstance(entry, dict):
                continue
            text = str(entry.get("lesson", "") or "").strip()
            if not text:
                continue
            try:
                out[text] = float(entry.get("utility_score", 0.0) or 0.0)
            except (TypeError, ValueError):
                out[text] = 0.0
        return out
    except Exception:
        return {}


def query_lessons_ranked(
    db: sqlite3.Connection,
    ticket: str | None = None,
    severity: str | None = None,
    limit: int = 3,
    *,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> list[dict[str, Any]]:
    """TCK-0837 §3: query_lessons(), re-ranked to prefer higher utility_score.

    Pulls a wider candidate window from SQLite (so utility can actually
    reshuffle the top-K) then sorts by utility_score DESCENDING, using
    lessons.json as the utility source (utility_score does not exist as a
    SQLite column — SPC-0026's lessons table has no such field). Rows with no
    matching lessons.json entry (e.g. sourced only from verdicts/*.json)
    default to neutral 0.0 and keep their relative severity/id position
    (Python's ``sorted`` is stable).

    Fail-open by design: if lessons.json is missing/corrupt/empty, or the
    utility lookup itself raises, this degrades to plain ``query_lessons``
    severity/id ordering — utility-based ranking is advisory, never a
    hard requirement (TCK-0837 §3 "keep it simple and fail-open")."""
    kwargs: dict[str, Any] = {"ticket": ticket, "limit": max(int(limit) * 4, 10)}
    if severity:  # only forward when set — keeps the call shape callers/tests expect
        kwargs["severity"] = severity
    candidates = query_lessons(db, **kwargs)
    try:
        umap = _lesson_utility_map(root, memory_dir_override)
        if umap:
            candidates = sorted(
                candidates,
                key=lambda r: -umap.get(str(r.get("lesson", "") or "").strip(), 0.0),
            )
    except Exception:
        pass  # fail-open: keep severity/id order from query_lessons
    return candidates[:limit]


# ---------------------------------------------------------------------------
# Canonical lesson write API (SPC-0032/F0.2)
# ---------------------------------------------------------------------------

def lesson_identity(ticket: str | None, text: str) -> str:
    """Stable lesson id = sha1(f"{ticket}:{normalized_text}").

    normalized = whitespace-collapsed, stripped, lowercased — so the SAME lesson
    appearing in both lessons.json and a verdicts/*.json dedups to one row."""
    norm = " ".join((text or "").split()).strip().lower()
    return hashlib.sha1(f"{ticket}:{norm}".encode("utf-8")).hexdigest()


def memory_dir(root: str | Path | None = None) -> Path:
    """Canonical .archagents/99-memory dir, overridable via CODEBASE_OPS_MEMORY_DIR
    (hermetic tests). Single resolver shared by the lesson writers."""
    env = os.environ.get("CODEBASE_OPS_MEMORY_DIR")
    if env:
        return Path(env)
    return paths(root).archagents / "99-memory"


# TCK-0588: fixed pattern-learner era ("blind era", pre-TCK-0578) judge
# output that is pure boilerplate carrying zero signal — never belongs in
# the canonical store. TCK-0894: promoted here (single source of truth) so
# both the write path (add_lesson, below) and the test suite
# (tests/test_memory_quarantine.py) check the SAME list instead of the
# test defining its own copy that only catches drift after the fact.
NOISE_PATTERNS = (
    "Nenhum relatório de verify disponível",
    "Nenhuma falha significativa detectada",
    "Nenhuma causa raiz identificada",
)


def _matches_noise_pattern(text: str) -> str | None:
    """Return the matched NOISE_PATTERNS substring, or None."""
    for pattern in NOISE_PATTERNS:
        if pattern in text:
            return pattern
    return None


def add_lesson(
    lesson: str,
    affected_tickets: list[str] | None = None,
    severity: str = "medium",
    *,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> str:
    """Canonical lesson write (F4): persist into 99-memory/lessons/lessons.json —
    the build-index-ingestible durable source — atomically and under a memory lock.
    The SQLite row is derived on the next build-index ingest. Returns the lesson_id.

    Every producer (judge, cognee-adapter) writes THROUGH here so there is one
    write path feeding the canonical store, not divergent stores.

    TCK-0894: a lesson whose text matches NOISE_PATTERNS (blind-era
    boilerplate) is quarantined at write time — it never enters the
    canonical lessons.json, going straight to quarantine.json instead. The
    returned lesson_id is unchanged so callers need no special-casing."""
    from lib.memstore import atomic_write_json, memory_lock

    md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
    lessons_file = md / "lessons" / "lessons.json"
    tickets = list(affected_tickets or [])
    new_id = lesson_identity(tickets[0] if tickets else None, lesson)
    noise_match = _matches_noise_pattern(lesson)
    entry = {
        "lesson": lesson,
        "affected_tickets": tickets,
        "severity": severity,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "applied": False,
    }
    with memory_lock(md):
        existing: list[dict[str, Any]] = []
        if lessons_file.exists():
            try:
                existing = json.loads(lessons_file.read_text(encoding="utf-8"))
                if not isinstance(existing, list):
                    existing = []
            except (json.JSONDecodeError, OSError):
                existing = []  # quarantine corrupt source; do not crash the writer
        # TCK-0590: dedup por identidade (ticket+texto) — o append incondicional
        # gerou triplicatas no store (mesma lição gravada 3x em 2026-06-21).
        for prev in existing:
            prev_tickets = prev.get("affected_tickets") or []
            prev_id = lesson_identity(prev_tickets[0] if prev_tickets else None,
                                      str(prev.get("lesson", "")))
            if prev_id == new_id:
                return new_id            # já registrada — não duplica

        # TCK-2104: MESMO texto, ticket DIFERENTE. O dedup do TCK-0590 é por
        # (ticket+texto), então isto passava como duas entradas — e passava sem
        # incomodar enquanto o judge rodava raramente. O hook do TCK-2088 o
        # colocou em TODO `--to done`, e o judge emite frases TEMPLADAS ("Entrega
        # eficiente em 1ª passagem: …") que se repetem a cada entrega boa.
        #
        # Duplicar o texto envenena o consumidor: `cbctl learn consult`
        # (TCK-2100) devolveria N cópias do mesmo template no lugar de N lições
        # distintas — o store viraria banner, que é o defeito que o TCK-1945 já
        # teve de corrigir no ranking.
        #
        # A resposta certa está no próprio schema: `affected_tickets` é LISTA.
        # Uma lição que vale para vários tickets é UMA lição com N tickets, não
        # N lições. Funde em vez de anexar — nenhuma informação se perde.
        for prev in existing:
            if str(prev.get("lesson", "")) != lesson:
                continue
            prev_tickets = list(prev.get("affected_tickets") or [])
            novos = [tk for tk in tickets if tk and tk not in prev_tickets]
            if novos:
                prev["affected_tickets"] = prev_tickets + novos
                atomic_write_json(lessons_file, existing)
            return new_id

        if noise_match is not None:
            qpath = md / "lessons" / "quarantine.json"
            prev_q: list[dict[str, Any]] = []
            if qpath.exists():
                try:
                    prev_q = json.loads(qpath.read_text(encoding="utf-8"))
                    if not isinstance(prev_q, list):
                        prev_q = []
                except (json.JSONDecodeError, OSError):
                    prev_q = []
            prev_q.append({
                **entry,
                "quarantined": True,
                "quarantine_reason": f"blind-era-noise-pattern: {noise_match}",
                "quarantined_at": datetime.now(timezone.utc).isoformat(),
            })
            atomic_write_json(qpath, prev_q)
            return new_id

        existing.append(entry)
        atomic_write_json(lessons_file, existing)
    return new_id


def quarantine_existing_noise_lessons(
    *,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> list[dict[str, Any]]:
    """TCK-0894: retroactive sweep for lessons already in the canonical
    store that match NOISE_PATTERNS (written before the add_lesson guard
    existed, or by a producer that bypassed it). Unlike
    quarantine_low_utility_lessons (which marks quarantined=true IN PLACE),
    this REMOVES the matching entries from lessons.json entirely — the
    invariant test iterates every entry's text unconditionally, so a
    flag-only mark would not satisfy it. Never deletes: moved entries are
    appended to quarantine.json, same as the write-time path."""
    try:
        from lib.memstore import atomic_write_json, memory_lock
    except Exception:
        return []
    md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
    lessons_file = md / "lessons" / "lessons.json"
    if not lessons_file.exists():
        return []
    moved: list[dict[str, Any]] = []
    try:
        with memory_lock(md):
            try:
                existing = json.loads(lessons_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                return []
            if not isinstance(existing, list):
                return []
            kept: list[dict[str, Any]] = []
            for entry in existing:
                if not isinstance(entry, dict):
                    kept.append(entry)
                    continue
                noise_match = _matches_noise_pattern(str(entry.get("lesson", "")))
                if noise_match is not None:
                    moved.append({
                        **entry,
                        "quarantined": True,
                        "quarantine_reason": f"blind-era-noise-pattern: {noise_match}",
                        "quarantined_at": datetime.now(timezone.utc).isoformat(),
                    })
                else:
                    kept.append(entry)
            if moved:
                atomic_write_json(lessons_file, kept)
                qpath = md / "lessons" / "quarantine.json"
                prev_q: list = []
                if qpath.exists():
                    try:
                        prev_q = json.loads(qpath.read_text(encoding="utf-8"))
                        if not isinstance(prev_q, list):
                            prev_q = []
                    except (json.JSONDecodeError, OSError):
                        prev_q = []
                prev_q.extend(moved)
                atomic_write_json(qpath, prev_q)
    except Exception:
        return []
    return moved


# TCK-0920: needle mínimo para substring match em mark_lessons_applied.
# Needle de 1 char ("x", fixture de teste) casaria com quase todas as
# lições; textos reais têm dezenas de chars e a identity sha1 tem 40.
_MIN_NEEDLE_LEN = 12


def lesson_needles(lessons: list) -> list[str]:
    """TCK-0889: contrato de needle consult→applied.

    mark_lessons_applied casa needles contra
    f"{lesson_identity_sha1} {texto}" — um id INTEIRO de linha do SQLite
    nunca casa com esse hay, então o needle precisa carregar o TEXTO da
    lição (id só como fallback quando não há texto). Único construtor de
    needles; orchestrator e pipeline_stages consomem daqui.
    """
    out: list[str] = []
    for lesson in lessons or []:
        if not isinstance(lesson, dict) or lesson.get("error"):
            continue
        needle = str(lesson.get("lesson") or lesson.get("id") or "").strip()[:80]
        if needle:
            out.append(needle)
    return out


def mark_lessons_applied(
    consulted: list[str],
    run_id: str,
    *,
    success: bool,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> int:
    """TCK-0837: close the applied loop.

    For each consulted lesson id/text fragment, mark matching lessons.json
    entries as applied, append run_id to applied_runs, and reinforce
    utility_score (+0.1 success / -0.05 failure, clamped [-1, 1]).
    Returns number of lessons updated. Fail-open: never raises to callers.
    """
    if not consulted:
        return 0
    try:
        from lib.memstore import atomic_write_json, memory_lock
    except Exception:
        return 0
    md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
    lessons_file = md / "lessons" / "lessons.json"
    if not lessons_file.exists():
        return 0
    delta = 0.1 if success else -0.05
    # TCK-0920: needles abaixo de _MIN_NEEDLE_LEN são ignorados (over-match
    # por substring — ver comentário na constante).
    needles = [
        n for n in (str(c).strip().lower() for c in consulted)
        if len(n) >= _MIN_NEEDLE_LEN
    ]
    if not needles:
        return 0
    updated = 0
    try:
        with memory_lock(md):
            try:
                existing = json.loads(lessons_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                return 0
            if not isinstance(existing, list):
                return 0
            changed = False
            for entry in existing:
                if not isinstance(entry, dict):
                    continue
                text = str(entry.get("lesson") or "")
                tickets = entry.get("affected_tickets") or []
                lid = lesson_identity(tickets[0] if tickets else None, text)
                hay = f"{lid} {text}".lower()
                if not any(n in hay or hay[:80] in n for n in needles):
                    continue
                entry["applied"] = True
                runs = entry.get("applied_runs")
                if not isinstance(runs, list):
                    runs = []
                if run_id and run_id not in runs:
                    runs.append(run_id)
                entry["applied_runs"] = runs[-20:]
                score = float(entry.get("utility_score") or 0.0)
                score = max(-1.0, min(1.0, score + delta))
                entry["utility_score"] = round(score, 3)
                entry["last_applied_at"] = datetime.now(timezone.utc).isoformat()
                updated += 1
                changed = True
            if changed:
                atomic_write_json(lessons_file, existing)
    except Exception:
        return 0
    return updated


def decay_lesson_utilities(
    *,
    half_life_days: float = 90.0,
    now: datetime | None = None,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> int:
    """TCK-0838: temporal decay of utility_score (half-life default 90d)."""
    import math
    try:
        from lib.memstore import atomic_write_json, memory_lock
    except Exception:
        return 0
    md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
    lessons_file = md / "lessons" / "lessons.json"
    if not lessons_file.exists():
        return 0
    now = now or datetime.now(timezone.utc)
    updated = 0
    try:
        with memory_lock(md):
            try:
                existing = json.loads(lessons_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                return 0
            if not isinstance(existing, list):
                return 0
            for entry in existing:
                if not isinstance(entry, dict):
                    continue
                ts = entry.get("last_applied_at") or entry.get("timestamp")
                if not ts:
                    continue
                try:
                    then = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
                except ValueError:
                    continue
                days = max(0.0, (now - then).total_seconds() / 86400.0)
                if days < 1:
                    continue
                factor = 0.5 ** (days / half_life_days)
                score = float(entry.get("utility_score") or 0.0)
                new_score = round(score * factor, 3)
                if new_score != score:
                    entry["utility_score"] = new_score
                    updated += 1
            if updated:
                atomic_write_json(lessons_file, existing)
    except Exception:
        return 0
    return updated


def quarantine_low_utility_lessons(
    *,
    threshold: float = -0.3,
    root: str | Path | None = None,
    memory_dir_override: str | Path | None = None,
) -> list[dict[str, Any]]:
    """TCK-0838: propose quarantine (mark quarantined=true); never delete."""
    try:
        from lib.memstore import atomic_write_json, memory_lock
    except Exception:
        return []
    md = Path(memory_dir_override) if memory_dir_override else memory_dir(root)
    lessons_file = md / "lessons" / "lessons.json"
    if not lessons_file.exists():
        return []
    proposed: list[dict[str, Any]] = []
    try:
        with memory_lock(md):
            try:
                existing = json.loads(lessons_file.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError):
                return []
            if not isinstance(existing, list):
                return []
            for entry in existing:
                if not isinstance(entry, dict):
                    continue
                score = float(entry.get("utility_score") or 0.0)
                if score <= threshold and not entry.get("quarantined"):
                    entry["quarantined"] = True
                    entry["quarantine_reason"] = f"utility_score={score} <= {threshold}"
                    proposed.append({
                        "lesson": str(entry.get("lesson", ""))[:160],
                        "utility_score": score,
                    })
            if proposed:
                atomic_write_json(lessons_file, existing)
                qpath = md / "lessons" / "quarantine.json"
                prev: list = []
                if qpath.exists():
                    try:
                        prev = json.loads(qpath.read_text(encoding="utf-8"))
                        if not isinstance(prev, list):
                            prev = []
                    except (json.JSONDecodeError, OSError):
                        prev = []
                prev.extend(proposed)
                atomic_write_json(qpath, prev)
    except Exception:
        return []
    return proposed


def get_stats(db: sqlite3.Connection) -> dict[str, Any]:
    """Contagens agregadas para dashboard/ops-where."""
    try:
        ticket_counts: dict[str, int] = {}
        for row in db.execute("SELECT status, COUNT(*) FROM tickets GROUP BY status"):
            ticket_counts[row[0] or "unknown"] = row[1]

        run_counts: dict[str, int] = {}
        for row in db.execute("SELECT status, COUNT(*) FROM runs GROUP BY status"):
            run_counts[row[0] or "unknown"] = row[1]

        verdict_counts: dict[str, int] = {}
        for row in db.execute("SELECT verdict, COUNT(*) FROM verifies GROUP BY verdict"):
            verdict_counts[row[0] or "unknown"] = row[1]

        lesson_count = db.execute("SELECT COUNT(*) FROM lessons").fetchone()[0]
    except sqlite3.DatabaseError as exc:
        # TCK-1136/DES-0745: fail-closed envelope (vide query_lessons).
        raise LessonStoreError(f"stats query failed (corrupt index?): {exc}") from exc

    return {
        "tickets_total": sum(ticket_counts.values()),
        "tickets_by_status": ticket_counts,
        "runs_total": sum(run_counts.values()),
        "runs_by_status": run_counts,
        "verifies_by_verdict": verdict_counts,
        "lessons_total": lesson_count,
    }
