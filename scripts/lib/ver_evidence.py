#!/usr/bin/env python3
"""ver_evidence.py — VER `approved` exige evidência semântica (TCK-1350 / SPC-0086 N3).

Verify tem que responder "o que foi pedido foi entregue com segurança?", não
reexibir a saída da mesma etapa que executou. Três defeitos medidos no acervo
(FND-0104, 2026-07-31):

- **72 de 258 VERs eram stubs auto-gerados** cujo corpo inteiro é
  *"Relatorio criado por scripts/ops/verify/create_report.py"* — e **todos os 72
  com `verdict: approved`. Zero rejeições.** Um gerador cuja saída é sempre
  aprovação não é verificação: é carimbo.
- **Auto-afirmação:** o mesmo caminho que executou emitia o VER que se aprova.
- **Sem ligação semântica:** o VER não referenciava nada do que o ticket pediu.

Regra (aplicada só a `verdict: approved` — o veredito mais forte):

1. **Corpo com evidência.** Stub conhecido ou corpo abaixo do mínimo → rejeita.
2. **Ligação semântica.** O corpo precisa referenciar o ticket E pelo menos um
   sinal concreto do que foi verificado (um check do `acceptance[]`, ou uma
   seção de escopo/evidência). Um VER que não diz *o que* verificou não pode
   afirmar aprovação.
3. **Não auto-afirmado.** Corpo que só declara "criado por <script>" sem
   veredito humano ou dimensão avaliada não sustenta `approved`.

**TCK-2207 — a isenção de `approved-with-notes` era o buraco maior.**

A v1 isentava with-notes, com a razão de que "declarar ressalva já é informação
honesta". Medido em 2026-08-08 sobre 394 VERs: **157 são with-notes, e 40 deles
são stub** — o mesmo corpo auto-gerado que a régua barra em `approved`, passando
porque o veredito tem outro nome. Pior: `approved-with-notes` virou o veredito
DEFAULT do driver desde o TCK-1420, então a isenção passou a cobrir o caminho
mais comum. A regra virou "escreva o veredito certo e nada é cobrado".

Agora with-notes passa pela MESMA régua de corpo. `rejected-*` segue isento, e
isso é fronteira, não descuido: rejeitar cedo com pouco texto é o comportamento
desejado — cobrar evidência extensa de quem parou o trabalho empurra para
aprovar.

**TCK-2207 — o predicado de LIMITES.** Medido no mesmo acervo, comparando os
VERs que declaram `verify_context: fresh` (n=20) com o resto (n=374):

| marcador | resto | fresh |
|---|---|---|
| declara o que NÃO mediu | **21%** | **85%** |
| prova por mutação | 4% | 40% |

E o desfecho: verify auto-assinado achou algo em **43%** dos casos; de contexto
fresco, em **75%**. Declarar limites é o discriminador mais forte que existe no
acervo, e não é satisfeito por elogio — exige a frase que um verificador
preguiçoso nunca escreve.

Retrocompatibilidade deliberada: os 72 stubs históricos não são reescritos
(seria fabricar evidência). Eles permanecem como registro; o gate impede novos.
"""

from __future__ import annotations

import re
from pathlib import Path

# Assinaturas de corpo auto-gerado sem conteúdo verificado.
STUB_MARKERS = (
    "relatorio criado por",
    "relatório criado por",
    "report created by",
)

# Corpo mínimo de CONTEÚDO (headings não contam — são estrutura, e um VER de
# puros títulos não afirma nada). Calibrado no VER mínimo realista: escopo do
# gate + resultado da suíte + nota do que não foi coberto ≈ 5 linhas úteis.
# Subir é livre (P9); o objetivo aqui é barrar o stub, não escrever ensaio.
MIN_EVIDENCE_LINES = 5

#: TCK-2207: piso reduzido para quem DECLARA LIMITES e cita evidência conferível.
#:
#: Isto NÃO enfraquece a régua (P9) — troca um proxy fraco por um sinal forte.
#: Contagem de linhas mede volume; limites declarados medem que houve medição.
#: No acervo, declarar limites separa 4% de 80% entre auto-assinado e fresco;
#: contar linhas não separa nada. A régua no conjunto ficou MAIS estrita: passou
#: a cobrir 157 `approved-with-notes` que eram isentos, dos quais 47 reprovam.
#:
#: Sem esta troca, a fronteira que o DES-1067 declarou quebrava: um verify
#: honesto de 3 linhas ("rodei X -> N passed", "conferi path:linha", "não rodei
#: a suíte") era barrado, enquanto 5 linhas de elogio passavam.
MIN_EVIDENCE_LINES_COM_LIMITES = 3

#: TCK-2207 — o discriminador mais forte do acervo: 4% dos VERs declaram o que
#: NÃO mediram, contra 80% dos de contexto fresco. Não é satisfeito por elogio;
#: exige a frase que um verificador preguiçoso nunca escreve.
#:
#: Deliberadamente generoso na forma: "não rodei a suíte" vale tanto quanto uma
#: seção `## Limites`. O objetivo é que o verificador DIGA, não que formate.
_LIMITES_RE = re.compile(
    r"(?i)("
    # TCK-2513: `\d+[.)]\s*` — cabeçalho NUMERADO. `##+\s*limit` não casava
    # `## 5. Limitações`, e dois VERs do acervo reprovavam o CI enquanto
    # declaravam limites em seções de 10+ linhas. Numerar é formatação, não
    # semântica: punir por formato treina o operador a formatar para o gate.
    r"##+\s*(\d+[.)]\s*)?limit|limites?\s+(declarad|do\s+que|desta)|"
    r"o\s+que\s+n[ãa]o\s+(medi|foi\s+medid|foi\s+verificad|cobri)|"
    # TCK-2513: `foi/foram` + `verificad|re-?executad|re-?medid|revisad`. O
    # alfabeto só tinha `foi medido`, então "não foi verificado" e "não foram
    # re-medidos" — as formas que os VERs reais usam — ficavam de fora.
    r"n[ãa]o\s+(medi|mediu|rodei|rodou|exercit|verifiquei|testei|"
    r"consegui\s+medir|for(am|a)m?\s+(medid|verificad|re-?medid|"
    r"re-?executad|revisad)|foi\s+(medid|verificad|re-?executad|revisad)|"
    r"cobert|abrangid|observ)|"
    r"n[ãa]o\s+medido|##+\s*n[ãa]o\s+cobert|"
    r"fora\s+(do\s+escopo|desta\s+verifica)"
    r")")
#: A v1 desta regex era estreita e reprovou a fixture `GOOD_VER` do
#: TCK-1350 — um exemplo de verify BEM-FEITO, que declara limites como
#: "## Não coberto aqui". Um gate que reprova o exemplar canônico de bom
#: comportamento seria desligado na primeira semana, e com razão.
#:
#: O predicado é sobre o verificador DIZER o que não mediu, não sobre a
#: palavra que ele escolheu. Formas aceitas cobrem "não coberto", "fora do
#: escopo", "não rodei", "não medi", "## Limites".

_FM_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


#: TCK-2207: nome PRÓPRIO. A v1 usou `.ver-evidence-baseline.json` — que já
#: existia, com outro dono (ADR-0033 / `lib/outcome_observed.py`, chave
#: `baseline`, 84 nomes) — e sobrescreveu 84 registros de outro gate. Só
#: apareceu porque a suíte completa reprovou `test_baseline_real_do_repo`.
#:
#: Nome parecido com dono diferente é a forma de `path-ownership-invariant`
#: mais fácil de cometer: eu li o nome como descrição do conteúdo, não como
#: endereço de alguém.
BASELINE_REL = ".archagents/.ver-substance-baseline.json"


def baselined(ver_id: str, root: str | Path | None = None) -> bool:
    """VER pré-existente à régua estendida (TCK-2207) — isento, nunca reescrito.

    Fail-CLOSED na leitura: baseline ausente ou ilegível devolve `False`, ou
    seja, o VER É cobrado. O contrário transformaria "não consegui ler a lista
    de isentos" em "todos isentos" — a classe que este repositório persegue.
    """
    import json as _json
    if not ver_id:
        return False
    base = Path(root) if root else Path(__file__).resolve().parents[2]
    alvo = base / BASELINE_REL
    try:
        return ver_id in set(_json.loads(alvo.read_text(encoding="utf-8"))["ver_ids"])
    except (OSError, ValueError, KeyError, TypeError):
        return False


def escrever_baseline(root: str | Path | None = None) -> tuple[int, str]:
    """Congela o acervo lendo o DISCO. One-shot: recusa sobrescrever.

    TCK-2207: o gate irmão (`check-verify-independence.py`) tem
    `--write-baseline` com recusa-a-sobrescrever; este não tinha nenhum
    produtor — o arquivo nascia de um script solto, sem caminho de migração
    para projeto existente (`/ops-config update`) e sem a guarda que impede
    alguém regravar o baseline para "resolver" um vermelho.
    """
    import json as _json
    import re as _re
    base = Path(root) if root else Path(__file__).resolve().parents[2]
    alvo = base / BASELINE_REL
    if alvo.exists():
        return 1, f"baseline já existe ({alvo}) — one-shot por desenho"
    reports = base / ".archagents" / "14-verify" / "reports"
    if not reports.is_dir():
        return 3, f"sem diretório de VERs ({reports}) — não medi, não escrevi"
    ids = []
    for f in sorted(reports.glob("VER-*.md")):
        try:
            texto = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            ids.append(f.stem)      # ilegível entra: não se cobra o que não se lê
            continue
        fm, _ = split_ver(texto)
        m = _re.search(r"(?m)^ticket:\s*(\S+)", fm)
        if check_ver_evidence(texto, ticket_id=m.group(1) if m else ""):
            ids.append(f.stem)
    alvo.parent.mkdir(parents=True, exist_ok=True)
    alvo.write_text(_json.dumps({
        "_comment": ("TCK-2207: VERs pre-existentes a regua estendida. Computado "
                     "lendo o DISCO, nunca digitado. P6: nao se reescreve historia "
                     "— so VER NOVO e cobrado. A populacao so ENCOLHE. NAO "
                     "confundir com .ver-evidence-baseline.json (ADR-0033)."),
        "ver_ids": sorted(ids),
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0, f"baseline com {len(ids)} VER(s) pre-existentes"


def split_ver(text: str) -> tuple[str, str]:
    """(frontmatter, corpo). Sem frontmatter → ("", texto inteiro)."""
    m = _FM_RE.match(text or "")
    return (m.group(1), m.group(2)) if m else ("", text or "")


def verdict_of(text: str) -> str:
    fm, _ = split_ver(text)
    m = re.search(r"(?m)^verdict:\s*(.+?)\s*$", fm)
    return (m.group(1).strip().strip('"\'') if m else "").lower()


#: Preenchimentos que NÃO são declaração de limite. O template canônico
#: (`core/06-verify/templates/verify-report.template.md:35`) traz
#: `**⚠️ Fora do escopo:** W` — placeholder de uma letra que satisfazia o
#: predicado de graça: 26 dos 80 acertos do acervo vinham dessa linha.
#: "Limites: nenhum" também entra aqui — é afirmação de que se mediu TUDO, o
#: oposto do que o predicado busca.
_PLACEHOLDER_RE = re.compile(
    r"(?i)^\s*[-*•]?\s*(nenhum[ao]?|n/?a|nada|none|todo|tbd|a\s+definir|"
    r"[a-z]|\(.{0,12}\)|\.{2,})\s*[.!]?\s*$")


def _declara_limites(body: str) -> bool:
    """Achou a marca E o que vem depois dela é conteúdo, não preenchimento."""
    for m in _LIMITES_RE.finditer(body):
        # Avança até o fim da LINHA da marca, não do match: a regex casa
        # `## Limit` e o resto do match seria `es` — a sobra da própria palavra,
        # que passava como "conteúdo" e anulava a checagem de placeholder.
        fim_linha = body.find("\n", m.start())
        if fim_linha == -1:
            fim_linha = len(body)
        na_linha = body[m.end():fim_linha]
        resto = body[fim_linha + 1:]
        # conteúdo pode vir na mesma linha (`Fora do escopo: W`) ou abaixo
        candidatos = [na_linha]
        candidatos += [l for l in resto.splitlines() if l.strip()][:1]
        # TCK-2513: se a marca é um CABEÇALHO, o que sobra na linha dele é
        # sempre sobra da própria palavra — `## Limitações` deixa `ações`, com
        # 5 letras, que escapava do corte `len <= 3` e fazia
        # `## Limitações\n\nNenhuma.` PASSAR. O gate existe exatamente para
        # barrar seção-ritual, e aceitava a mais óbvia delas. Em cabeçalho, só
        # o corpo abaixo conta.
        if body[fim_linha - len(na_linha) - (m.end() - m.start()):].lstrip().startswith("#"):
            candidatos = candidatos[1:]
        for bruto in candidatos:
            primeira = bruto.strip().lstrip(" :*—-_#").rstrip("*_ ")
            # sobra da própria palavra da marca não conta
            if not primeira or len(primeira) <= 3 and primeira.isalpha():
                continue
            if not _PLACEHOLDER_RE.match(primeira):
                return True
    return False


def check_ver_evidence(ver_text: str, *, ticket_id: str,
                       acceptance_checks: list[str] | None = None,
                       exigir_limites: bool = True) -> list[str]:
    """Failures que impedem um VER `approved` de valer. Vazio = aceito.

    Nunca levanta — texto ilegível já foi tratado por quem leu o arquivo.
    """
    verdict = verdict_of(ver_text)
    # TCK-2207: `approved-with-notes` entra na régua. Medido: 157 no acervo, 40
    # stubs — a isenção virava "escreva o veredito certo e nada é cobrado", e
    # esse é o veredito default do driver desde o TCK-1420.
    if not verdict.startswith("approved"):
        return []  # rejected-* declara honestamente; fronteira declarada

    fm, body = split_ver(ver_text)
    lowered = body.lower()
    failures: list[str] = []

    # TCK-2207: "é stub" passa a ser propriedade do CORPO, não presença de uma
    # string. O produtor escreve o marcador e o `pipeline-driver` APENSA escopo
    # real logo abaixo (`_append_ver_scope`, TCK-1420) — a régua binária
    # reprovava os dois igualmente, e o VER do driver, que declara quais checks
    # rodaram, não é carimbo. Só é stub quando o marcador é TUDO que há.
    _sem_boiler = lowered
    for _m in STUB_MARKERS:
        _sem_boiler = _sem_boiler.replace(_m, " ")
    _restante = [ln for ln in _sem_boiler.splitlines()
                 if ln.strip() and not ln.strip().startswith("#")
                 and not ln.strip().startswith("**")]
    _so_boiler = len(_restante) < MIN_EVIDENCE_LINES_COM_LIMITES
    if any(marker in lowered for marker in STUB_MARKERS) and _so_boiler:
        failures.append(
            "VER approved com corpo de stub auto-gerado (FND-0104: 72/258 do "
            "acervo eram assim, 100% approved) — aprovação exige evidência do "
            "que foi verificado, ou use approved-with-notes")
        return failures  # stub: não faz sentido seguir medindo

    # TCK-2207 — predicado #4 do DES-1067, que a v1 deixou de fora e o verify
    # cobrou. `verify_context` DISCRIMINA o que se exige, e é isso que impede o
    # gate de virar teatro:
    #
    #   mechanical → verificador determinístico (criteria-gate). O método É o
    #                limite, e é sempre o mesmo — exigir que ele REDIJA limites
    #                produziria texto fixo, ou seja, placeholder por construção
    #                (foi o erro da v1). O que se exige dele é EVIDÊNCIA do que
    #                rodou: quais checks, com que resultado. Sem isso, reprova.
    #   fresh/shared → verificador com julgamento. Dele se exige a frase que o
    #                mecânico não pode dar: o que ele escolheu NÃO medir.
    #   ausente    → mais estrito dos dois (não se presume proveniência).
    #
    # O produtor cru não passa em nenhum: não tem escopo nem limites.
    contexto = ""
    m_ctx = re.search(r"(?m)^verify_context:\s*(\S+)", fm)
    if m_ctx:
        contexto = m_ctx.group(1).strip().strip('"\'').lower()
    if contexto == "mechanical":
        exigir_limites = False

    # TCK-2207: DEPOIS do stub-check. Um corpo que é só o texto do gerador já
    # foi diagnosticado pelo que ele é; cobrar "declare limites" de um stub
    # troca a mensagem útil por outra. A ordem foi ajustada quando o teste do
    # TCK-1350 (`assert "stub" in failures[0]`) reprovou — o teste estava certo:
    # o primeiro problema reportado deve ser o mais fundamental.
    if exigir_limites and not _declara_limites(body):
        failures.append(
            "VER não declara LIMITES: dizer o que NÃO foi medido é o que separa "
            "verificação de carimbo (medido: 21% do acervo declara, contra 85% "
            "dos verifies de contexto fresco). Uma linha basta — "
            "'não rodei a suíte completa', 'não exercitei o caminho X'")

    meaningful = [ln for ln in body.splitlines() if ln.strip()
                  and not ln.strip().startswith("#")]
    declarou_limites = _declara_limites(body)
    # `mechanical` entra no piso menor pelo mesmo motivo por que é dispensado de
    # redigir limites: o MÉTODO dele é o limite, e é sempre o mesmo. O que se
    # cobra é evidência do que rodou — e três linhas de escopo real ("criteria:
    # 3/3", "[ok] pytest x", "TCK conferido") são mais informativas que cinco de
    # prosa.
    declarou_limites = declarou_limites or contexto == "mechanical"
    minimo = (MIN_EVIDENCE_LINES_COM_LIMITES if declarou_limites
              else MIN_EVIDENCE_LINES)
    if len(meaningful) < minimo:
        failures.append(
            f"VER approved com corpo insuficiente ({len(meaningful)} linhas "
            f"úteis, mínimo {minimo}) — verify independente registra o que "
            f"avaliou")

    # Ligação semântica: cita o ticket E algum sinal do que foi verificado.
    if ticket_id and ticket_id.lower() not in lowered:
        failures.append(
            f"VER approved não referencia {ticket_id} — sem ligação com o "
            f"pedido, a aprovação não é rastreável ao que foi solicitado")

    checks = [c for c in (acceptance_checks or []) if c and c.strip()]
    if checks:
        cited = any(_check_signal(c) in lowered for c in checks)
        has_scope = any(k in lowered for k in
                        ("escopo", "evidência", "evidencia", "critério",
                         "criterio", "criteria", "verificado", "não coberto",
                         "nao coberto"))
        if not (cited or has_scope):
            failures.append(
                "VER approved sem ligação semântica: não cita nenhum critério "
                "do acceptance[] nem declara escopo do que foi verificado")
    return failures


def _check_signal(check: str) -> str:
    """Trecho do comando estável o bastante para procurar no corpo do VER."""
    token = check.strip().strip('"\'').lower()
    for prefix in ("bash ", "./", "python3 ", "python "):
        if token.startswith(prefix):
            token = token[len(prefix):]
    return token[:40]


def read_ver(path: str | Path) -> str:
    try:
        return Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""
