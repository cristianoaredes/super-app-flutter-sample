#!/usr/bin/env python3
"""Atomic ticket operations for codebase-ops."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path
from typing import Any

from lib.acceptancelock import count_active_worktrees, read_lock
from lib.frontmatter import FRONTMATTER_RE, parse_frontmatter, parse_list
from lib.ids import id_lock, next_ticket_id, next_ticket_id_unlocked
from lib.paths import paths
from lib.runstate import ALL_PAUSED_STATUSES, parse_iso_safe


# FND-0048: single canonical source — re-exported from runstate.ALL_PAUSED_STATUSES
PAUSED_STATUSES = ALL_PAUSED_STATUSES

STATUS_TRANSITIONS: dict[str, frozenset[str]] = {
    "raw": frozenset({"triaged", "rejected"}),
    "triaged": frozenset({"designed", "blocked", "rejected"}),
    "designed": frozenset({"executing", "blocked", "rejected"}),
    "executing": frozenset({"verifying", "blocked", "rejected", "failed-fatal", *PAUSED_STATUSES}),
    "verifying": frozenset({"done", "executing", "blocked", "rejected"}),
    "blocked": frozenset({"triaged", "designed", "executing", "rejected"}),
    "failed-fatal": frozenset({"blocked", "rejected"}),
    "done": frozenset(),
    "closed": frozenset(),
    "rejected": frozenset(),
}
for _paused in PAUSED_STATUSES:
    STATUS_TRANSITIONS[_paused] = frozenset({"executing", "verifying", "blocked", "rejected"})

KNOWN_STATUSES = frozenset(STATUS_TRANSITIONS)
LIST_FIELDS = frozenset(
    {
        "linked_findings",
        "linked_designs",
        "linked_runs",
        "linked_verifications",
        "linked_docs",
        "external_refs",
        "external_sync",
        "blocks",
        "blocked_by",
        "related",
        "acceptance",
    }
)

TICKET_FIELD_ORDER = [
    "id",
    "slug",
    "title",
    "source",
    "created_at",
    "created_by",
    "updated_at",
    "status",
    "severity",
    "category",
    "effort",
    "flow",
    "ceremony",
    "business_impact",
    "linked_findings",
    "linked_designs",
    "linked_runs",
    "linked_verifications",
    "linked_docs",
    "external_refs",
    "external_sync",
    "blocks",
    "blocked_by",
    "related",
    "acceptance",
]


class TicketError(RuntimeError):
    """Base error for ticket operations."""


class InvalidTransition(TicketError):
    """Raised when a status transition violates the status graph."""


@dataclass
class TicketDocument:
    path: Path
    frontmatter: dict[str, Any]
    body: str

    @property
    def ticket_id(self) -> str:
        return str(self.frontmatter.get("id", ""))

    @property
    def status(self) -> str:
        return str(self.frontmatter.get("status", ""))

    def render(self) -> str:
        return render_document(self.frontmatter, self.body)


@dataclass
class TicketOperationResult:
    ticket_id: str
    path: Path
    status: str
    changed: bool
    dry_run: bool
    frontmatter: dict[str, Any]

    def as_dict(self) -> dict[str, Any]:
        return {
            "ticket_id": self.ticket_id,
            "path": str(self.path),
            "status": self.status,
            "changed": self.changed,
            "dry_run": self.dry_run,
            "frontmatter": self.frontmatter,
        }


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def slugify(text: str, max_length: int = 80) -> str:
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-")
    return (slug or "ticket")[:max_length].strip("-") or "ticket"


def find_ticket_path(ticket: str | Path, root: str | Path | None = None) -> Path:
    candidate = Path(ticket)
    if candidate.exists():
        return candidate
    # F0.7-T5: one resolver (lib.artifacts.resolve_artifact). Lazy import avoids the
    # artifacts<->ticket cycle (artifacts imports ticket at module load). include_archive
    # =False preserves the prior tickets/-only search; ArtifactError->TicketError keeps
    # the existing ambiguity contract that load_ticket callers depend on.
    from lib.artifacts import resolve_artifact, ArtifactError
    try:
        return resolve_artifact("TCK", str(ticket), root=root, include_archive=False)
    except ArtifactError as exc:
        raise TicketError(str(exc)) from exc


def split_document(text: str) -> tuple[dict[str, Any], str]:
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}, text
    return parse_frontmatter(text), text[match.end():]


def load_ticket(ticket: str | Path, root: str | Path | None = None) -> TicketDocument:
    path = find_ticket_path(ticket, root=root)
    text = path.read_text(encoding="utf-8")
    frontmatter, body = split_document(text)
    if not frontmatter.get("id"):
        raise TicketError(f"missing ticket id in {path}")
    return TicketDocument(path=path, frontmatter=frontmatter, body=body)


def _format_scalar(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    text = str(value)
    if text == "":
        return '""'
    if re.fullmatch(r"[A-Za-z0-9_./:@+-]+", text):
        return text
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _iter_frontmatter_items(data: dict[str, Any]) -> list[tuple[str, Any]]:
    ordered: list[tuple[str, Any]] = []
    seen: set[str] = set()
    for key in TICKET_FIELD_ORDER:
        if key in data:
            ordered.append((key, data[key]))
            seen.add(key)
    for key, value in data.items():
        if key not in seen:
            ordered.append((key, value))
    return ordered


def render_frontmatter(data: dict[str, Any]) -> str:
    lines: list[str] = ["---"]
    for key, value in _iter_frontmatter_items(data):
        if isinstance(value, list):
            if not value:
                lines.append(f"{key}: []")
                continue
            lines.append(f"{key}:")
            for item in value:
                if isinstance(item, dict):
                    first = True
                    for dict_key, dict_value in item.items():
                        prefix = "  - " if first else "    "
                        lines.append(f"{prefix}{dict_key}: {_format_scalar(dict_value)}")
                        first = False
                else:
                    lines.append(f"  - {_format_scalar(item)}")
        elif isinstance(value, dict):
            if not value:
                lines.append(f"{key}: {{}}")
                continue
            lines.append(f"{key}:")
            for dict_key, dict_value in value.items():
                lines.append(f"  {dict_key}: {_format_scalar(dict_value)}")
        else:
            lines.append(f"{key}: {_format_scalar(value)}")
    lines.append("---")
    return "\n".join(lines) + "\n"


def render_document(frontmatter: dict[str, Any], body: str) -> str:
    return render_frontmatter(frontmatter) + body.lstrip("\n")


def save_ticket_atomic(path: Path, text: str, *, overwrite: bool = True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            delete=False,
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
        ) as fh:
            tmp_path = Path(fh.name)
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        if overwrite:
            os.replace(tmp_path, path)
        else:
            os.link(tmp_path, path)
            tmp_path.unlink()
        tmp_path = None
    except FileExistsError as exc:
        raise TicketError(f"ticket already exists: {path}") from exc
    finally:
        if tmp_path is not None:
            tmp_path.unlink(missing_ok=True)


def _as_list(frontmatter: dict[str, Any], field: str) -> list[str]:
    return parse_list(frontmatter.get(field))


def _add_unique(frontmatter: dict[str, Any], field: str, values: list[str]) -> bool:
    current = _as_list(frontmatter, field)
    changed = False
    for value in values:
        if value and value not in current:
            current.append(value)
            changed = True
    frontmatter[field] = current
    return changed


def _append_transition_log(body: str, timestamp: str, status: str, reason: str) -> str:
    entry = f"- {timestamp} - **{status}** - {reason.strip()}\n"
    stripped = body.rstrip()
    if "## Log de trans" in stripped:
        return stripped + "\n" + entry
    return stripped + "\n\n## Log de transicoes\n\n" + entry


def validate_transition(from_status: str, to_status: str, force: bool = False) -> None:
    if force:
        return
    if from_status not in KNOWN_STATUSES:
        raise InvalidTransition(f"unknown current status: {from_status}")
    if to_status not in KNOWN_STATUSES:
        raise InvalidTransition(f"unknown target status: {to_status}")
    if to_status not in STATUS_TRANSITIONS[from_status]:
        raise InvalidTransition(f"invalid transition: {from_status} -> {to_status}")


def _new_ticket_payload(
    *,
    ticket_id: str,
    title: str,
    severity: str,
    category: str,
    effort: str,
    source: str,
    root: str | Path | None,
    created_by: str,
) -> tuple[Path, dict[str, Any], str]:
    slug = slugify(title)
    timestamp = utc_now()
    ticket_path = paths(root).tickets / f"{ticket_id}-{slug}.md"
    frontmatter: dict[str, Any] = {
        "id": ticket_id,
        "slug": slug,
        "title": title,
        "source": source,
        "created_at": timestamp,
        "created_by": created_by,
        "updated_at": timestamp,
        "status": "raw",
        "severity": severity,
        "category": category,
        "effort": effort,
        "flow": "normal",
        "ceremony": "full",
        "business_impact": "",
        "linked_findings": [],
        "linked_designs": [],
        "linked_runs": [],
        "linked_verifications": [],
        "linked_docs": [],
        "external_refs": [],
        "external_sync": [],
        "blocks": [],
        "blocked_by": [],
        "related": [],
        "acceptance": [],
    }
    body = (
        f"# {ticket_id} - {title}\n\n"
        "## Contexto\n\n"
        f"Criado via scripts/ops/ticket/create.py a partir de source={source}.\n\n"
        # TCK-2482 / ADR-0038: a seção nasce aqui, no PRODUTOR — editar o
        # template `.md` não alcança ticket nenhum criado pela ferramenta
        # (`path-ownership-invariant`). É afordância; o mecanismo é o gate no
        # fechamento.
        "## Falsificador\n\n"
        "<!-- O que reprova ANTES do fix: o comando que fica vermelho hoje, ou\n"
        "     `arquivo:linha` da evidência. Sem isto o ticket não fecha. -->\n\n"
        "## Log de transicoes\n\n"
        f"- {timestamp} - **raw** - criado via scripts/ops/ticket/create.py.\n"
    )
    return ticket_path, frontmatter, body


def create_ticket(
    *,
    title: str,
    severity: str,
    category: str,
    effort: str,
    source: str,
    root: str | Path | None = None,
    dry_run: bool = False,
    created_by: str = "ops",
) -> TicketOperationResult:
    if dry_run:
        # TCK-2277: dry-run NAO reserva. Antes ele bumpava o high-water
        # compartilhado e queimava o id — medido: a sonda desta sessao consumiu
        # o TCK-2276, que nao existe como arquivo.
        ticket_id = next_ticket_id(root=root, reservar=False)
        ticket_path, frontmatter, _body = _new_ticket_payload(
            ticket_id=ticket_id,
            title=title,
            severity=severity,
            category=category,
            effort=effort,
            source=source,
            root=root,
            created_by=created_by,
        )
        return TicketOperationResult(ticket_id, ticket_path, "raw", True, True, frontmatter)

    with id_lock(root):
        ticket_id = next_ticket_id_unlocked(root=root)
        ticket_path, frontmatter, body = _new_ticket_payload(
            ticket_id=ticket_id,
            title=title,
            severity=severity,
            category=category,
            effort=effort,
            source=source,
            root=root,
            created_by=created_by,
        )
        if ticket_path.exists():
            raise TicketError(f"ticket already exists: {ticket_path}")
        save_ticket_atomic(
            ticket_path,
            render_document(frontmatter, body),
            overwrite=False,
        )
    return TicketOperationResult(ticket_id, ticket_path, "raw", True, False, frontmatter)


# ---------------------------------------------------------------------------
# SPC-0058/TCK-0672 — catraca de confiança.
#
# Matriz ÚNICA que decide se `transition_ticket(..., to_status="done")` exige
# um VER válido e fresco. Hoje só consumida por transition_ticket abaixo; o
# M2/SPC-0059 (custo/cerimônia) importa a MESMA função para não duplicar a
# matriz (risco already mapeado no SPC: "Divergência entre matriz do gate e
# matriz de cerimônia do M2").
# ---------------------------------------------------------------------------

_VER_REQUIRED_SEVERITIES = frozenset({"P0", "P1", "critical", "high"})
_HOTFIX_POSTMORTEM_SEVERITIES = frozenset({"P0", "P1"})
_VER_REQUIRED_EFFORTS = frozenset({"M", "L", "XL"})
_VALID_VER_VERDICTS = frozenset({"approved", "approved-with-notes"})

# Formato gravado por _append_transition_log: "- <ts> - **<status>** - <reason>".
_TRANSITION_LOG_RE = re.compile(r"^-\s+(\S+)\s+-\s+\*\*([\w-]+)\*\*\s+-\s", re.MULTILINE)


def _normalize_severity(value: Any) -> str:
    """Normaliza severity: aceita tanto P0-P3 quanto critical/high/medium/low
    quanto must/should/could/wont (TRIAGE.md — rubricas paralelas por
    `source`). P0-P3 vira maiúsculo canônico ("p0" -> "P0"); o resto vira
    minúsculo ("Critical" -> "critical"). Não inventa equivalência ENTRE
    rubricas (critical não vira "P0") — a matriz abaixo lista os dois
    conjuntos separadamente de propósito (bullets 1 e 4 do SPC-0058 usam
    conjuntos diferentes: {P0,P1,critical,high} vs {P0,P1})."""
    text = str(value or "").strip().lower()
    if re.fullmatch(r"p[0-3]", text):
        return text.upper()
    return text


def ver_required(ticket_frontmatter: dict[str, Any]) -> dict[str, Any]:
    """Catraca de confiança (SPC-0058/TCK-0672): decide se `done` exige VER.

    Pura — não lê disco, nunca levanta exceção. Retorna:
    ``{"required": bool, "reason": str, "mode": "standard" |
    "hotfix_postmortem" | None}``.

    Regras (primeira condição verdadeira já basta para required=True; todas
    as que disparam entram no `reason`):
    - severity ∈ {P0, P1, critical, high} → requerido.
    - effort ∈ {M, L, XL} → requerido.
    - category == "security" → requerido (independe de severity/effort).
    - flow == "hotfix" E severity ∈ {P0, P1} → requerido, mode
      "hotfix_postmortem" (VER pode chegar depois; ver `_hotfix_deadline`).
    - nenhuma das anteriores → not required, mode None.

    Nota (VER onda-A/PLN-0010): a rubrica MoSCoW (`must/should/could/wont`)
    nunca dispara `required` por severity — intencional, não lacuna. MoSCoW
    mede PRIORIDADE de negócio (o que entra num release), não RISCO técnico;
    um `must` de baixo risco não deveria herdar o piso de verificação de um
    `critical`. Se um ticket MoSCoW precisa de VER, isso chega por outro eixo
    (effort M+/L/XL ou category=security), nunca pela severity isolada.
    """
    severity = _normalize_severity(ticket_frontmatter.get("severity"))
    effort = str(ticket_frontmatter.get("effort") or "").strip().upper()
    category = str(ticket_frontmatter.get("category") or "").strip().lower()
    flow = str(ticket_frontmatter.get("flow") or "").strip().lower()

    reasons: list[str] = []
    required = False

    if severity in _VER_REQUIRED_SEVERITIES:
        required = True
        reasons.append(f"severity={ticket_frontmatter.get('severity')!r} (P0/P1/critical/high)")

    if effort in _VER_REQUIRED_EFFORTS:
        required = True
        reasons.append(f"effort={ticket_frontmatter.get('effort')!r} (M/L/XL)")

    if category == "security":
        required = True
        reasons.append("category=security (independe de severity/effort)")

    is_hotfix_postmortem = flow == "hotfix" and severity in _HOTFIX_POSTMORTEM_SEVERITIES
    if is_hotfix_postmortem:
        required = True
        reasons.append("flow=hotfix + severity P0/P1 (modo póstumo: ver_pending_hotfix, prazo 24h)")

    if not required:
        return {
            "required": False,
            "reason": "nenhuma condição da matriz ver_required disparada (severity/effort/category/hotfix)",
            "mode": None,
        }

    return {
        "required": True,
        "reason": "; ".join(reasons),
        "mode": "hotfix_postmortem" if is_hotfix_postmortem else "standard",
    }


def _hotfix_deadline(now_iso: str, hours: int = 24) -> str:
    """ISO-8601 now+hours (default 24h — SPC-0058 Q1, decisão do operador
    2026-07-04). `now_iso` é o mesmo timestamp já usado para `updated_at`
    nesta transição — evita uma segunda chamada a `datetime.now()`."""
    now_dt = parse_iso_safe(now_iso) or datetime.now(timezone.utc)
    return (now_dt + timedelta(hours=hours)).isoformat(timespec="seconds").replace("+00:00", "Z")


def _last_transition_timestamp(body: str, status: str) -> str | None:
    """Último timestamp em que o log de transições (`_append_transition_log`)
    registrou `status` — usado para calcular o frescor de um VER (SPC-0058:
    "trabalho re-executado após o VER invalida o frescor")."""
    matches = [m.group(1) for m in _TRANSITION_LOG_RE.finditer(body) if m.group(2) == status]
    return matches[-1] if matches else None


def _iter_verify_report_frontmatter(root: str | Path | None) -> list[dict[str, Any]]:
    reports_dir = paths(root).verify_reports
    if not reports_dir.exists():
        return []
    out: list[dict[str, Any]] = []
    for report_path in sorted(reports_dir.glob("*.md")):
        try:
            text = report_path.read_text(encoding="utf-8")
        except OSError:
            continue
        fm, _ = split_document(text)
        if fm.get("id") and fm.get("verdict"):
            out.append(fm)
    return out


#: Timestamps que o produtor canônico emite já trazem fuso
#: (`pipeline_reports.py` usa `now_utc_compact()` desde o TCK-0559, com o
#: comentário "was bare datetime.now (naive/LOCAL)"). O buraco do TCK-2571 é do
#: LEITOR: ele aceitava naive sem dizer que aceitou.
_TZ = re.compile(r"(?:Z|z|[+-]\d{2}:?\d{2})\s*$")


def _sem_fuso(raw: Any) -> bool:
    """`True` quando o timestamp existe e NÃO declara fuso.

    Só data (`2026-08-16`) não conta: não afirma hora nenhuma, e a catraca já
    tem tratamento próprio para isso. O alvo é `2026-08-16 18:59`, que afirma
    um instante sem dizer em qual relógio.
    """
    if not isinstance(raw, str) or not raw.strip():
        return False
    # As aspas do YAML sobrevivem em alguns leitores do acervo, e sem tirá-las
    # o `$` da regex casa a aspa em vez do `Z`. Medido: `'"2026-06-12T23:15:00Z"'`
    # era o ÚNICO "sem fuso" de 446 VERs — número pequeno o bastante para eu
    # abrir e ver que o instrumento estava errado, não o dado.
    s = raw.strip().strip('"').strip("'").strip()
    if not re.search(r"\d{1,2}:\d{2}", s):
        return False
    return not _TZ.search(s)


def _find_valid_fresh_ver(
    document: TicketDocument,
    root: str | Path | None,
    extra_linked: list[str] | None = None,
    naive_out: list[str] | None = None,
) -> dict[str, Any] | None:
    """VER válido e fresco (SPC-0058): frontmatter `id:`+`verdict:`
    parseável, `verdict` ∈ {approved, approved-with-notes}, ticket coberto
    por `linked_verifications` (do ticket + o que esta MESMA chamada de
    transition_ticket está prestes a vincular via `verification=`) OU pelo
    ticket presente em `covers:` do VER — e
    `date`/`created_at`/`verified_at` do VER
    POSTERIOR à última transição do ticket p/ `executing` (senão, stale: o
    trabalho mudou depois do veredito). Sem baseline de `executing` no log:
    fail-closed (não dá para provar frescor sem um marco de partida)."""
    _naive = naive_out if naive_out is not None else []
    executing_ts = _last_transition_timestamp(document.body, "executing")
    executing_dt = parse_iso_safe(executing_ts) if executing_ts else None
    if executing_dt is None:
        return None
    linked = set(_as_list(document.frontmatter, "linked_verifications"))
    linked.update(extra_linked or [])
    for fm in _iter_verify_report_frontmatter(root):
        if str(fm.get("verdict", "")).strip() not in _VALID_VER_VERDICTS:
            continue
        # SPC-0058 covers:[] + TCK-0749 tickets:[] + ticket: list (wave alias)
        covered = (
            set(_as_list(fm, "covers"))
            | set(_as_list(fm, "tickets"))
            | set(_as_list(fm, "ticket"))
        )
        if str(fm.get("id", "")) not in linked and document.ticket_id not in covered:
            continue
        # Preserve schema precedence by key presence, not truthiness. A blank,
        # zero, or otherwise malformed high-priority field is invalid evidence;
        # it must not silently fall through to a lower-priority timestamp.
        raw_ver_timestamp: Any = None
        for timestamp_field in ("date", "created_at", "verified_at"):
            if timestamp_field in fm:
                raw_ver_timestamp = fm[timestamp_field]
                break
        # TCK-2571, TERCEIRO ESTADO. `parse_iso_safe` assume UTC para timestamp
        # sem fuso (TCK-0058, por uma razão legítima e alheia a esta: evitar
        # TypeError no cálculo de cycle-time). O efeito colateral aqui é que
        # "sem fuso" fica indistinguível de "com fuso", e a comparação passa a
        # medir uma diferença que não existe.
        #
        # Medido: um VER escrito à mão em UTC-3 com `date: 2026-08-16 18:59`
        # nasce 3h "no passado" contra um baseline `2026-08-16T21:59:23Z` do
        # log de transições — rejeitado como stale, sendo fresco. E a mensagem
        # do gate oferece `--force`, que desliga a catraca inteira para
        # contornar um problema de fuso.
        #
        # Pior: em fuso POSITIVO o erro inverte e falha ABERTO — um VER
        # genuinamente velho passa como fresco por até a diferença do offset.
        #
        # Ausência de fuso não é evidência velha; é evidência não comparável.
        # Recusa nos dois casos, com diagnóstico próprio para cada um.
        if _sem_fuso(raw_ver_timestamp):
            _naive.append(str(fm.get("id", "")) or "<sem id>")
            continue
        ver_dt = parse_iso_safe(raw_ver_timestamp)
        # Evidence must be both newer than the execution baseline and no newer
        # than the verifier's current clock. Future-dated reports cannot prove
        # freshness and therefore fail closed.
        if (
            ver_dt is None
            or ver_dt <= executing_dt
            or ver_dt > datetime.now(timezone.utc)
        ):
            continue
        return fm
    return None


def _backlink_indexes(root: str | Path | None) -> dict[str, Any]:
    """TCK-2361/DES-1090: índice único da evidencia reversa dos artefatos.

    Uma varredura do disco, tres indices keyed por ticket:
    - `runs`: {tid: [(run_id, design|None), ...]} — RUN declara o ticket.
    - `designs`: {tid: [des_id, ...]} — DES declara o ticket.
    - `vers`: {tid: [ver_id, ...]} — VER cobre o ticket (`covers:`/
      `tickets:`/`ticket:`, MESMO predicado reverso de
      `_find_valid_fresh_ver`).
    Falha de leitura e silenciosa (best-effort), nunca bloqueia. Fonte unica:
    consumidor nenhum re-le o disco por conta propria (classe de defeito
    TCK-1860/TCK-2178).

    TCK-2694: `run.json["design"]` e campo LIVRE preenchido por quem abriu o
    run — 1 exemplar no acervo carrega o literal `"DES-0000"` (nunca existiu
    um arquivo DES-0000). Sem filtro, esse valor vira "prova" de design e
    `_backlinks_for`/`transition_ticket` gravariam `linked_designs: [DES-0000]`
    — referencia pendurada que quebra `cbctl validate: ticket linked
    artifacts`. So conta como design PROVADO um id que resolve a um
    `DES-*.md` real no disco (mesmo universo que o loop de designs abaixo ja
    varre); designs escaneado primeiro para o filtro existir quando o loop de
    runs precisar dele.
    """
    p = paths(root)
    runs: dict[str, list[tuple[str, str]]] = {}
    designs: dict[str, list[str]] = {}
    vers: dict[str, list[str]] = {}
    existing_design_ids: set[str] = set()
    if p.designs.exists():
        for design_path in sorted(p.designs.glob("DES-*.md")):
            try:
                fm, _ = split_document(design_path.read_text(encoding="utf-8"))
            except OSError:
                continue
            tid = str(fm.get("ticket", "")).strip()
            des_id = str(fm.get("id", "")).strip()
            if des_id:
                existing_design_ids.add(des_id)
            if tid and des_id:
                designs.setdefault(tid, []).append(des_id)
    if p.runs.exists():
        for run_json in sorted(p.runs.glob("*/run.json")):
            try:
                data = json.loads(run_json.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if not isinstance(data, dict):
                continue
            tid = str(data.get("ticket", "")).strip()
            if not tid:
                continue
            run_id = str(data.get("id") or run_json.parent.name)
            design_id = str(data.get("design") or "").strip() or None
            if design_id and design_id not in existing_design_ids:
                design_id = None  # campo livre sem DES-*.md real: nao e prova
            runs.setdefault(tid, []).append((run_id, design_id))
    for fm in _iter_verify_report_frontmatter(root):
        covered = (
            set(_as_list(fm, "covers"))
            | set(_as_list(fm, "tickets"))
            | set(_as_list(fm, "ticket"))
        )
        ver_id = str(fm.get("id", "")).strip()
        if not ver_id:
            continue
        for tid in covered:
            vers.setdefault(tid, []).append(ver_id)
    return {"runs": runs, "designs": designs, "vers": vers}


def _backlinks_for(
    tid: str, indexes: dict[str, Any]
) -> dict[str, list[str]]:
    """Matcher puro (TCK-2361/DES-1090): o que o índice prova para `tid`."""
    runs_out: list[str] = []
    designs_out: list[str] = []
    for run_id, design_id in indexes["runs"].get(tid, []):
        if run_id and run_id not in runs_out:
            runs_out.append(run_id)
        if design_id and design_id not in designs_out:
            designs_out.append(design_id)
    for des_id in indexes["designs"].get(tid, []):
        if des_id not in designs_out:
            designs_out.append(des_id)
    vers_out: list[str] = []
    for ver_id in indexes["vers"].get(tid, []):
        if ver_id not in vers_out:
            vers_out.append(ver_id)
    return {"designs": designs_out, "runs": runs_out, "verifications": vers_out}


def _derive_backlinks(
    document: TicketDocument,
    root: str | Path | None,
) -> dict[str, list[str]]:
    """TCK-2361/DES-1090: links derivados da evidencia dos proprios artefatos.

    So conta o que o artefato MESMO declara (ver `_backlink_indexes`).
    Rastreabilidade pura: o preenchimento entra DEPOIS dos gates no passo de
    escrita do `done`, nunca muda decisao de fechamento.
    """
    return _backlinks_for(document.ticket_id, _backlink_indexes(root))


def _incomplete_children(children: list[str], root: str | Path | None) -> list[str]:
    """Épicos (SPC-0058): o gate de VER é satisfeito por AGREGAÇÃO — nunca
    exige VER duplicado no próprio épico. Cada child ausente ou não-`done`
    vira uma entrada legível na lista retornada; lista vazia == épico pode
    fechar."""
    incomplete: list[str] = []
    for child_id in children:
        from lib.dependencies import resolve_canonical_ticket_path

        try:
            child_path, resolve_error = resolve_canonical_ticket_path(
                child_id, root=root
            )
            if child_path is None:
                diagnosis = {
                    "missing": "não encontrado",
                    "id-mismatch": "id divergente",
                }.get(resolve_error, "ambíguo")
                incomplete.append(f"{child_id} ({diagnosis})")
                continue
            child = load_ticket(child_path, root=root)
        except (TicketError, FileNotFoundError):
            incomplete.append(f"{child_id} (não encontrado)")
            continue
        if child.ticket_id != child_id:
            incomplete.append(f"{child_id} (id divergente)")
            continue
        if child.status != "done":
            incomplete.append(f"{child_id} (status={child.status})")
    return incomplete


# ---------------------------------------------------------------------------
# TCK-1187 (PLN-0017 D4) — decision log.
#
# Toda transição que representa um julgamento autônomo vira um DEC no log
# append-only (lib/decisions.py) — a camada de dados que a catraca de
# autonomia (D5) vai medir. Classes mínimas: triage (raw->triaged),
# design-approval (triaged->designed), done-closure (verifying->done).
# Confiança vem de sinais reais do ticket — nunca 1.0 fabricado.
# ---------------------------------------------------------------------------

_DECISION_CLASSES: dict[tuple[str, str], str] = {
    ("raw", "triaged"): "triage",
    ("triaged", "designed"): "design-approval",
    ("verifying", "done"): "done-closure",
}


def _transition_confidence(
    document: TicketDocument,
    classe: str,
    *,
    force: bool,
    ver_check: dict[str, Any] | None,
) -> float:
    """Confiança honesta derivada de evidência real do ticket (D4).

    - triage: 0.5 base + 0.1 por campo de classificação preenchido
      (severity/category/effort/business_impact) → 0.5..0.9.
    - design-approval: 0.7 com design vinculado, 0.4 sem.
    - done-closure: 0.9 com VER vinculado; 0.6 quando a matriz ver_required
      não disparou; 0.5 em hotfix póstumo (VER ainda pendente); 0.3 quando
      --force passou por cima do gate."""
    fm = document.frontmatter
    if classe == "triage":
        filled = sum(
            1
            for field in ("severity", "category", "effort", "business_impact")
            if str(fm.get(field) or "").strip()
        )
        return round(0.5 + 0.1 * filled, 2)
    if classe == "design-approval":
        return 0.7 if _as_list(fm, "linked_designs") else 0.4
    # done-closure
    if force:
        return 0.3
    if _as_list(fm, "linked_verifications"):
        return 0.9
    if ver_check is not None and ver_check.get("mode") == "hotfix_postmortem":
        return 0.5
    return 0.6


def _record_transition_decision(
    document: TicketDocument,
    from_status: str,
    to_status: str,
    *,
    root: str | Path | None,
    force: bool,
    ver_check: dict[str, Any] | None,
) -> None:
    """Registra o DEC da transição, se ela for um julgamento autônomo.

    Fail-open: o decision log NUNCA quebra o writer canônico de tickets."""
    classe = _DECISION_CLASSES.get((from_status, to_status))
    if classe is None:
        return
    try:
        from lib import decisions as _decisions  # lazy: evita custo/ciclo de import

        _decisions.record_decision(
            classe,
            f"{document.ticket_id}: {from_status}->{to_status}",
            _transition_confidence(document, classe, force=force, ver_check=ver_check),
            metadata={
                "ticket_id": document.ticket_id,
                "from": from_status,
                "to": to_status,
                "forced": bool(force),
                "ver_required": ver_check.get("required") if ver_check else None,
            },
            root=root,
        )
    except Exception:  # noqa: BLE001 — fail-open por contrato (D4)
        pass


def transition_ticket(
    ticket: str | Path,
    *,
    to_status: str,
    reason: str,
    design: list[str] | None = None,
    run: list[str] | None = None,
    verification: list[str] | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
    force: bool = False,
) -> TicketOperationResult:
    document = load_ticket(ticket, root=root)
    from_status = document.status
    validate_transition(from_status, to_status, force=force)
    from lib.dependencies import (
        dependency_failures,
        evaluate_ticket_dependencies,
        is_progress_status,
    )
    from lib.readiness_events import emit_readiness_event

    # TCK-1347/DES-0808: blocked_by é gate fail-closed em TODO alvo de
    # progresso. Deliberadamente fora de qualquer condição ``not force``:
    # force preserva overrides legados da máquina/VER, nunca a topologia.
    if is_progress_status(to_status):
        dependency_readiness = evaluate_ticket_dependencies(
            document.ticket_id,
            root=root,
        )
        issue_codes = sorted(
            {issue.code for issue in dependency_readiness.issues}
        )
        emit_readiness_event(
            "dependency_readiness",
            correlation_id=document.ticket_id,
            outcome="ready" if dependency_readiness.eligible else "blocked",
            reason=issue_codes[0] if issue_codes else "ready",
            ticket=document.ticket_id,
            eligible=dependency_readiness.eligible,
            dependency_ids=list(dependency_readiness.dependencies),
            issue_codes=issue_codes,
            consumer="writer",
        )
        failures = dependency_failures(dependency_readiness)
        if failures:
            emit_readiness_event(
                "transition_dependency_gate",
                correlation_id=document.ticket_id,
                outcome="rejected",
                reason=issue_codes[0] if issue_codes else "dependency-gate",
                ticket=document.ticket_id,
                **{
                    "from": from_status,
                    "to": to_status,
                    "mutated": False,
                },
            )
            raise InvalidTransition("; ".join(failures))
    # TCK-2156 (DES-1052): reconciliação aceite↔design na ENTRADA do execute.
    # O DES mais recente do ticket precisa declarar acceptance_delta
    # (reemitted|unchanged) — o aceite nasce no Triage e o design fixa
    # critérios depois; sem a marca, o done cobraria menos que o DES decidiu.
    # Cabeado AQUI e em handoff.CONTRACTS["executing"] (fonte única do
    # predicado em lib.acceptance_delta) pela razão de sempre: a transição
    # canônica não consome handoff. DES pré-gate vivem no baseline. --force
    # pula, como nos gates irmãos (override humano com justificativa).
    if to_status == "executing" and not force:
        from lib.acceptance_delta import check_acceptance_delta
        delta_root = root if root is not None else document.path.parents[3]
        delta_failures = check_acceptance_delta(document.frontmatter, delta_root)
        if delta_failures:
            raise InvalidTransition(
                f"{document.ticket_id}: {'; '.join(delta_failures)}")
    # SPC-0057/C2.2 (DES-0213 §3.5) — anti-phantom-done (SPC-0028): em contexto
    # paralelo (>1 worktree ativo), `done` exige evidência flipada pelo runner
    # (criteria-check/pipeline-verify). `force` é o override humano explícito.
    if to_status == "done" and not force and count_active_worktrees(root) > 1:
        entry = read_lock(root).get(document.ticket_id)
        if not entry or entry.get("passes") is not True:
            raise InvalidTransition(
                f"{document.ticket_id}: done bloqueado pelo acceptance-lock "
                f"(>1 worktree ativo e passes != true). Rode "
                f"criteria-check/pipeline-verify antes, ou --force com "
                f"justificativa humana; ver DES-0213 §3.")
    # SPC-0058/TCK-0672 — catraca de confiança: SOMA ao acceptance-lock acima
    # (ortogonal, não substitui — ver DES-0213 §3 vs SPC-0058). Ordem de
    # checagem (GATE.md): acceptance-lock (barato) -> ver_required() ->
    # força/hotfix. Épico (children[]) satisfaz por agregação — nunca exige
    # VER duplicado nele.
    ver_check: dict[str, Any] | None = None
    if to_status == "done" and not force:
        children = _as_list(document.frontmatter, "children")
        if children:
            incomplete = _incomplete_children(children, root)
            if incomplete:
                raise InvalidTransition(
                    f"{document.ticket_id}: épico não pode fechar por agregação "
                    f"(catraca de confiança SPC-0058) — children pendentes: "
                    f"{', '.join(incomplete)}.")
        else:
            ver_check = ver_required(document.frontmatter)
            if ver_check["required"] and ver_check["mode"] != "hotfix_postmortem":
                naive: list[str] = []
                if _find_valid_fresh_ver(document, root,
                                         extra_linked=verification,
                                         naive_out=naive) is None:
                    # TCK-2571: dois motivos, duas mensagens. Mandar `--force`
                    # para um VER que só está sem fuso é oferecer a chave que
                    # desliga a catraca inteira como remédio de um problema de
                    # formatação — e foi o único caminho que a mensagem
                    # oferecia.
                    if naive:
                        raise InvalidTransition(
                            f"{document.ticket_id}: catraca de confiança "
                            f"(SPC-0058): {len(naive)} VER com `date:` SEM FUSO "
                            f"({', '.join(naive[:3])}) — sem fuso, o instante "
                            f"não é comparável com o log de transições, que "
                            f"grava UTC. NÃO use --force: reemita com sufixo Z "
                            f"(ex.: `date: "
                            f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}`).")
                    raise InvalidTransition(
                        f"{document.ticket_id}: catraca de confiança (SPC-0058): "
                        f"VER exigido para severity/effort/category atual "
                        f"({ver_check['reason']}) — rode verify e vincule, ou "
                        f"--force com justificativa.")
        # TCK-1348 (SPC-0086 N1): o verdict do Judge é autoridade bloqueante em
        # TODOS os caminhos nativos — provado nesta entrega que a transição
        # canônica fechava ticket com verdict REJECTED (o contrato de handoff
        # não é consumido aqui). REJECTED, erro de Judge ou safety abaixo do
        # piso barram o fechamento; verdict ausente não barra (DES-0822 T2).
        # Regra e piso vivem em lib/judge_gate (fonte única). --force pula —
        # como na catraca VER: override HUMANO com justificativa, marcado por
        # forced_past_ver_gate; um agente usar --force para furar o judge é
        # violação de matriz de permissões, não um caminho suportado.
        from lib.judge_gate import check_judge_verdict
        # TCK-1636: passar `root` cru mandava `None` quando o CLI não recebia
        # `--root`, e o gate estourava. O documento JÁ foi resolvido por
        # `load_ticket`, e seu path é `<raiz>/.archagents/15-backlog/tickets/…`
        # — a raiz real está a 3 diretórios de distância. Usá-la vale para
        # qualquer chamador, com ou sem `--root`, e em worktree.
        judge_root = root if root is not None else document.path.parents[3]
        judge_failures = check_judge_verdict(document.ticket_id, judge_root)
        if judge_failures:
            raise InvalidTransition(
                f"{document.ticket_id}: {'; '.join(judge_failures)}")
        # TCK-1521: piso de evidência — `done` exige critério falsificável.
        # Cabeado AQUI e não só em handoff.CONTRACTS pela mesma razão do judge
        # logo acima, e provado do mesmo jeito (teste escrito vermelho): a
        # transição canônica não consome o contrato de handoff, então gate que
        # vive só lá é decorativo. Regra e isenções vivem em handoff (fonte
        # única); aqui só se consome.
        from lib.handoff import _check_done_acceptance
        floor_failures = _check_done_acceptance(document, root)
        if floor_failures:
            raise InvalidTransition(
                f"{document.ticket_id}: {'; '.join(floor_failures)}")
        # TCK-2127 (DES-1046): P10 mecanizado — se o ticket TEM verify
        # vinculado, o mais recente precisa ser INDEPENDENTE (verified_by !=
        # operator do RUN). Cabeado AQUI e no CI (audit-measure) pela mesma
        # razão dos dois gates acima: a transição canônica não consome
        # handoff, e gate que vive num lugar só é decorativo (3ª reincidência
        # documentada). Os 371 VERs pré-gate vivem em .p10-baseline.json e
        # nunca reprovam; ticket leve SEM verify segue fechando pelo criteria
        # gate (fronteira declarada no DES — nenhuma exigência nova de VER).
        p10_root = root if root is not None else document.path.parents[3]
        p10_failures = _check_verify_independence(
            document, p10_root, extra_linked=verification)
        if p10_failures:
            raise InvalidTransition(
                f"{document.ticket_id}: {'; '.join(p10_failures)}")
        # TCK-2207: IDENTIDADE (acima) e SUBSTÂNCIA (aqui) são gates distintos, e
        # o de substância vivia só no `handoff.CONTRACTS` — 4ª reincidência de
        # `gate-only-in-handoff-is-decorative`. A transição canônica NÃO consome
        # handoff, então 134 VERs entraram por aqui sem passar pela régua.
        sub_failures = _check_ver_substance(
            document, p10_root, extra_linked=verification)
        if sub_failures:
            raise InvalidTransition(
                f"{document.ticket_id}: {'; '.join(sub_failures)}")

        # TCK-2482 / ADR-0038: o falsificador declarado. A prática saiu de 0%
        # para 73% e RECUOU para 51% enquanto era só prosa em VERIFY.md:36 —
        # advisory é exatamente o estado que recuou. Fail-open na ausência do
        # módulo (lacuna de INSTALAÇÃO, TCK-2120, mesma assimetria do gate
        # irmão P10), fail-closed no dado.
        if not force:
            try:
                from lib.falsifier_evidence import check_falsifier
            except ImportError as exc:
                print(f"[codebase-ops] AVISO: régua de falsificador indisponível "
                      f"({exc}) — a DECLARAÇÃO não foi medida (não é 'ok'). "
                      f"Instale os scripts do framework para reativar o gate.",
                      file=sys.stderr)
            else:
                fals_failures = check_falsifier(
                    document.body, ticket_id=document.ticket_id, root=p10_root)
                if fals_failures:
                    raise InvalidTransition("; ".join(fals_failures))
    timestamp = utc_now()
    document.frontmatter["status"] = to_status
    document.frontmatter["updated_at"] = timestamp
    changed = from_status != to_status
    if to_status in ("done", "rejected", "closed"):
        # TCK-2361/DES-1090: back-link mecanico — deriva da evidencia dos
        # proprios artefatos e mergeia aditivamente. APOS os gates (ordem
        # acima): preenchimento e rastreabilidade, nunca muda decisao de
        # fechamento. Ratchet (P9): so aperta.
        #
        # TCK-2484 (achado F1 do verify da onda 1): rodava SÓ no `done`. Como
        # o fechamento de run percorre `linked_runs`, um ticket rejeitado com
        # a lista vazia não fechava run nenhum — e o sensor era cego a ele
        # (`_tickets_done` não incluía `rejected`). O caminho de rejeição
        # reproduzia exatamente a classe que esta onda existe para fechar.
        derived = _derive_backlinks(document, root)
        design = list(design or []) + derived["designs"]
        run = list(run or []) + derived["runs"]
        verification = list(verification or []) + derived["verifications"]
    changed = _add_unique(document.frontmatter, "linked_designs", design or []) or changed
    changed = _add_unique(document.frontmatter, "linked_runs", run or []) or changed
    changed = _add_unique(document.frontmatter, "linked_verifications", verification or []) or changed
    if to_status == "done":
        if force:
            document.frontmatter["forced_past_ver_gate"] = True
            changed = True
        elif ver_check is not None and ver_check["mode"] == "hotfix_postmortem":
            document.frontmatter["ver_pending_hotfix"] = _hotfix_deadline(timestamp)
            changed = True
    document.body = _append_transition_log(document.body, timestamp, to_status, reason)
    if not dry_run:
        save_ticket_atomic(document.path, document.render())
        _record_transition_decision(
            document, from_status, to_status, root=root, force=force, ver_check=ver_check
        )
        if to_status == "done":
            # ORDEM (TCK-2231, 2ª rodada do verify): a linhagem vem DEPOIS do
            # loop-close. A v1 fazia o contrário e o judge carimbava
            # `final_judge_delta: 29` com `source: "judge"` sobre um artefato que
            # declara NÃO ser execução — fabricação de outcome, a classe que o
            # ADR-0029 teve de desfazer. O `create_lineage_run` nascia honesto
            # (`delta: None`) e era sobrescrito na MESMA chamada.
            _post_done_loop_close(document, root=root)
            _emitir_linhagem_se_sem_run(document, root=root)
            _close_runs_on_done(document, root=root)
        elif to_status in ("rejected", "closed"):
            # TCK-2484: o ticket também termina por aqui, e o run ficava
            # pendurado do mesmo jeito. Sem judge nem linhagem — só o fecho,
            # com `aborted`, porque o trabalho não foi aceito.
            _close_runs_on_done(document, root=root, alvo_padrao="aborted")
    return TicketOperationResult(
        document.ticket_id,
        document.path,
        to_status,
        changed,
        dry_run,
        document.frontmatter,
    )


def _check_ver_substance(
    document: TicketDocument,
    root: str | Path,
    *,
    extra_linked: list[str] | None = None,
) -> list[str]:
    """TCK-2207: o VER do ticket carrega o que mediu (régua de `lib/ver_evidence`).

    Reusa a régua existente (TCK-1350) em vez de duplicá-la: dois predicados
    sobre o mesmo campo divergem pela unidade — foi o defeito dos contadores
    gêmeos (TCK-1860) e o dos dois leitores de procedência (TCK-2178).

    Baseline (`.ver-evidence-baseline.json`) isenta os pré-existentes: P6, não
    se reescreve história. Ticket leve sem VER segue fechando pelo criteria
    gate — nenhuma exigência nova de VER.
    """
    linked = parse_list(document.frontmatter.get("linked_verifications"))
    linked = list(linked) + list(extra_linked or [])
    if not linked:
        return []
    raiz = Path(root)
    try:
        from lib.ver_evidence import baselined, check_ver_evidence
    except ImportError as e:
        # Usa o `sys` do topo do módulo: importar com apelido dentro da
        # função viola a fronteira de packaging ('aliased-sys'). E o
        # detector é TEXTUAL — a v1 deste comentário CITAVA a forma
        # proibida e reprovava o próprio fix (5ª ocorrência da classe
        # `textual-check-rejects-own-fix` nesta sessão).
        # TCK-2207: fail-OPEN aqui é DELIBERADO e assimétrico ao `baselined()`
        # (fail-closed). Mesma razão do gate irmão P10: `lib/` ausente é lacuna
        # de INSTALAÇÃO (TCK-2120), não sinal sobre o VER — bloquear todo `done`
        # de quem não recebeu o instrumento é o gate que ninguém satisfaz. Já o
        # `baselined` é fail-closed porque lá a ausência é sobre O DADO (a lista
        # de isentos), não sobre a existência do medidor.
        print(f"[codebase-ops] AVISO: régua de substância indisponível ({e}) — "
              f"a SUBSTÂNCIA do verify NÃO foi medida (não é 'verify ok'). "
              f"Instale os scripts do framework para reativar o gate.",
              file=sys.stderr)
        return []
    alvo = sorted(linked)[-1]
    if baselined(str(alvo), raiz):
        return []
    caminho = raiz / ".archagents" / "14-verify" / "reports" / f"{alvo}.md"
    if not caminho.is_file():
        return []      # inexistência é domínio do gate de linhagem, não deste
    try:
        texto = caminho.read_text(encoding="utf-8")
    except OSError as e:
        return [f"VER {alvo} ilegível ({e}) — ausência de medição, não aprovação"]
    falhas = check_ver_evidence(texto, ticket_id=document.ticket_id)
    if not falhas:
        return []
    return [f"VER {alvo}: " + "; ".join(falhas)]


def _check_verify_independence(
    document: TicketDocument,
    root: str | Path,
    *,
    extra_linked: list[str] | None = None,
) -> list[str]:
    """TCK-2127: o VER mais recente do ticket deve passar no gate P10.

    Fonte única do predicado é o script `gates/check-verify-independence.py`
    (stdlib puro, o mesmo que o CI roda) — duas implementações divergiriam
    pela unidade, como os contadores gêmeos do TCK-1860. Consumo via
    subprocess com raiz RESOLVIDA (TCK-1636: o gate não confia em receber).

    Script ausente (consumidor cuja instalação não trouxe gates/) → aviso
    ALTO e segue: a ausência é lacuna de instalação (TCK-2120), não licença
    para bloquear todo `done` de quem nem recebeu o instrumento.
    """
    linked = parse_list(document.frontmatter.get("linked_verifications"))
    for extra in extra_linked or []:
        if extra and extra not in linked:
            linked.append(extra)
    if not linked:
        return []
    gate = Path(__file__).resolve().parents[1] / "gates" / "check-verify-independence.py"
    if not gate.is_file():
        print(f"[ops:p10] AVISO: gate ausente ({gate}) — independência do "
              f"verify NÃO checada nesta transição", file=sys.stderr)
        return []
    latest = str(linked[-1])
    try:
        proc = subprocess.run(
            [sys.executable, str(gate), "--root", str(root), "--ver", latest],
            capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return [f"P10 (DES-1046): gate de independência falhou ao rodar "
                f"({exc}) — fail-closed"]
    if proc.returncode == 0:
        return []
    detalhe = (proc.stdout or proc.stderr or "").strip().splitlines()
    detalhe_txt = detalhe[0] if detalhe else f"rc={proc.returncode}"
    if proc.returncode == 4:
        return [f"P10 (TCK-2476): procedência quebrada no VER {latest} — "
                f"{detalhe_txt}. O remédio NÃO é spawnar verificador fresco: "
                f"o VER cita run que não existe ou é de outro ticket, então a "
                f"independência sequer é decidível. Emita o VER contra o run "
                f"do próprio ticket."]
    if proc.returncode == 3:
        return [f"P10 (DES-1046): medição quebrada no VER {latest} — "
                f"{detalhe_txt}. RUN ilegível não conta como independente "
                f"(terceiro estado); conserte o RUN ou vincule VER válido"]
    return [f"P10 (DES-1046): {detalhe_txt}. Quem executou não assina o "
            f"próprio verify — spawne verificador de contexto fresco "
            f"(VERIFY.md) e vincule o VER dele, ou --force com justificativa "
            f"humana"]


def _close_runs_on_done(document: TicketDocument, *,
                        root: str | Path | None,
                        alvo_padrao: str = "completed") -> None:
    """TCK-2477: ticket `done` significa que os RUNs dele terminaram.

    Medido em 2026-08-13: 81 runs presos em `running`, e **81 de 81** com o
    ticket já fechado. Não era trabalho abandonado — era o registro que nunca
    fechava, porque este módulo não tinha uma única menção a fechar run. O
    produtor (`runstate.finalize_run_status`) já existia com um único chamador
    (`pipeline-driver.py:1052`): `canonical-producer-cited-not-called`.

    Três invariantes deste ponto de inserção, todas travadas por código:

    - **Depois de `_post_done_loop_close`**, porque
      `_close_applied_loop_best_effort` exige `"approved" in run.json["result"]`
      e `finalize_run_status` sobrescreve `result` quando recebe `note`. Por
      isso NÃO passamos `note=` — fechar antes, ou com nota, mataria o elo
      applied que o TCK-2362 acabou de ligar.
    - **Depois de `_emitir_linhagem_se_sem_run`**, que pode ADICIONAR run a
      `linked_runs`.
    - **Fora de `_post_done_loop_close`**, que é inerte sob pytest; aqui o
      fecho precisa ser testável in-process.

    Gateia em `ACTIVE_STATUSES`, não em "não-terminal": o acervo tem 63 runs
    com `status: ""` e 2 com `shipped` — nenhum é ativo, e nenhum deve ser
    reescrito. Fail-open por contrato: run inacessível (archive, path movido)
    avisa e segue; o fechamento do ticket nunca depende disto.
    """
    from lib.artifacts import find_run_dir
    from lib.runstate import ACTIVE_STATUSES, TERMINAL_STATUSES, effective_run_status, finalize_run_status

    runs = document.frontmatter.get("linked_runs") or []
    if isinstance(runs, str):
        runs = [runs]
    for run_id in runs:
        run_id = str(run_id).strip()
        if not run_id:
            continue
        try:
            run_dir = find_run_dir(run_id, root)
            efetivo = effective_run_status(run_dir)
            atual = str((efetivo.get("run_data") or {}).get("status") or "").lower()
            if atual not in ACTIVE_STATUSES:
                continue  # terminal, vazio ou desconhecido: não é nosso
            # o REPORT.md pode já declarar o desfecho — respeitamos qual foi
            alvo = efetivo.get("status") if efetivo.get("status") in TERMINAL_STATUSES else alvo_padrao
            finalize_run_status(run_dir, status=alvo)
        except Exception as exc:  # noqa: BLE001 — nunca derruba o fecho do ticket
            print(f"[ops:post-done] run-close: {run_id} não fechado ({exc})",
                  file=sys.stderr)


def _emitir_linhagem_se_sem_run(document: TicketDocument, *,
                                root: str | Path | None) -> None:
    """TCK-2231: ticket que fecha SEM run emite um RUN de LINHAGEM.

    Medido em 2026-08-09: 85 de 302 `done` (28%) não tinham run — o loop mede
    runs, então esse trabalho era invisível. Ticket leve fechar pelo criteria
    gate é comportamento POR DESENHO; o que faltava era reconciliar o desenho
    com a métrica.

    Roda ANTES do `_post_done_loop_close` de propósito: o judge do hook precisa
    de um run para avaliar, e é o mesmo motivo pelo qual a cura roda depois de
    todas as cópias (`cure-must-run-after-all-copies`).

    Best-effort e silencioso no caminho feliz: um ticket que não fecha por
    causa da linhagem é pior que um ticket sem linhagem.
    """
    try:
        if parse_list(document.frontmatter.get("linked_runs")):
            return          # já tem execução — nada a suprir
        # FRONTEIRA que o teste do repo defendeu (test_epic_close_is_quiet):
        # épico fecha por AGREGAÇÃO e legitimamente não tem run. Ele é
        # container, não trabalho — emitir linhagem para ele seria o RUN vazio
        # virando ruído, que é o risco declarado desta escolha.
        if (document.frontmatter.get("category") == "epic"
                or parse_list(document.frontmatter.get("children"))):
            return
        from lib.artifacts import create_lineage_run
        raiz = Path(root) if root is not None else document.path.parents[3]
        rid = create_lineage_run(
            document.ticket_id, raiz,
            reason=f"fechado por criteria gate ({document.frontmatter.get('category', '?')})")
        if rid:
            _add_unique(document.frontmatter, "linked_runs", [rid])
            save_ticket_atomic(document.path, document.render())
    except Exception as e:  # noqa: BLE001 — nunca derruba o fecho
        import sys as _s
        print(f"[codebase-ops] AVISO: linhagem não emitida para "
              f"{document.ticket_id} ({e}) — o trabalho segue invisível ao loop.",
              file=_s.stderr)


def _close_applied_loop_best_effort(base: Path, run_id: str) -> int:
    """TCK-2362: fecha o elo applied no chokepoint nativo.

    Medido na analise do loop (2026-08-12): applied 7/36 — o fechador
    `mark_lessons_applied` (TCK-0837, lib.db, fonte unica do matcher) so era
    chamado no happy path do orchestrator; o close nativo nunca fechava o
    elo. Mesma classe de `gate-so-em-um-lugar-e-decorativo`. Regra: RUN com
    resultado APROVADO e licoes consultadas reforca as licoes (success=True);
    reprovado nao marca (nao se reforca licao que nao evitou a falha).
    Advisory + fail-open como o judge deste chokepoint: nunca derruba a
    transicao.
    """
    try:
        run_dir = paths(base).runs / run_id
        data = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return 0
    if not isinstance(data, dict):
        return 0
    if "approved" not in str(data.get("result") or ""):
        return 0
    consulted = [str(c) for c in data.get("lessons_consulted") or []
                 if isinstance(c, (str, int, float))]
    if not consulted:
        return 0
    from lib.db import mark_lessons_applied
    return mark_lessons_applied(consulted, run_id, success=True, root=base)


def _post_done_loop_close(document: TicketDocument, *, root: str | Path | None) -> None:
    """Fecha os elos 2 e 3 do loop no chokepoint (TCK-2088 / DES-1038).

    Medido em 2026-08-06: o feedback de estratégia decidia sobre **8 de 191**
    runs (4,2%) porque o juiz — o único produtor de `final_judge_delta` com
    procedência que o leitor do TCK-2027 aceita — só rodava no driver do loop.
    O fluxo manual fechava ticket sem nunca acionar o produtor
    (`learning-log-has-no-producer`, em nova roupa).

    Contrato: ADVISORY + fail-open. Um juiz quebrado não pode impedir um done
    legítimo; toda saída é skip declarado ou warn, nunca exceção. E o momento é
    o done porque é quando o diff ainda está na working tree — judgar após o
    commit degrada para `working_tree_aggregate/low_confidence` (probe no RUN
    do TCK-2084).
    """
    # Inerte sob pytest (lição snapshot-disk-bomb: side effect não guardado no
    # e2e já vazou 369GB). Os testes do hook exercitam via subprocess com env
    # limpo + CBOPS_REPO_ROOT no fixture — processo real, efeitos contidos.
    if os.environ.get("PYTEST_CURRENT_TEST"):
        return
    try:
        base = paths(root).root
        runs = parse_list(document.frontmatter.get("linked_runs"))
        if not runs:
            print("[ops:post-done] judge: skip (ticket sem run vinculado)")
        else:
            run_id = runs[-1]
            _judge_run_best_effort(base, document.ticket_id, run_id)
            # TCK-2362: elo applied — apos o judge (que pode gravar o
            # resultado no run.json), reforca licoes consultadas em RUN
            # aprovado. Advisory + fail-open como o judge acima.
            _close_applied_loop_best_effort(base, run_id)
        _close_outcomes_best_effort(base)
        # TCK-2368: criterio 4 da TLP-0001 — esqueleto de PRR por ship. O
        # mecanismo existia (observe.py --emit) sem CALL SITE: nenhum ship
        # real o disparou (medido no PRR-0005). Advisory + fail-open como os
        # vizinhos deste chokepoint.
        _emitir_prr_skeleton_best_effort(base, document.ticket_id)
    except Exception as e:  # noqa: BLE001 — advisory: nunca derruba a transição
        print(f"[ops:post-done] hook falhou (transição intacta): {e}", file=sys.stderr)


def _emitir_prr_skeleton_best_effort(base: Path, ticket_id: str) -> None:
    """Emite o esqueleto de PRR do ticket no chokepoint done (TCK-2368).

    Idempotente: se já existe PRR com `ticket: <id>` no frontmatter (ex.:
    re-done com --force, ou PRR escrito à mão como o PRR-0005), skip — nunca
    duplica esqueleto. Fail-open POR SI: produtor quebrado não rouba o fecho.
    """
    try:
        prr_dir = base / ".archagents" / "17-observability" / "post-release"
        if prr_dir.is_dir():
            for existente in sorted(prr_dir.glob("PRR-*.md")):
                try:
                    if f"ticket: {ticket_id}" in existente.read_text(encoding="utf-8"):
                        print(f"[ops:post-done] prr: skip ({existente.name} "
                              f"já cobre {ticket_id})")
                        return
                except OSError:
                    continue
        from lib.observability import create_post_release_report
        result = create_post_release_report(ticket=ticket_id, root=base,
                                            dry_run=False)
        print(f"[ops:post-done] prr: {result.artifact_id} emitido "
              f"(completar via /ops-observe)")
    except Exception as e:  # noqa: BLE001 — advisory
        print(f"[ops:post-done] prr: falhou ({e}) — transição intacta",
              file=sys.stderr)


def _judge_run_best_effort(base: Path, ticket_id: str, run_id: str) -> None:
    """Invoca o juiz mecânico para gravar o delta MEDIDO no run.json.

    Fail-open POR SI (não só via caller): uma exceção aqui — juiz sabotado,
    timeout, disco — não pode roubar a vez do fecho de outcomes que vem depois.
    """
    try:
        _judge_run(base, ticket_id, run_id)
    except Exception as e:  # noqa: BLE001 — advisory
        print(f"[ops:post-done] judge: falhou ({e}) — transição intacta",
              file=sys.stderr)


def _judge_run(base: Path, ticket_id: str, run_id: str) -> None:
    import json as _json
    import subprocess

    run_json = base / ".archagents" / "13-execution" / "runs" / run_id / "run.json"
    if run_json.exists():
        try:
            data = _json.loads(run_json.read_text(encoding="utf-8"))
        except (OSError, _json.JSONDecodeError):
            data = {}
        # Idempotência (DES-1038 D4): o driver do loop judga ANTES de
        # transicionar — re-judgar aqui seria trabalho dobrado no mesmo diff.
        if data.get("final_judge_delta_source") == "judge":
            print(f"[ops:post-done] judge: skip ({run_id} já judgado)")
            return

    judge = Path(__file__).resolve().parent.parent / "pipeline" / "pipeline-judge.py"
    if not judge.is_file():
        # Consumidor sem o fecho do pipeline instalado: ausência de instrumento
        # não é violação (terceiro estado) — mas é dita, nunca silenciosa.
        print("[ops:post-done] judge: indisponível nesta instalação — skip")
        return

    env = dict(os.environ)
    env["CBOPS_REPO_ROOT"] = str(base)  # DES-1038 D3: raiz da transição, não do arquivo
    proc = subprocess.run(
        [sys.executable, str(judge), "--ticket", ticket_id, "--run", run_id, "--json"],
        capture_output=True, text=True, timeout=120, env=env, cwd=str(base),
    )
    # Exit do juiz é VEREDITO, não saúde (pipeline-judge.py:1242): 0 = EXCELLENT/
    # ACCEPTABLE, 1 = NEEDS_IMPROVEMENT/POOR — nos dois casos ele judgou e gravou
    # o delta. Só rc>=2 (recursion guard, abort) é falha do instrumento. Tratar
    # rc=1 como falha descartaria exatamente os julgamentos negativos — e um
    # produtor que só grava quando o resultado é bom é o backfill do ADR-0029
    # com passos extras.
    if proc.returncode not in (0, 1):
        print(f"[ops:post-done] judge: falhou rc={proc.returncode} (transição intacta)",
              file=sys.stderr)
        return
    delta = src = None
    if run_json.exists():
        try:
            d = _json.loads(run_json.read_text(encoding="utf-8"))
            delta, src = d.get("final_judge_delta"), d.get("final_judge_delta_source")
        except (OSError, _json.JSONDecodeError):
            pass
    print(f"[ops:post-done] judge: {run_id} delta={delta} source={src}")


def _close_outcomes_best_effort(base: Path) -> None:
    """Fecha outcomes que os VERs do acervo já tornaram decidíveis (elo 3).

    Mesmo produtor do driver (TCK-2030): `lib.outcome_observed` deriva de
    sequência de VER — a única procedência que sobrevive ao filtro do ADR-0029.
    """
    try:
        from lib.outcome_observed import aplicar, planejar
        plano, _ = planejar(base)
        if plano:
            aplicar(base, plano)
            print(f"[ops:post-done] outcomes: {len(plano)} fechado(s)")
    except Exception as e:  # noqa: BLE001 — advisory
        print(f"[ops:post-done] outcomes: falhou ({e}) — transição intacta",
              file=sys.stderr)


def link_ticket(
    ticket: str | Path,
    *,
    designs: list[str] | None = None,
    runs: list[str] | None = None,
    verifications: list[str] | None = None,
    root: str | Path | None = None,
    dry_run: bool = False,
) -> TicketOperationResult:
    document = load_ticket(ticket, root=root)
    timestamp = utc_now()
    changed = False
    changed = _add_unique(document.frontmatter, "linked_designs", designs or []) or changed
    changed = _add_unique(document.frontmatter, "linked_runs", runs or []) or changed
    changed = _add_unique(document.frontmatter, "linked_verifications", verifications or []) or changed
    if changed:
        document.frontmatter["updated_at"] = timestamp
        # TCK-1929: a linha de auditoria do link usa o evento próprio `linked`,
        # NUNCA o status atual do ticket. Gravar `**executing** - links updated`
        # fazia o vínculo do VER invalidar o PRÓPRIO VER: a catraca (SPC-0058)
        # lê a última linha `executing` como marco de frescor, e o empate no
        # mesmo segundo reprovava `--to done`. Era uma corrida — fluxo lento
        # passava, fluxo rápido (loop autônomo) reprovava com os mesmos
        # artefatos. `linked` não é status da máquina de estados, então nenhum
        # leitor de estágio (_last_transition_timestamp, cycle_time) o casa.
        document.body = _append_transition_log(document.body, timestamp, "linked", "links updated")
    if changed and not dry_run:
        save_ticket_atomic(document.path, document.render())
    return TicketOperationResult(
        document.ticket_id,
        document.path,
        document.status,
        changed,
        dry_run,
        document.frontmatter,
    )
