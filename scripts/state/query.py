#!/usr/bin/env python3
"""query.py — CLI thin para queryar o índice SQLite (SPC-0026, TCK-0198).

Expõe SQL via linha de comando → JSON compacto (ou tabela human-readable).
Agentes e scripts chamam query.py em vez de glob+read+parse.

Uso:
  query.py tickets [--status S] [--priority P] [--kind K] [--json]
  query.py runs [--status S] [--ticket T] [--stale] [--json]
  query.py verifies [--status S] [--ticket T] [--json]
  query.py lessons [--ticket T] [--severity S] [--limit N] [--json]
  query.py search "text" [--limit N] [--json]    # FTS5 (TCK-0201, TCK-1140)
  query.py stats [--json]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

SCRIPTS_DIR = Path(__file__).resolve().parent.parent

from lib.db import get_db, query_tickets, query_runs, query_verifies, query_lessons, get_stats


def _print_json(data: Any) -> None:
    """JSON compacto (sem pretty-print) para minimizar tokens."""
    print(json.dumps(data, separators=(",", ":"), ensure_ascii=False))


def _print_table(rows: list[dict], columns: list[str] | None = None) -> None:
    """Tabela human-readable para uso interativo."""
    if not rows:
        print("(no results)")
        return
    cols = columns or list(rows[0].keys())
    # Header
    print("  ".join(f"{c:12s}" for c in cols))
    print("  ".join("-" * 12 for _ in cols))
    for row in rows:
        print("  ".join(str(row.get(c, ""))[:12].ljust(12) for c in cols))


def cmd_tickets(args: argparse.Namespace) -> int:
    db = get_db(args.root)
    rows = query_tickets(db, status=args.status, priority=args.priority, kind=args.kind)
    if args.json:
        _print_json(rows)
    else:
        _print_table(rows, ["id", "status", "priority", "title"])
    return 0


def cmd_runs(args: argparse.Namespace) -> int:
    db = get_db(args.root)
    rows = query_runs(db, status=args.status, ticket=args.ticket, stale=args.stale)
    if args.json:
        _print_json(rows)
    else:
        _print_table(rows, ["id", "ticket", "status", "result"])
    return 0


def cmd_verifies(args: argparse.Namespace) -> int:
    db = get_db(args.root)
    rows = query_verifies(db, status=args.status, ticket=args.ticket)
    if args.json:
        _print_json(rows)
    else:
        _print_table(rows, ["id", "ticket", "verdict"])
    return 0


def cmd_lessons(args: argparse.Namespace) -> int:
    db = get_db(args.root)
    rows = query_lessons(db, ticket=args.ticket, severity=args.severity, limit=args.limit)
    if args.json:
        _print_json(rows)
    else:
        _print_table(rows, ["id", "ticket", "severity", "lesson"])
    return 0


def cmd_search(args: argparse.Namespace) -> int:
    """FTS5 full-text search over tickets (title + slug + body; active + archived).

    TCK-1140/DES-0749 (FND-0093): tickets_fts agora cobre o corpus unificado
    (build-index popula archived + body). O LEFT JOIN com a tabela relacional
    (active-only) deriva o escopo: sem match → ticket arquivado."""
    db = get_db(args.root)
    try:
        rows = db.execute(
            """SELECT tickets_fts.ticket_id, tickets_fts.title, tickets.status
               FROM tickets_fts
               LEFT JOIN tickets ON tickets.id = tickets_fts.ticket_id
               WHERE tickets_fts MATCH ? ORDER BY rank LIMIT ?""",
            (args.text, args.limit),
        ).fetchall()
        results = [
            {
                "id": dict(r)["ticket_id"],
                "title": dict(r)["title"],
                # NULL no JOIN = ausente da tabela ativa → arquivado
                "scope": "active" if dict(r)["status"] is not None else "archived",
                "status": dict(r)["status"] or "",
            }
            for r in rows
        ]
    except Exception as e:
        _print_json({"error": str(e)})
        return 1
    if args.json:
        _print_json(results)
    else:
        _print_table(results, ["id", "scope", "title"])
    return 0


def cmd_stats(args: argparse.Namespace) -> int:
    db = get_db(args.root)
    stats = get_stats(db)
    if args.json:
        _print_json(stats)
    else:
        for key, val in stats.items():
            if isinstance(val, dict):
                print(f"{key}:")
                for k, v in val.items():
                    print(f"  {k}: {v}")
            else:
                print(f"{key}: {val}")
    return 0


def _add_common_args(p: argparse.ArgumentParser) -> None:
    """Adiciona --json e --root a cada subparser (permite posicionar após subcomando)."""
    p.add_argument("--root", default=None, help="Project root (default: cwd)")
    p.add_argument("--json", action="store_true", help="Output compact JSON")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Query CLI for .archagents/ SQLite index (SPC-0026)"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # tickets
    p = sub.add_parser("tickets", help="Query tickets")
    p.add_argument("--status", default=None)
    p.add_argument("--priority", default=None)
    p.add_argument("--kind", default=None)
    _add_common_args(p)
    p.set_defaults(func=cmd_tickets)

    # runs
    p = sub.add_parser("runs", help="Query runs")
    p.add_argument("--status", default=None)
    p.add_argument("--ticket", default=None)
    p.add_argument("--stale", action="store_true", help="Only stale runs (>24h running)")
    _add_common_args(p)
    p.set_defaults(func=cmd_runs)

    # verifies
    p = sub.add_parser("verifies", help="Query verify reports")
    p.add_argument("--status", default=None, help="Verdict (approved, rejected, etc.)")
    p.add_argument("--ticket", default=None)
    _add_common_args(p)
    p.set_defaults(func=cmd_verifies)

    # lessons
    p = sub.add_parser("lessons", help="Query lessons from judge")
    p.add_argument("--ticket", default=None)
    p.add_argument("--severity", default=None)
    p.add_argument("--limit", type=int, default=10)
    _add_common_args(p)
    p.set_defaults(func=cmd_lessons)

    # search (FTS5 — TCK-0201)
    p = sub.add_parser("search", help="Full-text search (FTS5 — TCK-0201)")
    p.add_argument("text", help="Search query")
    p.add_argument("--limit", type=int, default=10)
    _add_common_args(p)
    p.set_defaults(func=cmd_search)

    # stats
    p = sub.add_parser("stats", help="Aggregate counts")
    _add_common_args(p)
    p.set_defaults(func=cmd_stats)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
