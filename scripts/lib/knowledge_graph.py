"""Deterministic knowledge graph in SQLite (PLN-0012 / TCK-0832).

Nodes/edges from ticket frontmatter links + facts.json imports.
No LLM required. Lives inside `.archagents/.index.db`.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from lib.frontmatter import parse_frontmatter_file
from lib.paths import paths

GRAPH_DDL = """
CREATE TABLE IF NOT EXISTS kg_nodes (
    id          TEXT PRIMARY KEY,
    kind        TEXT NOT NULL,
    label       TEXT,
    path        TEXT,
    meta_json   TEXT
);
CREATE TABLE IF NOT EXISTS kg_edges (
    src         TEXT NOT NULL,
    dst         TEXT NOT NULL,
    kind        TEXT NOT NULL,
    weight      REAL DEFAULT 1.0,
    PRIMARY KEY (src, dst, kind)
);
CREATE INDEX IF NOT EXISTS idx_kg_edges_src ON kg_edges(src);
CREATE INDEX IF NOT EXISTS idx_kg_edges_dst ON kg_edges(dst);
CREATE INDEX IF NOT EXISTS idx_kg_nodes_kind ON kg_nodes(kind);
"""

LINK_FIELDS = (
    "linked_designs", "linked_runs", "linked_verifications",
    "linked_findings", "linked_docs", "blocks", "blocked_by", "related",
)


def _as_list(val: Any) -> list[str]:
    if val is None:
        return []
    if isinstance(val, list):
        return [str(x) for x in val if x]
    if isinstance(val, str) and val.strip():
        return [val.strip()]
    return []


def _node(conn: sqlite3.Connection, nid: str, kind: str, label: str = "",
          path: str = "", meta: dict | None = None) -> None:
    conn.execute(
        """INSERT INTO kg_nodes (id, kind, label, path, meta_json)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET
             kind=excluded.kind, label=excluded.label,
             path=excluded.path, meta_json=excluded.meta_json""",
        (nid, kind, label or nid, path, json.dumps(meta or {}, ensure_ascii=False)),
    )


def _edge(conn: sqlite3.Connection, src: str, dst: str, kind: str,
          weight: float = 1.0) -> None:
    if not src or not dst or src == dst:
        return
    conn.execute(
        """INSERT INTO kg_edges (src, dst, kind, weight)
           VALUES (?, ?, ?, ?)
           ON CONFLICT(src, dst, kind) DO UPDATE SET weight=excluded.weight""",
        (src, dst, kind, weight),
    )


def _kind_of_id(nid: str) -> str:
    prefix = nid.split("-", 1)[0].upper()
    return {
        "TCK": "ticket", "DES": "design", "VER": "verify", "RUN": "run",
        "ADR": "adr", "LRN": "learning", "DSC": "discovery", "PLN": "plan",
        "SPC": "spec", "FND": "finding", "BRF": "brief",
    }.get(prefix, "artifact")


def rebuild_graph(conn: sqlite3.Connection, root: str | Path | None = None) -> dict[str, int]:
    """Full rebuild of kg_nodes/kg_edges from filesystem + facts.json."""
    p = paths(root)
    conn.executescript(GRAPH_DDL)
    conn.execute("DELETE FROM kg_edges")
    conn.execute("DELETE FROM kg_nodes")

    # Tickets + link edges
    tickets_dir = p.tickets
    if tickets_dir.exists():
        for md in sorted(tickets_dir.glob("TCK-*.md")):
            fm = parse_frontmatter_file(md)
            tid = str(fm.get("id") or md.stem.split("-")[0] + "-" + md.stem.split("-")[1]
                      if "-" in md.stem else md.stem)
            if not str(fm.get("id", "")).startswith("TCK-"):
                # prefer frontmatter id
                tid = str(fm.get("id") or tid)
            _node(conn, tid, "ticket", str(fm.get("title") or tid),
                  str(md.relative_to(p.root)),
                  {"status": fm.get("status"), "effort": fm.get("effort")})
            for field in LINK_FIELDS:
                for target in _as_list(fm.get(field)):
                    if not re_looks_like_id(target):
                        continue
                    _node(conn, target, _kind_of_id(target), target)
                    _edge(conn, tid, target, field)

    # Designs
    designs = p.root / ".archagents" / "16-designs"
    if designs.exists():
        for md in sorted(designs.glob("DES-*.md")):
            fm = parse_frontmatter_file(md)
            did = str(fm.get("id") or md.stem.split("-")[0] + "-" + md.stem.split("-")[1])
            _node(conn, did, "design", str(fm.get("title") or did),
                  str(md.relative_to(p.root)))

    # AS-IS docs
    for doc in sorted((p.root / ".archagents").glob("0*.md")):
        nid = f"DOC-{doc.stem}"
        _node(conn, nid, "doc", doc.stem, str(doc.relative_to(p.root)))

    # facts.json modules + import edges
    facts_path = p.archagents / ".index" / "facts.json"
    if facts_path.exists():
        try:
            facts = json.loads(facts_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            facts = {}
        for m in facts.get("modules") or []:
            mid = f"MOD-{m.get('id')}"
            _node(conn, mid, "module", str(m.get("id")), str(m.get("path") or ""))
        for e in facts.get("python_imports") or []:
            src = f"FILE-{e.get('src')}"
            dst = f"IMP-{e.get('dst')}"
            _node(conn, src, "file", str(e.get("src")), str(e.get("src")))
            _node(conn, dst, "import_target", str(e.get("dst")))
            _edge(conn, src, dst, "imports")
        for ep in facts.get("entrypoints") or []:
            eid = f"EP-{ep.get('id')}"
            _node(conn, eid, "entrypoint", str(ep.get("id")), str(ep.get("path") or ""))

    # Lessons as nodes linked to tickets
    lessons_file = p.archagents / "99-memory" / "lessons" / "lessons.json"
    if lessons_file.exists():
        try:
            lessons = json.loads(lessons_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            lessons = []
        if isinstance(lessons, list):
            for i, lesson in enumerate(lessons):
                if not isinstance(lesson, dict):
                    continue
                lid = f"LESSON-{i}"
                text = str(lesson.get("lesson") or "")[:120]
                _node(conn, lid, "lesson", text)
                for t in _as_list(lesson.get("affected_tickets")):
                    _edge(conn, lid, t, "about")

    conn.commit()
    n_nodes = conn.execute("SELECT COUNT(*) FROM kg_nodes").fetchone()[0]
    n_edges = conn.execute("SELECT COUNT(*) FROM kg_edges").fetchone()[0]
    return {"nodes": n_nodes, "edges": n_edges}


def re_looks_like_id(s: str) -> bool:
    s = s.strip()
    return bool(s) and "-" in s and s.split("-", 1)[0].isalpha() and len(s) < 80


def neighbors(conn: sqlite3.Connection, node_id: str, hops: int = 1
              ) -> list[dict[str, Any]]:
    """Return unique neighbor nodes within N hops (undirected)."""
    if hops < 1:
        return []
    frontier = {node_id}
    seen = {node_id}
    out: list[dict[str, Any]] = []
    for _ in range(hops):
        nxt: set[str] = set()
        for nid in frontier:
            rows = conn.execute(
                """SELECT dst AS other, kind FROM kg_edges WHERE src = ?
                   UNION
                   SELECT src AS other, kind FROM kg_edges WHERE dst = ?""",
                (nid, nid),
            ).fetchall()
            for other, kind in rows:
                if other in seen:
                    continue
                seen.add(other)
                nxt.add(other)
                meta = conn.execute(
                    "SELECT id, kind, label, path FROM kg_nodes WHERE id = ?",
                    (other,),
                ).fetchone()
                if meta:
                    out.append({
                        "id": meta[0], "kind": meta[1], "label": meta[2],
                        "path": meta[3], "via": kind, "from": nid,
                    })
                else:
                    out.append({
                        "id": other, "kind": _kind_of_id(other),
                        "label": other, "path": "", "via": kind, "from": nid,
                    })
        frontier = nxt
    return out


def expand_paths(conn: sqlite3.Connection, seed_paths: list[str],
                 ticket_id: str | None = None, limit: int = 10
                 ) -> list[str]:
    """Given BM25 hit paths, add paths of 1-hop graph neighbors (docs/designs)."""
    extra: list[str] = []
    seeds = set(seed_paths)
    if ticket_id:
        for n in neighbors(conn, ticket_id, hops=1):
            path = n.get("path") or ""
            if path and path not in seeds:
                # prefer repo-relative under .archagents
                if not path.startswith(".archagents") and "archagents" not in path:
                    # try resolve
                    cand = paths().root / path
                    if cand.exists():
                        path = str(cand.relative_to(paths().root))
                extra.append(path)
                seeds.add(path)
            if len(extra) >= limit:
                break
    return extra[:limit]
