#!/usr/bin/env python3
"""P10 mecanizado (TCK-2127 / DES-1046): VER novo não pode ser auto-assinado.

Medido em 2026-08-07 (FND-agentes-hooks-p10): 92% dos VER traziam
`verified_by` igual ao `operator:` do RUN — o produtor hardcodava "ops"
(lib/artifacts.py) e nenhum código consumia o P10. As 3 janelas do ratchet
de autonomia (60/60 decisões) apontavam para tickets de verify auto-assinado:
a precisão de 0,95 não distinguia "a decisão foi certa" de "eu julguei minha
decisão certa".

Contrato (decisão do operador, 2026-08-07: bloqueante já):
- VER cujo id está em `.archagents/.p10-baseline.json` NUNCA reprova
  (os históricos são fato consumado; o baseline é COMPUTADO do disco por
  `--write-baseline`, nunca digitado).
- VER novo:
    ok        verified_by e operator legíveis e DIFERENTES
    achado    iguais, verified_by vazio, ou VER sem `run:` (fail-closed:
              sem procedência não há como provar independência)
    quebrado  `run:` aponta para RUN ilegível/ausente — medição quebrada,
              LISTADA, nunca conta como ok (terceiro estado)

Consumidores (cabeado em DOIS pontos — gate só no handoff é decorativo, 3×):
- `lib/ticket.py` transition --to done  → modo `--ver <id>` (rc 0/1/3)
- CI via audit-measure                  → modo varredura (exit 0 só se
                                          achado=0 e quebrado=0)

Piso do CI: stdlib puro — o CI instala requirements.lock, não o pacote;
import de lib/ops no topo quebraria o modo bloqueante.
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime
import re
import sys
from pathlib import Path

BASELINE_REL = ".archagents/.p10-baseline.json"
REPORTS_REL = ".archagents/14-verify/reports"
RUNS_REL = ".archagents/13-execution/runs"

_FM_KEY = {
    "id": re.compile(r"^id:\s*(.+?)\s*$", re.M),
    "run": re.compile(r"^run:\s*(.+?)\s*$", re.M),
    "verified_by": re.compile(r"^verified_by:\s*(.+?)\s*$", re.M),
    "operator": re.compile(r"^operator:\s*(.+?)\s*$", re.M),
    "ticket": re.compile(r"^ticket:\s*(.+?)\s*$", re.M),
    # TCK-2572 (`--adopt-pre-gate`): o corte da adoção é por timestamp do
    # disco. Os três nomes existem no acervo e a precedência entre eles segue a
    # do `_find_valid_fresh_ver`.
    "date": re.compile(r"^date:\s*(.+?)\s*$", re.M),
    "created_at": re.compile(r"^created_at:\s*(.+?)\s*$", re.M),
    "verified_at": re.compile(r"^verified_at:\s*(.+?)\s*$", re.M),
}


def _frontmatter(path: Path) -> str:
    """Só o bloco entre os `---` iniciais — corpo pode citar os campos em prosa."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    if not text.startswith("---"):
        return ""
    end = text.find("\n---", 3)
    return text[: end + 4] if end != -1 else ""


def _campo(fm: str, chave: str) -> str:
    m = _FM_KEY[chave].search(fm)
    if not m:
        return ""
    return m.group(1).strip().strip('"').strip("'")


def _norm(valor: str) -> str:
    return valor.strip().lower()


#: Identidades que SÃO quem executa, qualquer que seja o `operator` do RUN.
#:
#: Lista curta e fechada de propósito. Não é vocabulário de `verified_by` — o
#: censo mostrou 114 valores distintos, 97 deles únicos, e fechar isso exigiria
#: migrar 347 documentos. É o complemento: os poucos nomes cuja presença já
#: responde à pergunta, sem precisar saber quem são todos os outros.
#:
#: Recém-chegado não é acusado nem absolvido em silêncio: a lista é medida por
#: `test_identidades_do_executor_cobre_o_acervo`, que varre os VERs fora do
#: baseline e reprova se aparecer identidade nova que signifique execução.
IDENTIDADES_DO_EXECUTOR = frozenset({
    "executor", "ops", "codebase-ops-executor", "self", "mesmo-agente",
    "o executor", "quem executou",
})


#: Pontuação que separa NOME de COMENTÁRIO. O hífen só entra quando cercado de
#: espaços — `subagent-fresh-context` é um nome, `executor - declarado` são dois
#: pedaços.
_SEPARADOR = re.compile(r"[(,;:—–]|\s+-\s+")


def _identidade(verified_by: str) -> str:
    """O nome, sem a anotação.

    `subagent-fresh-context (verify adversarial que REJEITOU a v1)` tem
    identidade `subagent-fresh-context`: o parêntese é comentário do
    verificador sobre o próprio trabalho, e 11 dos 14 VERs em prosa fora do
    baseline têm exatamente essa forma. Cortar no primeiro separador põe o nome
    de um lado e o comentário do outro sem precisar entender o comentário.

    A v1 cortava só em `(` e `,`. Um verificador independente enumerou o que
    escapava: `executor — P10 nao satisfeito`, `executor - declarado`,
    `executor: declarado`, `executor; quem executou`. Todas são a MESMA
    confissão com outra pontuação, e todas saíam `ok` — falso negativo, que é
    a direção que este ticket chama de pior.

    O hífen fica de FORA da lista de separadores porque ele é parte dos nomes:
    `subagent-fresh-context`, `verificador-fresco-tck2553`,
    `independent-reviewer`. Cortá-lo cru devolvia `subagent`, `verificador`,
    `independent` — sem falso positivo hoje (nenhum está na lista), mas medindo
    o prefixo em vez do nome. Só conta como separador quando vem CERCADO DE
    ESPAÇOS (` - `), que é pontuação de frase, não de identificador.
    """
    return _norm(_SEPARADOR.split(verified_by, maxsplit=1)[0])


#: Nascimento deste gate, em UTC. `git show -s --format=%cI 592526fe` devolve
#: `2026-08-07T01:38:58-03:00`, que é `04:38:58Z` — e a conversão importa: um
#: VER de `03:10:45Z` PRECEDE o gate em 1h28, mas comparado com o `01:38` local
#: pareceria posterior. Terceira vez na mesma sessão que local-vs-UTC quase
#: inverteu uma conclusão (é literalmente o TCK-2571).
NASCIMENTO_DO_GATE = "2026-08-07T04:38:58+00:00"


def _e_anterior_ao_gate(fm: str) -> bool:
    """O VER foi escrito antes de este predicado existir?

    Fail-closed em tudo que não der para provar: timestamp ausente, ilegível ou
    SEM FUSO devolve `False` — e portanto o VER é julgado normalmente. Sem fuso
    não é "antigo", é não-comparável (TCK-2571), e não-comparável nunca pode
    virar absolvição por omissão.
    """
    bruto = next((_campo(fm, c) for c in ("date", "created_at", "verified_at")
                  if _campo(fm, c)), "")
    if not bruto:
        return False
    try:
        quando = datetime.fromisoformat(bruto.strip().replace("Z", "+00:00"))
    except ValueError:
        return False
    if quando.tzinfo is None:
        return False
    return quando < datetime.fromisoformat(NASCIMENTO_DO_GATE)


def _operator_do_run(root: Path, run_id: str) -> tuple[str, str]:
    """(operator, motivo_se_quebrado). REPORT.md primeiro; run.json fallback."""
    run_dir = root / RUNS_REL / run_id
    if not run_dir.is_dir():
        # Defesa em profundidade, não caminho vivo: desde o TCK-2476 o
        # `_classifica` intercepta run ausente mais cedo (vira `run-alheio`) e
        # só chega aqui com diretório existente. A guarda fica porque a função
        # é chamável de fora do `_classifica` — mas quem lê o gate deve saber
        # que o rótulo "RUN ausente" não é mais o que o operador vê.
        return "", f"RUN ausente: {run_dir.name}"
    report = run_dir / "REPORT.md"
    if report.is_file():
        op = _campo(_frontmatter(report), "operator")
        if op:
            return op, ""
    run_json = run_dir / "run.json"
    if run_json.is_file():
        try:
            op = str(json.loads(run_json.read_text(encoding="utf-8")).get("operator") or "")
            if op.strip():
                return op.strip(), ""
        except (OSError, json.JSONDecodeError) as e:
            return "", f"run.json ilegível: {e}"
    return "", "RUN sem campo operator legível (REPORT.md/run.json)"


def _classifica(root: Path, ver_path: Path) -> tuple[str, str]:
    """-> (estado, motivo) em {ok, achado, run-alheio, quebrado}."""
    fm = _frontmatter(ver_path)
    if not fm:
        return "quebrado", "frontmatter ausente/ilegível"
    verified_by = _campo(fm, "verified_by")
    run_id = _campo(fm, "run")
    if not run_id:
        # fail-closed deliberado: sem procedência não há independência a provar
        return "achado", "VER sem `run:` vinculado — independência improvável"
    # TCK-2476, TERCEIRO ESTADO. 81 VERs de uma campanha em lote citam
    # `RUN-TCK-0001e-kiro-research` — run de OUTRO ticket, usado como
    # placeholder porque `create_verify_report` exigia `--run` e não havia run
    # próprio. Os checks rodaram (≈311, com 103 REFUSED/FAIL); o que falta é
    # PROCEDÊNCIA, não independência. Contá-los como auto-assinados mistura
    # duas dívidas de natureza diferente e faz o número da independência
    # mentir nos dois sentidos: infla o problema aqui e esconde o de schema.
    # `run-alheio` não é `ok` — entra no relatório e no baseline como classe
    # própria, com remédio próprio (TCK-2476 no produtor).
    # A porta vem ANTES de `verified_by` de propósito: quando a procedência
    # está quebrada, `verified_by vazio` é verdade mas é o sintoma menor —
    # sem run legítimo não existe `operator` contra quem comparar, então a
    # independência sequer é DECIDÍVEL. Rotular isso de "auto-assinado" é
    # afirmar mais do que se mediu.
    ticket_ver = _ticket_do_ver(fm)
    if not (root / RUNS_REL / run_id).is_dir():
        return "run-alheio", (
            f"cita {run_id}, que não existe em {RUNS_REL} — procedência "
            f"inexistente; independência indecidível (não é auto-assinatura)")
    ticket_run = _ticket_do_run(root, run_id)
    if ticket_ver and ticket_run and ticket_run != ticket_ver:
        return "run-alheio", (
            f"o VER é de {ticket_ver} mas cita {run_id}, que é de "
            f"{ticket_run} — dívida de SCHEMA (procedência), não de "
            f"independência")
    if not verified_by:
        return "achado", "verified_by vazio"
    operator, motivo = _operator_do_run(root, run_id)
    if motivo:
        return "quebrado", motivo
    if _norm(verified_by) == _norm(operator):
        return "achado", (f"auto-assinado: verified_by={verified_by!r} == "
                          f"operator={operator!r} do {run_id}")
    # TCK-2572. A desigualdade de string era o predicado INTEIRO, e ela mede
    # grafia, não identidade. Um VER desta sessão trazia
    #
    #     verified_by: executor (P10 nao satisfeito — declarado)
    #
    # contra `operator: ops`. Strings diferentes -> `ok`. O gate leu uma
    # CONFISSÃO e classificou como prova de independência, e errou na direção
    # aberta: falso negativo é silêncio, não incômodo.
    #
    # Censo do acervo (347 VERs, 114 valores distintos, 97 deles únicos):
    # vocabulário fechado é inviável de retroajustar. Mas fora do baseline as
    # identidades caem em duas famílias e só duas — `subagent-fresh-*` /
    # `verificador-fresco-*` / `independent-*`, que são verificadores
    # declarados, e `executor`/`ops`, que são quem executou. A anotação entre
    # parênteses é comentário; a identidade é o token que vem antes.
    # TCK-2572, QUINTO ESTADO — e a segunda tentativa de resolver isto.
    #
    # Endurecer o predicado tornou achado um VER de 2026-08-07 que ninguém
    # tinha como prever: `verified_by: ops` contra `operator: cristiano` passava
    # por desigualdade de string. Ele é anterior ao próprio gate.
    #
    # A v1 desta correção ADOTAVA o id no `.p10-baseline.json`. O
    # `check-baseline-ratchet` reprovou na hora, e com razão: "baseline só
    # encolhe" (P9) é invariante forte, e abrir exceção computada continua
    # sendo abrir exceção. Escrever no baseline para caber no gate é o gesto
    # que o gate existe para impedir.
    #
    # A resposta certa não guarda nada: o disco já sabe a data do VER e o git
    # já sabe a data do gate. Anterioridade é COMPUTÁVEL a cada execução, não
    # precisa de lista. Sem entrada, sem crescimento, sem manutenção — e a
    # dívida continua VISÍVEL no relatório, como classe própria.
    if _e_anterior_ao_gate(fm):
        return "pre-gate", (
            f"VER anterior ao nascimento do gate ({NASCIMENTO_DO_GATE}) — o "
            f"predicado que o acusa não existia quando ele foi escrito")
    if _identidade(verified_by) in IDENTIDADES_DO_EXECUTOR:
        return "achado", (
            f"verified_by={verified_by!r} declara a própria execução — "
            f"identidade {_identidade(verified_by)!r} É quem executa; "
            f"diferir de operator={operator!r} não torna a assinatura "
            f"independente")
    return "ok", f"verified_by={verified_by!r} != operator={operator!r}"


def _ticket_do_ver(fm: str) -> str:
    return _campo(fm, "ticket")


def _ticket_do_run(root: Path, run_id: str) -> str:
    """O ticket que o RUN declara. `""` = não deu para ler — nunca acusa."""
    d = root / ".archagents" / "13-execution" / "runs" / run_id
    rj = d / "run.json"
    if rj.is_file():
        try:
            return str(json.loads(rj.read_text(encoding="utf-8")).get("ticket") or "")
        except (OSError, json.JSONDecodeError):
            return ""
    rep = d / "REPORT.md"
    if rep.is_file():
        try:
            return _campo(_frontmatter(rep) or "", "ticket")
        except OSError:
            return ""
    return ""


def _carrega_baseline(root: Path) -> set[str]:
    p = root / BASELINE_REL
    if not p.is_file():
        return set()
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return {str(v) for v in data.get("ver_ids", [])}
    except (OSError, json.JSONDecodeError):
        # baseline ilegível ≠ baseline vazio: reportar alto, tratar como vazio
        # (fail-closed: mais VERs viram "novos", nunca menos)
        print("AVISO: baseline ilegível — tratando todos os VERs como novos",
              file=sys.stderr)
        return set()


def _todos_os_vers(root: Path) -> list[Path]:
    d = root / REPORTS_REL
    return sorted(d.glob("VER-*.md")) if d.is_dir() else []


def cmd_write_baseline(root: Path) -> int:
    destino = root / BASELINE_REL
    if destino.exists():
        print(f"baseline já existe ({destino}) — recusa a sobrescrever; "
              f"o congelamento é one-shot (append-only)", file=sys.stderr)
        return 1
    ids = []
    for p in _todos_os_vers(root):
        vid = _campo(_frontmatter(p), "id") or p.stem
        ids.append(vid)
    payload = {
        "reason": "TCK-2127/DES-1046: congela os VERs pré-gate; novos exigem "
                  "verified_by != operator do RUN",
        "ver_ids": sorted(ids),
    }
    destino.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
                       encoding="utf-8")
    print(f"baseline escrito: {len(ids)} VER(s) congelado(s) em {destino}")
    return 0


def cmd_um_ver(root: Path, ver_id: str) -> int:
    """rc 0 ok / 1 achado / 3 quebrado — consumido por transition --to done."""
    nome = ver_id if ver_id.endswith(".md") else f"{ver_id}.md"
    path = root / REPORTS_REL / nome
    if not path.is_file():
        print(f"quebrado: VER não encontrado: {path}")
        return 3
    vid = _campo(_frontmatter(path), "id") or path.stem
    if vid in _carrega_baseline(root):
        print(f"ok: {vid} está no baseline (pré-gate)")
        return 0
    estado, motivo = _classifica(root, path)
    print(f"{estado}: {vid} — {motivo}")
    # rc 4 = `run-alheio`. Bloqueia como achado — o produtor já o impede desde
    # o TCK-2476, então VER novo nessa forma é regressão. O rc é PRÓPRIO porque
    # o consumidor precisa dizer o remédio certo: separar as classes só no
    # relatório e devolver rc 1 faria `transition_ticket` responder "spawne
    # verificador fresco" a um problema de procedência, que verificador fresco
    # nenhum conserta. É a classe `proxy-of-the-signal-not-the-signal`:
    # medir certo e comunicar errado.
    return {"ok": 0, "pre-gate": 0, "achado": 1, "run-alheio": 4,
            "quebrado": 3}[estado]


def cmd_explain(root: Path, as_json: bool) -> int:
    """A composição da dívida, baseline incluído. Diagnóstico, nunca gate:
    sai sempre rc 0 — quem bloqueia é a varredura."""
    baseline = _carrega_baseline(root)
    por_classe: dict[str, list[tuple[str, str, bool]]] = {}
    for p in _todos_os_vers(root):
        vid = _campo(_frontmatter(p), "id") or p.stem
        estado, motivo = _classifica(root, p)
        por_classe.setdefault(estado, []).append((vid, motivo, vid in baseline))
    rel = {c: {"total": len(v), "congelados": sum(1 for _, _, b in v if b),
               "ativos": sum(1 for _, _, b in v if not b)}
           for c, v in sorted(por_classe.items())}
    if as_json:
        print(json.dumps({"estados": rel, "baseline_total": len(baseline)},
                         indent=2, ensure_ascii=False))
    else:
        for classe, n in rel.items():
            print(f"{classe}: total={n['total']} congelados={n['congelados']} "
                  f"ativos={n['ativos']}")
    return 0


def cmd_varredura(root: Path, as_json: bool) -> int:
    baseline = _carrega_baseline(root)
    ok, achados, quebrados, congelados, alheios = [], [], [], [], []
    # TCK-2572: balde PRÓPRIO, nunca somado a `ok`. Um VER anterior ao gate
    # não é 'independente' — é 'não julgável por um predicado que não existia'.
    # Somá-lo a `ok` inflaria a independência medida; escondê-lo apagaria a
    # dívida. Sai contado e nomeado, e não bloqueia.
    pre_gate = []
    for p in _todos_os_vers(root):
        vid = _campo(_frontmatter(p), "id") or p.stem
        if vid in baseline:
            congelados.append(vid)
            continue
        estado, motivo = _classifica(root, p)
        {"ok": ok, "achado": achados, "quebrado": quebrados,
         "run-alheio": alheios,
         "pre-gate": pre_gate}[estado].append((vid, motivo))
    if as_json:
        print(json.dumps({
            "ok": len(ok), "achado": len(achados), "quebrado": len(quebrados),
            "run_alheio": len(alheios), "pre_gate": len(pre_gate),
            "baseline": len(congelados),
            "achados": [{"ver": v, "motivo": m} for v, m in achados],
            "quebrados": [{"ver": v, "motivo": m} for v, m in quebrados],
            "run_alheios": [{"ver": v, "motivo": m} for v, m in alheios],
        }, indent=2, ensure_ascii=False))
    else:
        print(f"p10: ok={len(ok)} achado={len(achados)} "
              f"run-alheio={len(alheios)} quebrado={len(quebrados)} "
              f"pre-gate={len(pre_gate)} baseline={len(congelados)}")
        for vid, motivo in achados:
            print(f"  ! {vid}: {motivo}")
        for vid, motivo in alheios:
            print(f"  @ {vid}: {motivo}")
        for vid, motivo in quebrados:
            print(f"  ~ {vid}: {motivo}")
    return 1 if (achados or alheios or quebrados) else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", type=Path, default=Path("."))
    ap.add_argument("--ver",
                    help="checa UM VER (rc 0 ok / 1 achado / 3 quebrado / "
                         "4 run-alheio)")
    ap.add_argument("--write-baseline", action="store_true",
                    help="congela os VERs atuais (one-shot, recusa overwrite)")
    ap.add_argument("--json", action="store_true", dest="as_json")
    ap.add_argument("--explain-estados", action="store_true",
                    dest="explain",
                    help="classifica IGNORANDO o baseline e informa quanto de "
                         "cada classe está congelado. Sem isto, o gate mostra "
                         "sempre zero e a composição da dívida fica invisível "
                         "— foi preciso medir à mão duas vezes para descobrir "
                         "que 151 dos 454 eram procedência, não independência.")
    args = ap.parse_args(argv)
    root = args.root.resolve()
    if not (root / ".archagents").is_dir():
        print(f"quebrado: {root} sem .archagents/ — raiz errada?", file=sys.stderr)
        return 3
    if args.write_baseline:
        return cmd_write_baseline(root)
    if args.ver:
        return cmd_um_ver(root, args.ver)
    if args.explain:
        return cmd_explain(root, args.as_json)
    return cmd_varredura(root, args.as_json)


if __name__ == "__main__":
    raise SystemExit(main())
