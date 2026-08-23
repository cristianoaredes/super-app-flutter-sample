"""Reconciliação aceite↔design (TCK-2156 / DES-1052).

O aceite nasce no Triage, antes do design — por desenho (TCK-0049). O buraco
medido: quando o DES fixa critérios mais fortes, nada obrigava o `acceptance[]`
do ticket a ser revisitado, e o `done` cobrava o aceite de intake. 3 exemplares
na onda de 2026-08-07; um épico inteiro num consumidor.

O mecanismo: o DES declara `acceptance_delta: reemitted | unchanged` — escolha
ATIVA de quem desenha (default silencioso recriaria o buraco com carimbo). A
transição `designed → executing` bloqueia DES novo sem a marca, cabeada em dois
pontos (transition + handoff) porque gate num lugar só é decorativo (3ª lição).

Baseline: DES pré-gate vivem em `.acceptance-delta-baseline.json` (computado do
disco, one-shot) e nunca reprovam. DES com marca dispensa baseline — a população
congelada só encolhe em relevância.

Fonte única do predicado — transition e handoff consomem DAQUI. Duas
implementações divergiriam pela unidade (twin-counters, TCK-1860).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

BASELINE_REL = ".archagents/.acceptance-delta-baseline.json"
DESIGNS_REL = ".archagents/16-designs"
VALORES_VALIDOS = ("reemitted", "unchanged")

_FM_DELTA = re.compile(r"^acceptance_delta:\s*(.+?)\s*$", re.M)
_FM_ID = re.compile(r"^id:\s*(DES-\d+)\s*$", re.M)


def _frontmatter(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[: end + 4] if end != -1 else ""


def _resolve_design(root: Path, design_id: str) -> Path | None:
    """DES-NNNN -> arquivo; canônico primeiro, archive depois (ADR-0004)."""
    for base in (root / DESIGNS_REL, root / ".archagents" / "archive"):
        if not base.is_dir():
            continue
        hits = sorted(base.rglob(f"{design_id}-*.md"))
        # playbooks/threat-models são companions do MESMO id — o documento
        # principal vive na raiz de 16-designs/ (ou espelhado no archive)
        principais = [h for h in hits if h.parent.name not in
                      ("playbooks", "threat-models")]
        if principais:
            return principais[0]
        if hits:
            return hits[0]
    return None


def load_baseline(root: Path) -> set[str]:
    p = root / BASELINE_REL
    if not p.is_file():
        return set()
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return {str(v) for v in data.get("design_ids", [])}
    except (OSError, json.JSONDecodeError):
        # ilegível ≠ vazio silencioso: tratar como vazio é fail-closed
        # (mais DES viram "novos"), e o chamador enxerga a falha no gate
        return set()


def check_acceptance_delta(frontmatter: dict, root: str | Path) -> list[str]:
    """Failures da reconciliação aceite↔design para UM ticket.

    Contrato de entrada: `frontmatter` já parseado (dict) e `root` resolvida —
    o gate não confia em receber (TCK-1636).
    """
    rootp = Path(root)
    linked = frontmatter.get("linked_designs") or []
    if isinstance(linked, str):
        linked = [linked] if linked.strip() else []
    linked = [str(d).strip() for d in linked if str(d).strip()]
    if not linked:
        return []  # sem design não há o que reconciliar (exigência de DES é de outro gate)
    design_id = linked[-1]
    path = _resolve_design(rootp, design_id)
    if path is None:
        return [f"reconciliação aceite↔design (TCK-2156): {design_id} vinculado "
                f"mas não encontrado em 16-designs/ nem no archive — medição "
                f"quebrada não conta como ok"]
    if design_id in load_baseline(rootp):
        return []
    fm = _frontmatter(path)
    if not fm:
        return [f"reconciliação aceite↔design (TCK-2156): {design_id} com "
                f"frontmatter ilegível — fail-closed"]
    m = _FM_DELTA.search(fm)
    if not m:
        return [f"reconciliação aceite↔design (TCK-2156): {design_id} não "
                f"declara `acceptance_delta` — o design fixou critérios; o "
                f"aceite do ticket foi revisitado? Declare no frontmatter do "
                f"DES: `acceptance_delta: reemitted` (aceite reescrito) ou "
                f"`unchanged` (aceite de intake já cobre). A escolha é ativa "
                f"por contrato — sem default"]
    valor = m.group(1).strip().strip('"').strip("'")
    if valor not in VALORES_VALIDOS:
        return [f"reconciliação aceite↔design (TCK-2156): {design_id} declara "
                f"acceptance_delta={valor!r} — vocabulário é "
                f"{'|'.join(VALORES_VALIDOS)}"]
    return []


def write_baseline(root: str | Path) -> tuple[int, str]:
    """Congela os DES SEM marca (one-shot; recusa overwrite). -> (rc, msg)."""
    rootp = Path(root)
    destino = rootp / BASELINE_REL
    if destino.exists():
        return 1, (f"baseline já existe ({destino}) — recusa a sobrescrever; "
                   f"o congelamento é one-shot")
    ids = []
    ddir = rootp / DESIGNS_REL
    if ddir.is_dir():
        for p in sorted(ddir.glob("DES-*.md")):
            fm = _frontmatter(p)
            did = (_FM_ID.search(fm).group(1) if _FM_ID.search(fm)
                   else p.name.split("-", 2)[0] + "-" + p.name.split("-", 2)[1])
            if not _FM_DELTA.search(fm):
                ids.append(did)
    payload = {
        "reason": "TCK-2156/DES-1052: congela DES pré-gate sem acceptance_delta; "
                  "novos declaram reemitted|unchanged",
        "design_ids": sorted(set(ids)),
    }
    destino.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
                       encoding="utf-8")
    return 0, f"baseline escrito: {len(set(ids))} DES congelado(s) em {destino}"
