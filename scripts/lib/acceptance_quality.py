#!/usr/bin/env python3
"""acceptance_quality.py — detecta critério que não consegue ficar vermelho (TCK-1522).

Um `acceptance[].check` tautológico é pior que critério nenhum: produz verde
com custo de credibilidade. O ticket parece verificado, o gate parece ter
rodado, e nada foi provado.

Censo completo em 2026-08-01, com estes padrões: **22 de 1375 checks (1,6%)** —
1/317 no diretório ativo, 21/1058 no archive. Baixo, e é o ponto: o padrão não
precisa ser comum para ser caro, porque cada ocorrência produz um verde que
ninguém revisa. A concentração no archive (2,0% vs 0,3%) sugere que o hábito
está diminuindo sozinho; o gate é o que impede a volta.

O pior caso encontrado é instrutivo — `… | grep -c 'X' || true` com `expect: 0`:
o `|| true` zera o exit, e o `expect` desancorado ainda casaria `10` ou `20`.
Dois mecanismos de falsificação anulados no mesmo critério.

Padrões detectados — todos com a mesma assinatura, o exit code final nunca
depende do que se quer provar:

0. **Comando trivialmente verdadeiro** (`true`, `:`, `/bin/true`, `exit 0`, ou
   um `echo` puro) — TCK-1540. Achado *usando* o piso do TCK-1521: cobrado a
   preencher `acceptance[]`, o caminho de menor esforço é escrever `true`, e a
   v1 do linter deixava passar justamente o caso mais grosseiro. É a rota de
   escape óbvia do piso. `echo ok` com `expect: ok` é o mais insidioso: parece
   critério completo — comando, expect, e os dois casam — e nada do sistema é
   tocado. Casa o comando INTEIRO, nunca substring: `echo ok && test -f x` é
   legítimo (o `echo` ali é prefixo, não o critério).
1. `|| true` / `; true` — força exit 0 sem condição.
2. `|| echo …` **sem `expect`** — o `echo` sai 0 e vira o exit do comando; com
   `expect`, a saída ainda é comparada, então é legítimo.
3. Pipe terminal para `head`/`tail`/`cat`/`wc` — em pipeline sem `pipefail`, o
   exit é do ÚLTIMO comando. `pytest … | tail -1` sempre sai 0.
4. `grep -c` sem `expect` — `grep -c` sai 1 quando conta zero, mas o número
   impresso é o que interessa; sem `expect` o critério vira "achou pelo menos
   um", que raramente é o que o autor queria.

Sinal, não bloqueio automático: o `dor-check` decide barrar na entrada; o
`criteria-check` reporta. Bloquear retroativamente invalidaria acervo legítimo
sem revisão humana.
"""

from __future__ import annotations

import re

# (nome, regex, exige_expect_ausente) — quando o 3º é True, o padrão só é
# tautológico se o item NÃO declarar `expect`.
_PATTERNS: tuple[tuple[str, re.Pattern[str], bool], ...] = (
    # TCK-1540 — o comando INTEIRO não pode falhar. Ancorado nos dois extremos
    # de propósito: `echo ok && test -f x` não casa, porque ali o `echo` é
    # prefixo e o critério real é o `test`. `expect` não resgata nenhum destes
    # (3º elemento False): `echo ok` com `expect: ok` casa consigo mesmo sem
    # tocar em nada do sistema.
    ("check-trivialmente-verdadeiro",
     re.compile(r"^\s*(?:true|:|/bin/true|/usr/bin/true|exit\s+0"
                r"|echo(?:\s+[^&;|]*)?)\s*$"), False),
    ("força-exit-zero", re.compile(r"\|\|\s*true\b|;\s*true\s*$"), False),
    ("fallback-echo", re.compile(r"\|\|\s*echo\b"), True),
    ("pipe-terminal-mascara-exit",
     re.compile(r"\|\s*(head|tail|cat|wc)\b[^|]*$"), True),
    # TCK-1621: era só `grep`. O repo migrou para `rg` (ripgrep) há tempo — todo
    # acceptance novo usa `rg -c` — e a regra passou a olhar para um comando que
    # ninguém mais escreve. Instrumento tecnicamente ligado, praticamente cego:
    # a mesma classe que o `audit-reachability` caça, com outro disfarce.
    #
    # Custo medido: escrevi `rg -c '...' ` com `expect: "0"`, que é
    # ESTRUTURALMENTE IMPOSSÍVEL de ficar verde (sem match o rg sai 1 e não
    # imprime; com match sai 0 mas imprime ≥1). O linter passou; quem pegou foi
    # o verify adversarial.
    ("grep-c-sem-expect",
     re.compile(r"\b(?:grep|rg|ripgrep)\s+(?:-\w*c\w*|--count)\b"), True),
)


#: Filtros terminais que engolem o exit code do produtor. `grep`/`rg` entram
#: aqui — mas, ao contrário de `head`/`tail`, eles CARREGAM veredito (saem 1
#: sem match), então a regra abaixo não os trata como tautologia de forma: ela
#: pergunta se a saída de FRACASSO satisfaz o critério.
_FILTRO_TERMINAL_RE = re.compile(
    r"(?<!\|)\|(?!\|)\s*(?:head|tail|cat|wc|tr|sed|awk|cut|sort|uniq|tee"
    r"|column|nl|fold|grep|egrep|fgrep|rg|ripgrep)\b([^|]*)$")

#: Como a FALHA de cada produtor se parece. Se o `expect` casa uma destas, o
#: critério fica verde sobre uma execução que reprovou.
_VOCABULARIO_DE_FALHA = (
    (re.compile(r"\bpytest\b"),
     ("1 failed, 1 passed in 0.01s", "2 failed, 3 passed, 1 skipped in 0.10s",
      "ERROR collecting tests/test_x.py", "no tests ran in 0.01s")),
    (re.compile(r"\bunittest\b"), ("FAILED (failures=1)", "FAILED (errors=1)")),
)


def _expect_casa_saida_de_falha(check: str, expect: str | None) -> bool:
    """TCK-2480: o critério aceita a saída de um produtor que REPROVOU?

    Medido em 2026-08-13: 52 checks do acervo no padrão
    `pytest … 2>&1 | grep 'passed'` com `expect: passed`. O pipe terminal
    entrega o rc do `grep`, e `"passed"` é substring de `"1 failed, 4 passed"`
    — os dois lados de `rc_ok and matched` ficam verdadeiros sobre uma suíte
    vermelha.

    O detector não via nada, por DUAS causas independentes: `grep` não estava
    no alfabeto de filtros, e a isenção de `has_expect` desligava a regra.
    Corrigir só uma continuaria marcando 0 de 52.

    Duas soluções óbvias foram descartadas POR MEDIÇÃO, não por gosto:
    alargar o alfabeto marcaria 41 checks sadios (`| grep -q X` e `| jq -e`
    carregam veredito); exigir `expect` ancorado teria 21% de falso-positivo
    (os 26 `unittest | tail -1` com `expect: OK` discriminam de verdade).

    Esta regra mede a PERDA: pega o portador-de-veredito efetivo — o `expect`
    se houver, senão o padrão do próprio filtro — e pergunta se ele casa a
    saída de fracasso do produtor nomeado no check.
    """
    m = _FILTRO_TERMINAL_RE.search(check)
    if not m:
        return False
    portador = str(expect).strip() if expect and str(expect).strip() else m.group(1).strip()
    if not portador:
        return False
    portador = portador.strip("'\"")
    if not portador:
        return False
    for produtor_re, saidas in _VOCABULARIO_DE_FALHA:
        if not produtor_re.search(check):
            continue
        for saida in saidas:
            try:
                if re.search(portador, saida, re.IGNORECASE):
                    return True
            except re.error:
                if portador in saida:
                    return True
    return False


def tautological_reasons(check: str, expect=None) -> list[str]:
    """Motivos pelos quais este critério não consegue ficar vermelho.

    Lista vazia = falsificável. Nunca levanta.
    """
    text = str(check or "")
    if not text.strip():
        return []
    has_expect = expect is not None and str(expect).strip() not in ("", "True", "true")
    reasons: list[str] = []
    for name, pattern, needs_missing_expect in _PATTERNS:
        if needs_missing_expect and has_expect:
            continue
        if pattern.search(text):
            reasons.append(name)

    # TCK-2480: independente da isenção acima — é a única regra que pergunta
    # se a saída de FRACASSO satisfaz o critério, em vez de olhar a forma.
    if _expect_casa_saida_de_falha(text, expect):
        reasons.append("expect-casa-saida-de-falha")

    # TCK-1679: contador que espera ZERO nunca fica VERDE.
    #
    # `grep -c` / `rg -c` sem match saem **1** e não imprimem nada. Um critério
    # `rg -c '<padrão>'` com `expect: "^0$"` é, portanto, estruturalmente
    # impossível: quando o fato é verdadeiro (zero ocorrências), o comando falha.
    #
    # É o INVERSO do tautológico — em vez de nunca ficar vermelho, nunca fica
    # verde. Igualmente inútil e pior na prática: trava o ticket para sempre e
    # parece defeito do código.
    #
    # A regra `grep-c-sem-expect` não cobria: ela só dispara quando NÃO há
    # expect, e aqui há. Escrevi este mesmo check duas vezes na sessão de
    # 2026-08-02/03 (TCK-1612 e TCK-1620) sem o linter reclamar.
    #
    # Remédio: comando cujo EXIT CODE carregue o veredito (`python -c` com
    # `sys.exit`), em vez de contar linhas.
    if has_expect and re.search(r"\b(?:grep|rg|ripgrep)\s+(?:-\w*c\w*|--count)\b", text):
        alvo = str(expect).strip()
        if re.fullmatch(r"\^?0\$?|0", alvo):
            reasons.append("contador-esperando-zero-nunca-fica-verde")
    return reasons


def is_tautological(check: str, expect=None) -> bool:
    return bool(tautological_reasons(check, expect))


def audit_acceptance(acceptance: list) -> list[dict]:
    """Itens tautológicos de um `acceptance[]`, com o motivo de cada um."""
    out: list[dict] = []
    for index, item in enumerate(acceptance or [], 1):
        if not isinstance(item, dict):
            continue
        check = str(item.get("check", ""))
        reasons = tautological_reasons(check, item.get("expect"))
        if reasons:
            out.append({"index": index, "check": check[:160], "reasons": reasons})
    return out
