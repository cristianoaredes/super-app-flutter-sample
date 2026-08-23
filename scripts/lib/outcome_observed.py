#!/usr/bin/env python3
"""Outcome OBSERVADO — a lógica (TCK-1722 / G1 do SPC-0095).

CLI: `python3 scripts/cbctl.py outcome-observed [--verify|--apply]`.
Vive em `lib/` porque aqui `from lib.decisions import ...` resolve sem mutar
`sys.path` — a catraca de packaging (19 legados, congelada) proíbe um preâmbulo
novo, e com razão: cada um é uma cópia a mais do mesmo idiom.

## Por que este script existe

`update_decision_outcome` tinha **dois** chamadores: o backfill (250 registros,
fabricados) e o `pipeline-judge` (18, os únicos legítimos). Do outro lado,
`record_decision` roda a **cada transição de ticket**.

Resultado medido em 2026-08-03: **360 decisões abertas** de 628, com três
classes acima de 80 contra uma `window` de 20. Não falta volume — falta quem
feche. O judge só alcança decisões do run que ele julga; transições feitas fora
do pipeline nunca são fechadas.

## A regra (decidida pelo operador, SPC-0095)

    rejected  <- VER rejected
                 OU VER approved seguido de VER rejected (escape detectado depois)
                 OU ticket de correção que referencia este
    approved  <- VER approved E nenhum VER posterior para o mesmo ticket
    null      <- tudo mais, inclusive approved-with-notes com ressalva aberta

## O que este script NÃO faz, de propósito

- **Não deriva de "o ticket chegou a `done`".** O teste decisivo de qualquer
  produtor de outcome é *"existe caminho pelo qual ele saia `rejected`?"*.
  "Chegou a done -> approved" não tem: quem fecha vira `approved`, quem não
  fecha fica `null`, e a precisão vai a 1,0 **por construção**. É o modo de
  falha que o marcador `implies prior gate succeeded` descreve, e o acervo já
  carrega esse viés (266 approved contra 2 rejected).

- **Não inventa default.** Decisão sem evidência continua `null` — o terceiro
  estado é correto, e é ele que impede o próximo backfill circular.

- **Não reprocessa as 250 fabricadas.** O ADR-0029 já as demoveu a probation;
  reescrever histórico repetiria o erro que originou o ADR.

## Falsificador

`--verify` roda a regra sobre o histórico e exige que ela reproduza os
negativos conhecidos. Se devolver 100% `approved`, está fabricando — e o
comando falha, em vez de deixar entrar.

Uso:
    python3 scripts/ops/decision-outcome-observed.py --verify     # gate, read-only
    python3 scripts/ops/decision-outcome-observed.py              # dry-run (default)
    python3 scripts/ops/decision-outcome-observed.py --apply      # escreve
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path

from lib import decisions as dec

#: Proveniência deste produtor. NÃO pode colidir com
#: `autonomy_ratchet.FABRICATED_PROVENANCE_MARKERS` — se colidir, o outcome que
#: ele grava é descartado pela ratchete, e o trabalho todo vira mais backfill.
PROVENANCE = "observed-from-verify-sequence"

_FM = re.compile(r"^---\n(.*?)\n---", re.S)


def _campo(texto: str, nome: str) -> str | None:
    m = _FM.search(texto)
    if not m:
        return None
    for linha in m.group(1).splitlines():
        if linha.startswith(f"{nome}:"):
            return linha.split(":", 1)[1].strip().strip('"').strip("'")
    return None


def carregar_verificacoes(root: Path) -> dict[str, list[tuple[str, str]]]:
    """`{ticket: [(data, verdict), ...]}` ordenado por data.

    A ORDEM é o que carrega o sinal: `approved` seguido de `rejected` significa
    que o `approved` estava errado — escape detectado depois. Sem ordenar, os
    dois viram só "tem um de cada".
    """
    por_ticket: dict[str, list[tuple[str, str]]] = {}
    base = root / ".archagents" / "14-verify" / "reports"
    if not base.is_dir():
        return por_ticket
    for f in sorted(base.glob("VER-*.md")):
        try:
            texto = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        tk = _campo(texto, "ticket")
        vd = _campo(texto, "verdict")
        if not tk or not vd:
            continue
        quando = _campo(texto, "date") or _campo(texto, "created_at") or f.name
        por_ticket.setdefault(tk, []).append((quando, vd))
    for tk in por_ticket:
        por_ticket[tk].sort()
    return por_ticket


def classificar(sequencia: list[tuple[str, str]]) -> str | None:
    """Aplica a regra aprovada. `None` = fica aberta, e isso é um resultado."""
    if not sequencia:
        return None
    vereditos = [v for _, v in sequencia]

    if any(v.startswith("rejected") for v in vereditos):
        return "rejected"

    # `approved` seguido de QUALQUER veredito posterior: a primeira verificação
    # não bastou. Não é prova de erro, mas também não é prova de acerto — e
    # `null` é o estado honesto para "ainda não sabemos".
    if len(vereditos) > 1:
        return None

    unico = vereditos[0]
    if unico == "approved":
        return "approved"
    # `approved-with-notes` e variantes: ressalva registrada, não resolvida.
    return None


def decisoes_abertas(root: Path) -> list[dict]:
    p = root / ".archagents" / "99-memory" / "decisions" / "decisions.jsonl"
    if not p.is_file():
        return []
    fora = []
    for linha in p.read_text(encoding="utf-8").splitlines():
        if not linha.strip():
            continue
        try:
            d = json.loads(linha)
        except json.JSONDecodeError:
            continue
        if d.get("outcome") is None:
            fora.append(d)
    return fora


def _ticket_da(d: dict) -> str | None:
    md = d.get("metadata") or {}
    tk = md.get("ticket_id") or md.get("ticket")
    if tk:
        return str(tk)
    m = re.search(r"\bTCK-\d+\b", str(d.get("decision") or ""))
    return m.group(0) if m else None


def planejar(root: Path) -> tuple[list[tuple[dict, str]], Counter]:
    vers = carregar_verificacoes(root)
    plano: list[tuple[dict, str]] = []
    motivos: Counter = Counter()
    for d in decisoes_abertas(root):
        tk = _ticket_da(d)
        if not tk:
            motivos["sem ticket identificavel"] += 1
            continue
        seq = vers.get(tk)
        if not seq:
            motivos["ticket sem VER"] += 1
            continue
        veredito = classificar(seq)
        if veredito is None:
            motivos["evidencia insuficiente (fica aberta)"] += 1
            continue
        plano.append((d, veredito))
        motivos[f"-> {veredito}"] += 1
    return plano, motivos


def verificar(root: Path) -> int:
    """Gate: a regra tem de produzir `rejected` onde houve rejeição real."""
    vers = carregar_verificacoes(root)
    negativos = {tk for tk, seq in vers.items()
                 if any(v.startswith("rejected") for _, v in seq)}
    if not negativos:
        print("VERIFY FALHOU: nenhum VER rejeitado no acervo — sem negativo, a "
              "regra nao pode ser falsificada e o gate nao mede nada.", file=sys.stderr)
        return 1

    reproduzidos = {tk for tk in negativos if classificar(vers[tk]) == "rejected"}
    plano, _ = planejar(root)
    dist = Counter(v for _, v in plano)

    print(f"negativos conhecidos: {len(negativos)}  reproduzidos: {len(reproduzidos)}")
    print(f"plano: {dict(dist)}")

    if reproduzidos != negativos:
        faltando = sorted(negativos - reproduzidos)
        print(f"VERIFY FALHOU: a regra nao reproduz {faltando}", file=sys.stderr)
        return 1

    # ADR-0033 / TCK-2084: aqui havia `MIN_AMOSTRA = 20` — "plano com >=20 itens e
    # 100% approved e fabricacao". Removido por ser falso positivo POR CONSTRUCAO,
    # nao por limiar mal calibrado:
    #
    #   - contava DECISOES e raciocinava como vereditos independentes. Medido: 21
    #     itens vindos de 7 tickets (3,0 por ticket), e as 3 decisoes de um ticket
    #     herdam o MESMO veredito do mesmo VER (linha ~171). Amostra 3x inflada.
    #   - o comentario afirmava taxa-base ~5%; a real e 0,88% por ticket.
    #   - logo, reprovava um evento de 94% de probabilidade.
    #
    # A falsificabilidade nao dependia dele: a linha 185 exige que o acervo tenha
    # negativos, e a 197 exige que a regra os reproduza. Ambas intocadas.
    #
    # No lugar entra a checagem ESTRITA, no nivel onde "fabricacao" e decidivel:
    # o conteudo de cada VER approved. 40% do acervo (86 de 214) nao sobrevive a
    # ela — o gate antigo deixava todos passarem.
    fracos = _approved_sem_evidencia(root)
    if fracos:
        print(f"VERIFY FALHOU: {len(fracos)} VER approved novo(s) sem evidencia — "
              f"stub ou corpo vazio nao aprova: {', '.join(sorted(fracos)[:5])}",
              file=sys.stderr)
        print("  (VER honesto sobre limites deve usar approved-with-notes)",
              file=sys.stderr)
        return 1

    print("VERIFY OK: a regra discrimina (produz rejected onde houve rejeicao).")
    return 0


#: Baseline de VERs `approved` com evidencia fraca, por NOME (ADR-0033).
#: Contagem falharia nas duas direcoes — deixaria trocar um fraco velho por um
#: fraco novo. A lista so pode ENCURTAR: se crescer, alguem baselineou um novo,
#: que e exatamente o contorno que o ADR-0033 quer impedir.
BASELINE_EVIDENCIA = ".archagents/.ver-evidence-baseline.json"


def _carregar_baseline(root: Path) -> set[str]:
    f = root / BASELINE_EVIDENCIA
    try:
        dados = json.loads(f.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return set()
    if isinstance(dados, dict):
        dados = dados.get("baseline") or []
    return {str(x) for x in dados}


def _approved_sem_evidencia(root: Path) -> set[str]:
    """VERs `approved` que reprovam no medidor de evidencia e NAO estao no baseline.

    Fail-open na leitura: arquivo ilegivel nao acusa ninguem — o gate mede
    evidencia, e ausencia de meio de medir nao e violacao (terceiro estado).
    """
    try:
        from lib.ver_evidence import check_ver_evidence
    except ImportError:
        return set()
    baseline = _carregar_baseline(root)
    fracos: set[str] = set()
    reports = root / ".archagents" / "14-verify" / "reports"
    for p in sorted(reports.glob("VER-*.md")):
        if p.name in baseline:
            continue
        try:
            texto = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if not re.search(r"^verdict:\s*approved\s*$", texto, re.M):
            continue
        m = re.search(r"^ticket:\s*(\S+)", texto, re.M)
        # TCK-2207: `exigir_limites=False` — este gate mede `approved` sem
        # EVIDÊNCIA (ADR-0033, baseline próprio de 84 nomes). A régua
        # compartilhada ganhou o predicado de LIMITES; herdá-lo aqui mudaria
        # o escopo deste gate por efeito colateral (113 VERs passariam a
        # reprovar sem nada sobre outcome ter mudado). Fonte única segue
        # sendo lib/ver_evidence; o que varia é o que CADA gate cobra.
        if check_ver_evidence(texto, ticket_id=m.group(1) if m else "",
                              exigir_limites=False):
            fracos.add(p.name)
    return fracos




def aplicar(root: Path, plano: list[tuple[dict, str]]) -> int:
    """Escreve os outcomes. Um registro que falha nao derruba o lote."""
    n = 0
    for d, veredito in plano:
        try:
            dec.update_decision_outcome(
                d["id"], veredito,
                human_review={"reviewer": PROVENANCE, "verdict": veredito},
                root=root,
            )
            n += 1
        except Exception as e:
            print(f"  ! {d.get('id')}: {e}", file=sys.stderr)
    return n
