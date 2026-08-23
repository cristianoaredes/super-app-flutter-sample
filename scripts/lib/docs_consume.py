"""Mechanical consumption of 00-10 AS-IS docs (TCK-0831)."""
from __future__ import annotations

from pathlib import Path
from typing import Any

from lib.paths import paths


DOC_BY_SIGNAL = {
    "architecture": "02-architecture.md",
    "module": "03-modules.md",
    "modules": "03-modules.md",
    "convention": "08-conventions.md",
    "security": "07-security-compliance.md",
    "infra": "06-infra-devops.md",
    "integration": "05-integrations.md",
    "data": "04-data-model.md",
    "runbook": "10-runbooks.md",
    "overview": "00-overview.md",
}


def docs_for_ticket(ticket_text: str, root: Path | str | None = None) -> list[str]:
    """Return AS-IS doc paths relevant to ticket text (boost list)."""
    p = paths(root)
    text = (ticket_text or "").lower()
    chosen: list[str] = []
    for signal, doc in DOC_BY_SIGNAL.items():
        if signal in text:
            path = p.archagents / doc
            if path.exists():
                chosen.append(str(path.relative_to(p.root)))
    # Always include architecture + modules when present
    for doc in ("02-architecture.md", "03-modules.md", "08-conventions.md"):
        path = p.archagents / doc
        rel = str(path.relative_to(p.root))
        if path.exists() and rel not in chosen:
            chosen.append(rel)
    return chosen[:6]


def preflight_docs_consulted(ticket_id: str, ticket_path: Path | None = None,
                             root: Path | str | None = None) -> dict[str, Any]:
    body = ""
    if ticket_path and Path(ticket_path).exists():
        body = Path(ticket_path).read_text(encoding="utf-8", errors="ignore")
    docs = docs_for_ticket(f"{ticket_id} {body}", root=root)
    return {"ticket": ticket_id, "docs_consulted": docs, "n": len(docs)}
