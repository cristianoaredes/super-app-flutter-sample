#!/usr/bin/env python3
"""
pipeline-judge.py — Juiz pós-entrega. Analisa RUN + VER + diff, emite verdict,
extrai licoes aprendidas, e armazena na memoria coletiva (Cognee ou local).

Uso:
  python3 scripts/pipeline-judge.py --ticket TCK-NNNN [--run RUN-NNNN] [--verdict-file verdict.json]

Verdict JSON output:
  {
    "ticket": "TCK-NNNN",
    "run": "RUN-NNNN",
    "overall": "EXCELLENT|ACCEPTABLE|NEEDS_IMPROVEMENT|REJECTED",
    "score": 0-100,
    "dimensions": {
      "spec_compliance": {"score": 0-100, "notes": "..."},
      "code_quality": {"score": 0-100, "notes": "..."},
      "test_coverage": {"score": 0-100, "notes": "..."},
      "safety": {"score": 0-100, "notes": "..."},
      "documentation": {"score": 0-100, "notes": "..."},
      "objective_alignment": {"score": 0-100|null, "objective": "SPC-NNNN"|null,
                              "notes": "..."}
    },
    "objective_alignment": 0-100|null,
    "what_went_right": ["..."],
    "what_went_wrong": ["..."],
    "root_causes": ["..."],
    "lessons": [
      {"lesson": "...", "severity": "high", "affected_tickets": ["..."]}
    ],
    "recommendations": ["..."],
    "recommendation_tickets": ["TCK-NNNN"]
  }

O verdict é armazenado em .archagents/99-memory/ via lib.memstore (JSON canônico)
e indexado em .archagents/.index.db via lib.db (SQLite/BM25). O cognee-adapter.py
é ponto de extensão fallback-only, fora do caminho quente (TCK-2688).
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

import shlex
import sys
from pathlib import Path
from lib.cmd_utils import CmdExecutor
from lib.lesson_utility import compute_lesson_utility
from lib.report_utils import now_utc  # TCK-0559
from lib.runstate import ensure_loop_telemetry, resolve_run_for_ticket, LOOP_TELEMETRY_FIELDS
from lib.strategy import compute_effectiveness
from lib.obs import warn_telemetry
from lib.ops_logging import setup_logging
from lib.recursion_guard import RecursionGuard  # TCK-0416/SPC-0054 — T6 delegation-chain guard

logger = setup_logging(name="pipeline-judge")

from lib.bootstrap import get_repo_root

REPO_ROOT = get_repo_root()
RUNS_DIR = REPO_ROOT / ".archagents" / "13-execution" / "runs"
VER_DIR = REPO_ROOT / ".archagents" / "14-verify" / "reports"
TICKETS_DIR = REPO_ROOT / ".archagents" / "15-backlog" / "tickets"
# TCK-1193/PLN-0017 D11: fontes dos objetivos (6ª dimensão do judge)
SPECS_DIR = REPO_ROOT / ".archagents" / "12-inception" / "specs"
PLANS_DIR = REPO_ROOT / ".archagents" / "12-inception" / "plans"
DESIGNS_DIR = REPO_ROOT / ".archagents" / "16-designs"

# CmdExecutor para execução de comandos
# TCK-0589: timeout 30s truncava o re-run interno de criteria (gate 5/5 visto
# como 2/3 — suítes pytest de acceptance levam >30s); 120s alinha com o
# criteria gate. max_retries=0 = 1 tentativa (semântica pós-TCK-0578).
executor = CmdExecutor(timeout=120, max_retries=0)


def persist_verdict_and_lessons(verdict: dict, ticket: str,
                                memory_dir: Path | None = None) -> None:
    """TCK-0457/SPC-0057-A8: persiste verdict+lições nos writers canônicos
    (lib.memstore / lib.db.add_lesson) em vez de subprocess com f-string sem
    shlex.quote e retorno nunca checado — lição com aspas no texto não some
    mais em silêncio (e o vetor de shell injection morre). Falha de
    persistência é logger.error (loud), nunca fatal para o judge."""
    import os
    if memory_dir is None:
        override = os.environ.get("CODEBASE_OPS_MEMORY_DIR")
        if override:
            memory_dir = Path(override)
        else:
            # TCK-1941: guarda hermética no PRODUTOR (a cura do TCK-0499).
            # Um teste que invoca o judge real — direto ou via _run_judge do
            # driver — herdaria este default, que é o repo DO FRAMEWORK, e
            # gravaria verdict espúrio na memória coletiva compartilhada.
            # Medido: TCK_0001.json (score 54, run None) nasceu na suíte e
            # foi COMMITADO sem ninguém perceber. Sob pytest, sem
            # redirecionamento explícito (argumento ou env), a persistência é
            # recusada em voz alta — o teste que precisar dela redireciona.
            if os.environ.get("PYTEST_CURRENT_TEST"):
                logger.error(
                    "TCK-1941: persistência de verdict RECUSADA sob pytest sem "
                    "CODEBASE_OPS_MEMORY_DIR/memory_dir — o default é a memória "
                    "REAL do framework; redirecione no teste.")
                return
            memory_dir = REPO_ROOT / ".archagents" / "99-memory"
    try:
        from lib.memstore import atomic_write_json, memory_lock
        vpath = memory_dir / "verdicts" / f"{ticket.replace('-', '_')}.json"
        with memory_lock(memory_dir):
            atomic_write_json(vpath, verdict)
    except Exception as e:
        logger.error("Persistência do verdict falhou (TCK-0457, loud): %s", e)
    try:
        from lib.db import add_lesson
    except Exception as e:
        logger.error("Persistência de lições indisponível (TCK-0457, loud): %s", e)
        return
    for lesson in verdict.get("lessons", []):
        try:
            add_lesson(lesson["lesson"],
                       affected_tickets=lesson.get("affected_tickets") or [ticket],
                       severity=lesson.get("severity", "medium"),
                       memory_dir_override=memory_dir)
        except Exception as e:
            logger.error("Persistência de lição falhou (TCK-0457, loud): %s", e)


def find_run(ticket_id: str, run_hint: str = None) -> Path:
    # SPC-0036/F0.6: delegate to the shared resolver — the prior strip-only rule
    # (`ticket.replace('-','') in name`) missed canonically-named tck-NNNN dirs.
    return resolve_run_for_ticket(RUNS_DIR, ticket_id, run_hint)


def find_ver(run_dir: Path) -> Path:
    if not run_dir:
        return None
    ver_candidates = [f for f in VER_DIR.iterdir() if run_dir.name in f.read_text()]
    if ver_candidates:
        return sorted(ver_candidates, key=lambda p: p.stat().st_mtime, reverse=True)[0]
    return None


DIFF_PATHSPEC = ("-- '*.py' '*.mjs' '*.ts' '*.md' '*.sh' "
                 "':(exclude).archagents/.index/*'")
_DIFF_EXTS = (".py", ".mjs", ".ts", ".md", ".sh")

# TCK-1138: sha de commit (curto ou completo) — filtra placeholders (`null`,
# "") e qualquer string não-hex antes de interpolar em comando git (TCK-0457).
_SHA_RE = re.compile(r"^[0-9a-fA-F]{4,40}$")


def _run_commit_shas(run_dir) -> list:
    """TCK-1138/DES-0746 (FND-0091): SHAs de commit registrados nos artefatos
    do run — run.json (`commits`) e/ou frontmatter do REPORT.md (`commits:`,
    lista de {sha, message, files} — contrato do verify-run.py). Entradas
    dict contribuem `sha`; entradas string contam como sha direto (tolerância
    a formatos legados). Retorna shas válidos, dedup, na ordem registrada.
    """
    if not run_dir:
        return []
    entries = []
    rj = run_dir / "run.json"
    if rj.exists():
        try:
            data = json.loads(rj.read_text())
            if isinstance(data, dict):
                entries.extend(data.get("commits") or [])
        except Exception:
            pass  # fail-open: run.json malformado nunca derruba o judge
    report = run_dir / "REPORT.md"
    if report.exists():
        try:
            from lib.frontmatter import parse_frontmatter
            fm = parse_frontmatter(
                report.read_text(encoding="utf-8", errors="replace"))
            entries.extend(fm.get("commits") or [])
        except Exception:
            pass  # fail-open idem
    shas = []
    for entry in entries:
        candidate = entry.get("sha") if isinstance(entry, dict) else entry
        if candidate is None:
            continue
        candidate = str(candidate).strip()
        if _SHA_RE.match(candidate) and candidate not in shas:
            shas.append(candidate)
    return shas


def _diff_for_commit_range(shas, runner) -> str:
    """TCK-1138: diff do ticket = união (concatenação) dos `git show` de cada
    commit do run, no pathspec canônico. Commits que não resolvem no repo
    atual (sha stale, repo diferente) são pulados; retorna "" quando NENHUM
    sha rendeu diff — o chamador então cai no fallback agregado (fail-open:
    metadata ruim nunca quebra o julgamento)."""
    parts = []
    for sha in shas:
        show = runner.run("git show " + shlex.quote(sha) + " " + DIFF_PATHSPEC)
        if show.success and show.stdout.strip():
            parts.append(show.stdout)
    return "\n".join(parts)


def diff_scope_note(diff_scope: str) -> "str | None":
    """TCK-1138/DES-0746: nota explicativa gravada no verdict quando o judge
    NÃO conseguiu resolver o diff do ticket e caiu no escopo agregado.

    O fallback agregado mede a ÁRVORE INTEIRA (trabalho WIP de N tickets em
    onda, ou trabalho já commitado que não está mais no diff HEAD), não a
    entrega do ticket — o verdict precisa declarar isso junto do
    low_confidence forçado (scoped_low_confidence). None para escopos
    resolvidos (run_artifact, ticket_range) e para head_minus_1 (que já tem
    low_confidence próprio)."""
    if diff_scope == "working_tree_aggregate":
        return ("diff agregado da árvore inteira — sem commits resolúveis nos "
                "artefatos do run (WIP não commitado ou metadata ausente; "
                "FND-0091): o verdict mede o estado da árvore, não "
                "necessariamente a entrega do ticket")
    return None


def resolve_judge_diff(run_dir, cmd=None, ticket_id=None):
    """TCK-0576/TCK-0702/TCK-1138: fonte do diff com consciência do fluxo
    commit-pós-verify.

    Ordem de resolução:
    (1) run_dir/diff.txt — artefato do run, confiável;
    (2) TCK-1138/DES-0746 (FND-0091): commits explícitos nos artefatos do run
        (run.json/REPORT.md `commits:`) — o trabalho do ticket pode já estar
        COMMITADO quando o judge roda; o diff do ticket é a união dos
        `git show` daquele range, não a árvore inteira;
    (3) working tree SUJO — o trabalho ainda não foi commitado (padrão
        dominante: commit é passo pós-verify), então `git diff HEAD` +
        untracked sintético é a verdade;
    (4) fallback `git diff HEAD~1` — pode ser um commit alheio ao run, então o
        verdict sai low_confidence=True para não poluir a memória coletiva com
        score enganoso (caso real: TCK-0567 — judge 64 vs VER adversarial 84).

    TCK-0702: a fonte 3 (working tree sujo) faz `git diff HEAD` da ÁRVORE
    INTEIRA — não filtra por ticket. Em modo onda (múltiplos tickets dirty
    simultaneamente, o padrão normal do framework, ADR-0013), TODAS as
    invocações `--ticket X` recebem o MESMO diff agregado e tendem ao MESMO
    score (reproduzido: onda-A2, 5 tickets, score idêntico 90/EXCELLENT nos
    5). Escopar o diff por ticket de verdade exigiria rastrear quais arquivos
    cada ticket tocou — a maioria dos tickets não registra isso hoje, então a
    correção aqui (effort=S) é TRANSPARÊNCIA, não precisão cirúrgica: o
    terceiro valor retornado (`diff_scope`) identifica a fonte usada, para
    que o chamador (`main()`) trate o caso agregado como não-diferenciador
    por ticket (força `low_confidence=True` quando
    `diff_scope == "working_tree_aggregate"`, via `scoped_low_confidence()`,
    e grava `diff_scope_note`, via `diff_scope_note()` — TCK-1138).

    Retorna (diff_text, low_confidence, diff_scope), onde diff_scope é um
    dentre:
      - "executor_delta"         — fonte 1a (TCK-1936), run_dir/diff-executor.txt:
                                    a AUTORIA do executor, sem os artefatos que o
                                    próprio ciclo escreveu em `.archagents/`.
                                    Medido: 255/655 linhas do diff do E4 eram
                                    REPORT/brief/playbook do driver, e os únicos
                                    TODO eram do template — o judge punia o agente
                                    por obra alheia. Preferida quando NÃO-vazia;
                                    vazia (entrega legítima dentro de .archagents)
                                    cai na fonte 1.
      - "run_artifact"           — fonte 1, run_dir/diff.txt.
      - "ticket_range"           — fonte 2, união dos commits do run
                                    (TCK-1138; diff por-ticket de verdade).
      - "working_tree_aggregate" — fonte 3, git diff HEAD da árvore inteira
                                    (caso problemático: sem filtro por ticket).
      - "head_minus_1"           — fonte 4, fallback git diff HEAD~1.
    """
    runner = cmd or executor
    if run_dir and (run_dir / "diff-executor.txt").exists():
        texto = (run_dir / "diff-executor.txt").read_text()
        if texto.strip():
            return texto, False, "executor_delta"
    if run_dir and (run_dir / "diff.txt").exists():
        return (run_dir / "diff.txt").read_text(), False, "run_artifact"

    # TCK-1138/DES-0746 (FND-0091): (a) commits explícitos nos artefatos do
    # run vencem o agregado — sem isso, runs commitados ANTES do judge (fluxo
    # commit-pós-verify) eram medidos pela árvore inteira e saíam
    # sistematicamente pessimistas ("0/N critérios identificados no diff").
    shas = _run_commit_shas(run_dir)
    if shas:
        ticket_diff = _diff_for_commit_range(shas, runner)
        if ticket_diff.strip():
            return ticket_diff, False, "ticket_range"
        # shas registrados mas nenhum resolveu/rendeu diff no repo atual —
        # cai para o fallback agregado com nota (fail-open).

    # TCK-2479 / ADR-0037: quarta fonte — os commits DO TICKET, resolvidos por
    # `lib/ticket_commits`. As três acima não têm produtor (1, 7 e 0 de 280
    # runs); esta resolve 88,4% do acervo sem exigir disciplina nova, porque a
    # convenção de commit já carrega o ID.
    if ticket_id:
        try:
            from lib.ticket_commits import commits_do_ticket
            # raiz RESOLVIDA, não `Path(".")`: fora da raiz o resolvedor
            # devolvia [] em silêncio e caía no agregado
            # (classe `worktree-root-resolution-trap`, achado F6 do verify).
            _raiz = runner.run("git rev-parse --show-toplevel")
            _base = Path(_raiz.stdout.strip()) if _raiz.success and _raiz.stdout.strip() else Path(".")
            do_ticket, fonte = commits_do_ticket(_base, ticket_id)
        except Exception:  # noqa: BLE001 — resolver é auxiliar, nunca derruba
            do_ticket, fonte = [], ""
        if do_ticket:
            ticket_diff = _diff_for_commit_range(do_ticket, runner)
            if ticket_diff.strip():
                return ticket_diff, False, f"ticket_commits:{fonte}"

    status = runner.run("git status --porcelain")
    if status.success and status.stdout.strip():
        tracked = runner.run("git diff HEAD " + DIFF_PATHSPEC)
        parts = [tracked.stdout if tracked.success else ""]
        untracked = runner.run("git ls-files --others --exclude-standard")
        if untracked.success:
            for rel in untracked.stdout.splitlines():
                rel = rel.strip()
                if not rel or not rel.endswith(_DIFF_EXTS):
                    continue
                try:
                    content = Path(rel).read_text(encoding="utf-8",
                                                  errors="replace")
                except OSError:
                    continue
                body = "".join(f"+{ln}\n"
                               for ln in content.splitlines()[:400])
                parts.append(f"diff --git a/{rel} b/{rel}\n"
                             f"new file mode 100644\n--- /dev/null\n"
                             f"+++ b/{rel}\n{body}")
        return "\n".join(p for p in parts if p), False, "working_tree_aggregate"

    result = runner.run("git diff HEAD~1 " + DIFF_PATHSPEC)
    return (result.stdout if result.success else ""), True, "head_minus_1"


def scoped_low_confidence(diff_scope: str, low_confidence: bool) -> bool:
    """TCK-0702: o diff agregado de árvore inteira (`diff_scope ==
    "working_tree_aggregate"`, fonte 2 de resolve_judge_diff — sem filtro por
    ticket) nunca deve ser tratado como diferenciador por-ticket em modo
    onda. Reusa `low_confidence`, campo que já existe e já tem a semântica
    "não confie cegamente neste score" (TCK-0576/TCK-0567), forçando-o para
    True mesmo quando a fonte 2 por si só devolveu False.
    """
    return True if diff_scope == "working_tree_aggregate" else low_confidence


def analyze_spec_compliance(ticket_id: str, diff_text: str) -> dict:
    """Analisa conformidade com a spec."""
    try:
        ticket_path = next(TICKETS_DIR.glob(f"{ticket_id}*.md"))
        content = ticket_path.read_text()
    except StopIteration:
        return {"score": 0, "notes": "Ticket não encontrado"}

    # Extrai acceptance criteria
    criteria = re.findall(r'check:\s*"([^"]+)"', content)
    if not criteria:
        criteria = re.findall(r'-\s+\[x\]\s+(.+)', content)

    score = 50  # baseline
    notes = []

    if criteria:
        # Verifica se palavras-chave da spec aparecem no diff
        keywords = [c.lower() for c in criteria if len(c) > 10]
        matches = sum(1 for kw in keywords if kw[:20] in diff_text.lower())
        ratio = matches / len(keywords) if keywords else 0
        score = int(50 + ratio * 50)
        notes.append(f"{matches}/{len(keywords)} critérios identificados no diff")
    else:
        notes.append("Nenhum critério de aceitação machine-verifiable encontrado")

    return {"score": min(score, 100), "notes": "; ".join(notes)}


# TCK-1193/PLN-0017 D11: divergência >= este delta entre spec_compliance e
# objective_alignment gera nota no verdict (entrega casa com o ticket mas
# diverge dos objetivos — autonomia nunca excede o alinhamento medido).
OBJECTIVE_GAP_THRESHOLD = 25


def _linked_objective_ids(ticket_content: str) -> list:
    """TCK-1193/D11: IDs SPC/PLN linkados ao ticket, em ordem determinística.

    Fontes, em precedência:
      (1) frontmatter `linked_spec:` / `linked_plan:` (escalar, lista inline
          `[SPC-0001]` ou lista multilinha);
      (2) `linked_designs:` cujos DES-NNNN referenciam uma SPC/PLN no corpo
          do design (o DES "traces to" a spec/plan).
    """
    ids = []

    def _add(kind: str, num: str) -> None:
        oid = f"{kind}-{num}"
        if oid not in ids:
            ids.append(oid)

    def _blobs(m) -> str:
        return " ".join(g for g in (m.group("inline"), m.group("scalar"),
                                    m.group("block")) if g)

    fm_re = (r"\blinked_(?:spec|plan)s?\s*:\s*"
             r"(?:\[(?P<inline>[^\]]*)\]|(?P<scalar>[^\n]*))"
             r"(?:\n(?P<block>(?:\s+-\s+[^\n]+\n?)*))?")
    for m in re.finditer(fm_re, ticket_content):
        for kind, num in re.findall(r"(SPC|PLN)-(\d{4})", _blobs(m)):
            _add(kind, num)
    if ids:
        return ids

    dm = re.search(fm_re.replace("linked_(?:spec|plan)s?", "linked_designs"),
                   ticket_content)
    if dm:
        for des in dict.fromkeys(re.findall(r"DES-\d{4}", _blobs(dm))):
            for des_path in sorted(DESIGNS_DIR.glob(f"{des}*.md")):
                try:
                    des_content = des_path.read_text(encoding="utf-8",
                                                     errors="replace")
                except OSError:
                    continue
                for kind, num in re.findall(r"(SPC|PLN)-(\d{4})", des_content):
                    _add(kind, num)
    return ids


def _load_objective_doc(objective_id: str) -> "str | None":
    """TCK-1193/D11: corpo da SPC/PLN linkada (specs/ ou plans/). Fail-open."""
    base = SPECS_DIR if objective_id.startswith("SPC-") else PLANS_DIR
    for path in sorted(base.glob(f"{objective_id}*.md")):
        if "questions" in path.name:
            continue  # SPC-NNNN-questions.md é artefato irmão, não a spec
        try:
            return path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
    return None


def analyze_objective_alignment(ticket_id: str, diff_text: str) -> dict:
    """TCK-1193/PLN-0017 D11 — 6ª dimensão: alinhamento OBJETIVO.

    Mede a entrega contra os objetivos (SPC/PLN) linkados ao ticket — não só
    contra o acceptance do próprio ticket (spec_compliance). Reusa a mesma
    abordagem mecânica de analyze_spec_compliance: critérios `check:`
    grep-able da spec/plan, procurados no diff.

    CONTRATO DE NULL: sem spec linkada (ou sem critérios machine-verifiable
    nela), score=None e a dimensão é EXCLUÍDA do agregado — ticket sem
    objetivo linkado NUNCA é penalizado."""
    null = {"score": None, "objective": None}
    try:
        ticket_path = next(TICKETS_DIR.glob(f"{ticket_id}*.md"))
        ticket_content = ticket_path.read_text()
    except StopIteration:
        return {**null, "notes": "null (ticket não encontrado — sem como "
                                 "resolver spec linkada)"}
    objective_ids = _linked_objective_ids(ticket_content)
    if not objective_ids:
        return {**null, "notes": "null (no linked spec)"}
    objective_id = objective_ids[0]
    doc = _load_objective_doc(objective_id)
    if doc is None:
        return {**null, "objective": objective_id,
                "notes": f"null ({objective_id} linkada mas arquivo não "
                         f"encontrado em specs/plans)"}

    # Mesma extração de critérios do spec_compliance
    criteria = re.findall(r'check:\s*"([^"]+)"', doc)
    if not criteria:
        criteria = re.findall(r'-\s+\[x\]\s+(.+)', doc)
    keywords = [c.lower() for c in criteria if len(c) > 10]
    if not keywords:
        return {**null, "objective": objective_id,
                "notes": f"null ({objective_id} sem critérios "
                         f"machine-verifiable — excluída, não penaliza)"}

    matches = sum(1 for kw in keywords if kw[:20] in diff_text.lower())
    ratio = matches / len(keywords)
    score = int(50 + ratio * 50)
    return {"score": min(score, 100), "objective": objective_id,
            "notes": f"{matches}/{len(keywords)} critérios de {objective_id} "
                     f"identificados no diff"}


def objective_divergence_note(dimensions: dict) -> "str | None":
    """TCK-1193/D11: quando a entrega CASA com o ticket (spec_compliance alta)
    mas DIVERGE dos objetivos linkados (objective_alignment baixa), o verdict
    precisa dizer isso explicitamente — autonomia nunca excede o alinhamento
    medido. None quando não há base de comparação (dimensão null)."""
    oa = (dimensions.get("objective_alignment") or {}).get("score")
    sc = (dimensions.get("spec_compliance") or {}).get("score")
    if oa is None or sc is None:
        return None
    if sc - oa >= OBJECTIVE_GAP_THRESHOLD:
        objective = (dimensions["objective_alignment"].get("objective")
                     or "spec linkada")
        return (f"objective_alignment ({oa}) diverge significativamente de "
                f"spec_compliance ({sc}): a entrega atende o ticket mas não "
                f"os objetivos de {objective} — autonomia NUNCA deve exceder "
                f"o alinhamento medido (PLN-0017 D11)")
    return None


def analyze_code_quality(diff_text: str, *, escopo_resolvido: bool = True) -> dict:
    r"""Qualidade por CLASSE DE ARQUIVO no diff (TCK-2479).

    O predicado antigo dava `+10` quando `\b(test_|_test\.py|spec\.)` aparecia
    em QUALQUER lugar do texto — inclusive num comentário `# ver test_foo`. Com
    teto 80, a dimensão não podia sinalizar excelência e a média plana tirava
    ~7 pontos de toda entrega. Medido: dp 5,8 em 216 vereditos.

    Agora: arquivo de teste tocado (por PATH) conta; o teto é 100; e escopo não
    resolvido devolve `None` — o terceiro estado do ADR-0037.
    """
    if not escopo_resolvido:
        return {"score": None, "notes": "diff scope unresolved — not measured (ADR-0037)"}
    _arqs = _arquivos_do_diff(diff_text)
    _testes = [a for a in _arqs if "test" in Path(a).name or a.startswith("tests/")]
    _codigo = [a for a in _arqs if a.endswith((".py", ".sh", ".js", ".ts"))
               and a not in _testes]
    score = 70
    notes = []

    # TCK-2479: arquivo de teste TOCADO (por path), não a palavra "test"
    # aparecendo em qualquer lugar do texto — um comentário `# ver test_foo`
    # ganhava os mesmos 10 pontos que uma suíte nova.
    if _testes and _codigo:
        score += 30
        notes.append(f"Test files present ({len(_testes)} for {len(_codigo)} code file(s))")
    elif _testes:
        score += 20
        notes.append(f"Test files present ({len(_testes)})")
    else:
        notes.append("No test files in diff")

    # Se diff muito grande, penaliza levemente
    lines = diff_text.count('\n')
    if lines > 500:
        score -= 5
        notes.append(f"Large diff ({lines} lines)")

    # Se tem TODO/FIXME no diff, penaliza
    todos = len(re.findall(r'TODO|FIXME|XXX', diff_text))
    if todos > 0:
        score -= min(todos * 3, 15)
        notes.append(f"{todos} TODO/FIXME markers")

    return {"score": max(0, min(100, score)), "notes": "; ".join(notes) if notes else "OK"}


def analyze_test_coverage(diff_text: str) -> dict:
    """Analiza cobertura de testes."""
    score = 50
    notes = []

    test_files = re.findall(r'\+.*(test_.*\.py|.*_test\.py|\.spec\.(ts|js))', diff_text, re.I)
    if test_files:
        score = 80
        notes.append(f"{len(set(test_files))} test files added/modified")
    else:
        notes.append("No test files detected in diff")

    # Verifica se há asserts/expect no diff
    asserts = len(re.findall(r'\b(assert|expect|should|it\()', diff_text))
    if asserts > 0:
        score += 10
        notes.append(f"{asserts} assertions/expectations")

    return {"score": min(100, score), "notes": "; ".join(notes)}


def analyze_safety(diff_text: str) -> dict:
    """Verifica sinais de risco no diff."""
    score = 100
    notes = []
    risks = []

    # Secrets — ATRIBUIÇÃO, não co-ocorrência a distância (TCK-1871).
    #
    # A v1 fazia duas buscas INDEPENDENTES no diff inteiro: bastava existir, em
    # qualquer lugar, uma string de 20+ chars e, em outro lugar qualquer, a
    # palavra `key`. Medido no piloto E5: um diff de `install.sh` sem segredo
    # nenhum levou −30, deixando o safety em 70 — o piso exato do judge-gate.
    # Passava por um fio, e por heurística ruim.
    #
    # Agora exige o par na MESMA linha: `<nome-com-key|token|secret|password>`
    # seguido de atribuição e de um literal longo. `api_key = "aaaa…"` continua
    # pego; `# gera a key do cache` mais um hash noutra linha, não.
    # As aspas em volta do NOME são opcionais: `"token": "…"` (JSON/YAML) tem
    # de casar tanto quanto `api_key = "…"`. A v1 usava `\b[\w.\-]*` e o `\b`
    # não atravessa a aspa — o caso JSON escapava, e foi o teste que pegou.
    _ATRIBUI_SEGREDO = re.compile(
        r'(?i)["\']?[\w.\-]*(key|token|secret|passwd|password)[\w.\-]*["\']?\s*'
        r'[:=]\s*["\']?[A-Za-z0-9_\-/+=]{20,}')
    if _ATRIBUI_SEGREDO.search(diff_text):
        risks.append("Potential secret pattern")
        score -= 30

    # Git destrutivo
    if re.search(r'git push --force|git reset --hard', diff_text):
        risks.append("Destructive git command in diff")
        score -= 50

    # rm -rf — o ALVO decide, não o comando (TCK-1859).
    #
    # A v1 acusava qualquer `rm -rf`. No piloto E5 isso bloqueou uma entrega
    # boa: o alvo era um `mktemp -d` limpo por `trap ... EXIT`, que é o idiom
    # de staging que o próprio repo adotou (`scripts/lib/atomic_dir.sh`).
    #
    # Um gate que acusa o idiom SEGURO ensina o time a ignorá-lo — e aí ele
    # não protege mais nada. Mas afrouxar seria pior: `rm -rf` sobre caminho do
    # operador continua sendo risco real, e o ratchet P9 vale.
    #
    # Então distingue-se o alvo: temporário criado e limpo no mesmo diff é
    # seguro; qualquer outro alvo permanece risco.
    for m in re.finditer(r'rm\s+-rf\s+("?\$?\{?[\w/.~-]+\}?"?)', diff_text):
        alvo = m.group(1).strip('"')
        var = alvo.lstrip("$").strip("{}")
        # SÓ o caso provado: variável que o próprio diff cria com `mktemp -d`.
        #
        # A v1 deste refino também absolvia `/tmp/` literal — e
        # `test_safety_penalizes_destructive_and_rm` (vigente) exige que
        # `rm -rf /tmp/x` continue valendo −20. Afrouxar um gate vigente exige
        # ADR (P9), e este ticket não é sobre isso: o falso positivo medido no
        # E5 era `mktemp -d` + `trap`, não caminho literal.
        #
        # Menos abrangente de propósito. `/tmp/algo` fixo pode ser qualquer
        # coisa; `$(mktemp -d)` é, por construção, um diretório que o próprio
        # script acabou de criar.
        temporario = bool(
            var and re.search(rf'{re.escape(var)}\s*=\s*"?\$\(\s*mktemp\s+-d', diff_text)
        )
        if not temporario:
            risks.append(f"rm -rf em alvo não-temporário ({alvo})")
            score -= 20
            break

    if risks:
        notes.append("RISKS: " + ", ".join(risks))
    else:
        notes.append("No safety risks detected")

    return {"score": max(0, score), "notes": "; ".join(notes)}


def _arquivos_do_diff(diff_text: str) -> list[str]:
    r"""Paths tocados, lidos do cabeçalho do diff — não do corpo.

    TCK-2479: o predicado antigo casava `\+.*\.md\b` no TEXTO, então
    `+++ b/README.md` (o próprio cabeçalho) e até uma string `'docs/guia.md'`
    dentro do código davam 80 de documentação. Em `working_tree_aggregate`
    isso era garantido: a árvore sempre tem `.archagents/**/*.md` do ciclo.
    """
    return re.findall(r"^\+\+\+ b/(.+)$", diff_text, re.M)


def analyze_documentation(diff_text: str, *, escopo_resolvido: bool = True) -> dict:
    """Docs por CLASSE DE ARQUIVO no diff.

    `escopo_resolvido=False` devolve `score: None` — o terceiro estado do
    ADR-0037: sem saber o que foi entregue, não se atribui nota. O
    `calculate_overall` já exclui `None` do denominador.
    """
    if not escopo_resolvido:
        return {"score": None, "notes": "diff scope unresolved — not measured (ADR-0037)"}
    arquivos = _arquivos_do_diff(diff_text)
    docs = [a for a in arquivos if a.endswith((".md", ".rst", ".txt"))
            and not a.startswith(".archagents/")]
    codigo = [a for a in arquivos if a.endswith((".py", ".sh", ".js", ".ts"))]
    notes = []
    if not arquivos:
        # sem cabeçalho `+++ b/` não significa "não medi": pode ser diff em
        # outro formato ou fragmento. `None` é reservado ao escopo não
        # resolvido (ADR-0037) — aqui a resposta honesta é a base.
        return {"score": 50, "notes": "No documentation changes"}
    if docs and codigo:
        score, nota = 100, f"Documentation updated ({len(docs)} doc(s) for {len(codigo)} code file(s))"
    elif docs:
        score, nota = 90, f"Documentation updated ({len(docs)} doc(s))"
    elif not codigo:
        score, nota = 80, "No code in diff — documentation not applicable"
    else:
        score, nota = 50, f"No documentation changes ({len(codigo)} code file(s))"
    notes.append(nota)

    return {"score": score, "notes": "; ".join(notes)}


def extract_what_went_right(run_dir: Path, ver_path: Path, verify_report: dict) -> list:
    """Extrai o que deu certo."""
    positives = []
    if verify_report:
        passed = verify_report.get("coverage", {}).get("passed", 0)
        total = verify_report.get("coverage", {}).get("total", 0)
        if passed == total and total > 0:
            positives.append(f"Todos os {total} critérios de aceitação passaram")
        elif passed > 0:
            positives.append(f"{passed}/{total} critérios de aceitação passaram")

    diff_stats = verify_report.get("diff_summary", {}) if verify_report else {}
    if diff_stats.get("files_changed", 0) > 0:
        positives.append(f"{diff_stats['files_changed']} arquivos alterados conforme especificado")

    return positives if positives else ["Execução concluída sem erros fatais"]


def extract_what_went_wrong(verify_report: dict, iterations: int) -> list:
    """Extrai o que deu errado."""
    negatives = []
    if not verify_report:
        return ["Nenhum relatório de verify disponível"]

    failed = verify_report.get("coverage", {}).get("failed", 0)
    errors = verify_report.get("coverage", {}).get("errors", 0)
    if failed > 0:
        negatives.append(f"{failed} critérios de aceitação falharam")
    if errors > 0:
        negatives.append(f"{errors} checks com erro de execução")
    if iterations > 1:
        negatives.append(f"Precisou de {iterations} iterações (re-execução)")

    for check in verify_report.get("checks", []):
        if check["status"] != "PASS":
            negatives.append(f"Check #{check['id']}: {check['check'][:60]}")

    return negatives if negatives else ["Nenhuma falha significativa detectada"]


def extract_root_causes(verify_report: dict, iterations: int) -> list:
    """Extrai causas raiz. Lista VAZIA quando a entrega é limpa (TCK-1137)."""
    causes = []
    if not verify_report:
        return causes

    # Se muitos checks deram ERROR, causa raiz = ambiente/comando
    errors = sum(1 for c in verify_report.get("checks", []) if c["status"] == "ERROR")
    if errors > 0:
        causes.append(f"{errors} checks com erro de execução — possível problema de ambiente ou script de teste")

    # Se falhou em arquivo específico
    for check in verify_report.get("checks", []):
        if check["status"] == "FAIL":
            if "test -f" in check["check"]:
                causes.append("Arquivo esperado não foi criado — escopo de implementação incompleto")
            elif "grep" in check["check"]:
                causes.append("Conteúdo esperado não encontrado — implementação não atende requisito")
            elif "wc -l" in check["check"] or "grep -c" in check["check"]:
                causes.append("Quantidade/count não bate — possível omissão ou duplicação")
            break  # Só primeira para não repetir

    if iterations >= 3:
        causes.append("Máximo de iterações atingido — spec pode estar ambígua ou esforço subestimado")

    # TCK-1137 / DES-0660 (FND-0089): NO placeholder fallback — when the judge
    # has nothing to say, root_causes stays empty. The old "Nenhuma causa raiz
    # identificada — entrega direta" string fed extract_lessons_hybrid, which
    # minted a "Root cause signal: <placeholder>" lesson (blind-era noise that
    # lib.db.add_lesson now quarantines at write time). No lesson > noise lesson.
    return causes


def extract_lessons(verify_report: dict, root_causes: list, ticket_id: str) -> list:
    """Extrai lições — TCK-0836: ExpeL contrast + evidence-tagged fallback.

    Replaces bare regex templates with contrast extraction when verdict history
    exists; heuristic fallbacks always carry an `evidence` field.
    """
    try:
        from lib.expel_lessons import extract_lessons_hybrid
        from lib.db import memory_dir
        return extract_lessons_hybrid(
            verify_report or {},
            root_causes or [],
            ticket_id,
            memory_dir=memory_dir(),
        )
    except Exception:
        # Fail-open: keep pipeline alive with evidence-tagged minimal lessons
        lessons = []
        if not verify_report:
            return lessons
        failed = [c for c in verify_report.get("checks", []) if c.get("status") == "FAIL"]
        errors = [c for c in verify_report.get("checks", []) if c.get("status") == "ERROR"]
        if failed:
            lessons.append({
                "lesson": "Acceptance checks failed — harden criteria/pre-flight",
                "severity": "medium",
                "affected_tickets": [ticket_id],
                "evidence": [f"verify-fail:{len(failed)}"],
            })
        if errors:
            lessons.append({
                "lesson": "Acceptance checks errored — make commands robust",
                "severity": "high",
                "affected_tickets": [ticket_id],
                "evidence": [f"verify-error:{len(errors)}"],
            })
        return lessons


def calculate_overall(dimensions: dict, verify_report: dict, iterations: int) -> tuple:
    """Calcula score geral e classificação."""
    # TCK-1193/D11: dimensões null (objective_alignment sem spec linkada)
    # são EXCLUÍDAS do denominador — nunca penalizam nem inflam a média.
    scores = [d["score"] for d in dimensions.values()
              if d.get("score") is not None]
    avg = sum(scores) / len(scores) if scores else 0

    # Ajustes
    if verify_report:
        cov = verify_report.get("coverage", {})
        if cov.get("total", 0) > 0 and cov.get("passed", 0) == cov["total"]:
            avg += 10
        if iterations > 1:
            avg -= 5 * (iterations - 1)

    score = max(0, min(100, int(avg)))

    if score >= 90:
        return "EXCELLENT", score
    elif score >= 75:
        return "ACCEPTABLE", score
    elif score >= 50:
        return "NEEDS_IMPROVEMENT", score
    else:
        return "REJECTED", score


# TCK-1222/PLN-0017 D9: classes de julgamento autônomo do ciclo do ticket
# cujos outcomes o judge fecha. Demais classes (handoff-gate, safety-stop,
# execute-dispatch, operator-stop...) não são medidas pelo verdict de entrega
# e ficam intocadas.
BACKFILL_DECISION_CLASSES = frozenset(
    {"triage", "design-approval", "done-closure"})

# Bandas do verdict → outcome do decision log (vocabulário de
# lib/decisions.py: "approved" ∈ CORRECT_OUTCOMES, "rejected" ∈
# INCORRECT_OUTCOMES — o ratchet lê precision a partir deles).
APPROVED_VERDICT_BANDS = ("EXCELLENT", "ACCEPTABLE")


def verdict_to_outcome(overall: str) -> str:
    """Banda do verdict → outcome: EXCELLENT/ACCEPTABLE → "approved";
    NEEDS_IMPROVEMENT/REJECTED → "rejected"."""
    return "approved" if overall in APPROVED_VERDICT_BANDS else "rejected"


def backfill_decision_outcomes(ticket_id: str, overall: str,
                               root: Path | None = None) -> dict:
    """TCK-1222/PLN-0017 D9: fecha o loop do decision log.

    Após o verdict, preenche `outcome` das decisões ABERTAS (outcome=null) do
    ticket nas classes triage/design-approval/done-closure, para que o
    ratchet (D5, decision_accuracy) meça precision real. human_review fica
    null — o outcome é máquina (o ratchet distingue machine-outcome de
    human-outcome), e decisões já revisadas por humano NUNCA são
    sobrescritas.

    Idempotente: só decisões com outcome=null são alvo; rodar o judge duas
    vezes não regrava nem corrompe nada (segundo run é no-op). Fail-open
    (loud): qualquer falha é logger.error + summary["error"], nunca quebra o
    judge — mesmo contrato de persist_verdict_and_lessons (TCK-0457)."""
    summary = {"outcome": verdict_to_outcome(overall), "updated": [],
               "skipped_human_review": [], "error": None}
    try:
        from lib import decisions as decisions_lib
        open_decisions = decisions_lib.find_open_decisions(
            ticket_id, root=root or REPO_ROOT)
        for record in open_decisions:
            if record.get("classe") not in BACKFILL_DECISION_CLASSES:
                continue
            if record.get("human_review"):
                summary["skipped_human_review"].append(record["id"])
                continue
            decisions_lib.update_decision_outcome(
                record["id"], summary["outcome"], human_review=None,
                root=root or REPO_ROOT)
            summary["updated"].append(record["id"])
    except Exception as e:
        summary["error"] = str(e)
        logger.error("Backfill de outcomes de decisões falhou "
                     "(TCK-1222, loud): %s", e)
    return summary


def attach_loop_telemetry(run_dir, score: int, runs_dir):
    """Compute + persist advisory loop telemetry for a run (SPC-0028 units 2/3).

    Reads run.json, writes lesson_utility + final_judge_delta (score vs neutral 50)
    back, and scores the run's loop strategy across runs. Returns
    (lesson_utility, strategy_effectiveness). The metrics are ADVISORY: any failure
    is surfaced via warn_telemetry and falls back to a neutral default — it never
    crashes the judge and never silently fakes a value (anti phantom-done).
    """
    lesson_utility = {"utility": 0.0, "n_lessons": 0}
    # TCK-2027: o fallback é o caso "não consegui medir" — `None`, não 0.0. O
    # docstring acima já promete "never silently fakes a value"; um 0.0 aqui era
    # exatamente um valor fingido, indistinguível de efetividade neutra medida.
    strategy_effectiveness = {"strategy": "default", "effectiveness": None, "n_runs": 0}

    if run_dir and (run_dir / "run.json").exists():
        try:
            rj_path = run_dir / "run.json"
            raw = json.loads(rj_path.read_text())
            rdata = ensure_loop_telemetry(raw)
            # TCK-1102 preservation guard: ensure_loop_telemetry FILLS absent
            # telemetry fields with contract defaults (by design — legacy runs),
            # but its type-guards can also REPLACE a present non-None value
            # (e.g. a string lessons_consulted would become a char list; a
            # stringified loop_iterations would be coerced). The judge attach
            # step must never destroy values the run's producer already
            # recorded: only fill what was missing; restore anything present.
            if isinstance(raw, dict):
                for _k in LOOP_TELEMETRY_FIELDS:
                    if raw.get(_k) is not None and rdata.get(_k) != raw[_k]:
                        rdata[_k] = raw[_k]
            # final_judge_delta is the judge's OWN measurement (score vs the
            # neutral-50 baseline) — the one telemetry field this writer
            # legitimately (re)writes on every pass.
            rdata["final_judge_delta"] = score - 50
            rdata["final_judge_delta_source"] = "judge"  # TCK-1234
            lesson_utility = compute_lesson_utility(rdata)
            rdata["lesson_utility"] = lesson_utility
            rj_path.write_text(json.dumps(rdata, indent=2, ensure_ascii=False))
        except Exception as e:
            warn_telemetry("judge.lesson_utility", e)

    try:
        all_runs = []
        if runs_dir and Path(runs_dir).is_dir():
            for rj in Path(runs_dir).glob("*/run.json"):
                try:
                    all_runs.append(json.loads(rj.read_text()))
                except Exception:
                    continue
        strat = "default"
        if run_dir and (run_dir / "run.json").exists():
            strat = json.loads((run_dir / "run.json").read_text()).get("loop_strategy", "default")
        strategy_effectiveness = compute_effectiveness(all_runs, strat)
    except Exception as e:
        warn_telemetry("judge.strategy_effectiveness", e)

    return lesson_utility, strategy_effectiveness


def is_efficient_delivery(overall: str, iterations: int,
                          verify_report: dict | None,
                          dimensions: dict) -> bool:
    """TCK-1181/PLN-0017 D7: gate de eficiência para lição POSITIVA.

    Uma entrega só qualifica como "eficiente" (digna de ensinar "what good
    looks like" à memória coletiva) quando TODAS as condições valem:
      (a) verdict aprovado — EXCELLENT (approved) ou ACCEPTABLE
          (approved-with-notes) no vocabulário do judge;
      (b) iterations == 1 — primeira passagem, sem rework;
      (c) pass rate de critérios 100% QUANDO existem critérios de aceitação
          (coverage.total > 0); sem critérios, a condição não se aplica;
      (d) nenhuma dimensão (incl. safety) abaixo do piso.
    Thresholds como constantes nomeadas no topo, fáceis de tunar."""
    APPROVED_OVERALLS = ("EXCELLENT", "ACCEPTABLE")  # approved / approved-with-notes
    MAX_ITERATIONS = 1                               # primeira passagem apenas
    REQUIRED_CRITERIA_PASS_RATE = 1.0                # 100% quando há critérios
    MIN_DIMENSION_SCORE = 70                         # piso por dimensão (incl. safety)

    if overall not in APPROVED_OVERALLS:
        return False
    if iterations > MAX_ITERATIONS:
        return False
    if verify_report:
        cov = verify_report.get("coverage", {}) or {}
        total = cov.get("total", 0)
        if total > 0 and (cov.get("passed", 0) / total) < REQUIRED_CRITERIA_PASS_RATE:
            return False
    # TCK-1193/D11: dimensões null são "não aplicáveis" (skip) — e o piso
    # passa a valer TAMBÉM para objective_alignment quando ela é medida
    # (autonomia nunca excede o alinhamento medido).
    if any((d or {}).get("score") is not None
           and (d or {}).get("score") < MIN_DIMENSION_SCORE
           for d in (dimensions or {}).values()):
        return False
    return True


def _derive_success_specifics(verify_report: dict | None, diff_text: str,
                              ticket_content: str | None,
                              has_playbook: bool) -> list:
    """TCK-1181: deriva as práticas CONCRETAS que caracterizaram a eficiência,
    a partir dos atributos reais do run — nunca genéricas (anti-noise)."""
    SMALL_SCOPE_MAX_FILES = 5    # até N arquivos = escopo pequeno
    MEDIUM_SCOPE_MAX_FILES = 20  # até N arquivos = escopo médio
    SMALL_SCOPE_MAX_LINES = 200  # fallback por tamanho do diff (sem diff_summary)

    specifics = []
    scope_recorded = False
    if verify_report:
        cov = verify_report.get("coverage", {}) or {}
        total, passed = cov.get("total", 0), cov.get("passed", 0)
        if total > 0 and passed == total:
            specifics.append(
                f"acceptance mecânico claro ({passed}/{total} checks PASS de primeira)")
        files = (verify_report.get("diff_summary", {}) or {}).get("files_changed", 0)
        if files:
            scope_class = ("pequeno" if files <= SMALL_SCOPE_MAX_FILES
                           else "médio" if files <= MEDIUM_SCOPE_MAX_FILES
                           else "grande")
            specifics.append(f"escopo {scope_class} ({files} arquivos)")
            scope_recorded = True
    if ticket_content and re.search(r'check:\s*"', ticket_content):
        specifics.append("critérios machine-verifiable (check:) no ticket")
    if not scope_recorded and diff_text:
        lines = diff_text.count("\n")
        if lines and lines <= SMALL_SCOPE_MAX_LINES:
            specifics.append(f"escopo pequeno (~{lines} linhas de diff)")
    if has_playbook:
        specifics.append("design com playbook antes de executar")
    return specifics


def extract_success_lesson(overall: str, iterations: int,
                           verify_report: dict | None, dimensions: dict,
                           diff_text: str, ticket_id: str,
                           ticket_content: str | None = None,
                           has_playbook: bool = False) -> "dict | None":
    """TCK-1181/PLN-0017 D7: lição POSITIVA para entrega notavelmente eficiente.

    O canal de lições hoje se alimenta quase só de FAILUREs — entregas
    eficientes não produzem nada e a memória nunca aprende "what good looks
    like". Quando a entrega passa no gate de eficiência (is_efficient_delivery),
    minta UMA lição positiva, severity low (reforço positivo ranqueia abaixo
    das falhas no ORDER BY, corretamente).

    Anti-noise (mesma política da supressão FND-0089): a lição precisa ser
    ESPECÍFICA — nomear as práticas concretas derivadas dos atributos reais
    do run. Se nada específico puder ser derivado, NÃO minta: no lesson >
    generic lesson. O texto específico também nunca casa com NOISE_PATTERNS
    (boilerplate blind-era), então passa pela quarentena de lib.db.add_lesson
    e entra no store canônico pelo mesmo write path das lições de falha.
    """
    LESSON_SEVERITY = "low"   # reforço positivo ranqueia abaixo de falhas
    LESSON_PREFIX = "Entrega eficiente em 1ª passagem"

    if not is_efficient_delivery(overall, iterations, verify_report, dimensions):
        return None
    specifics = _derive_success_specifics(verify_report, diff_text,
                                          ticket_content, has_playbook)
    if not specifics:
        return None  # anti-noise: no lesson > generic lesson
    return {
        "lesson": f"{LESSON_PREFIX}: " + "; ".join(specifics),
        "severity": LESSON_SEVERITY,
        "affected_tickets": [ticket_id],
        "evidence": ["success:first-pass"],
    }


def _read_ticket_content(ticket_id: str) -> "str | None":
    """TCK-1181: conteúdo do ticket para derivar estilo de acceptance (fail-open)."""
    try:
        return next(TICKETS_DIR.glob(f"{ticket_id}*.md")).read_text()
    except (StopIteration, OSError):
        return None


def _ticket_has_playbook(ticket_content: str | None) -> bool:
    """TCK-1181: True se algum DES-NNNN referenciado no ticket tem playbook em
    .archagents/16-designs/playbooks/ (design tinha playbook antes de executar)."""
    if not ticket_content:
        return False
    playbooks_dir = REPO_ROOT / ".archagents" / "16-designs" / "playbooks"
    return any((playbooks_dir / f"{des}-playbook.md").exists()
               for des in set(re.findall(r"DES-\d{4}", ticket_content)))


def main():
    parser = argparse.ArgumentParser(description="Juiz pós-entrega do pipeline")
    parser.add_argument("--ticket", required=True)
    parser.add_argument("--run", help="ID do RUN (auto-detectado se omitido)")
    parser.add_argument("--verdict-file", type=Path, help="Arquivo para salvar verdict")
    parser.add_argument("--json", action="store_true", help="Saída JSON")
    # TCK-0416/SPC-0054: delegation chain already traversed before this invocation
    # (e.g. pipeline-orchestrator.py forwards 'orchestrator,executor' after its own
    # run). Judge can also be invoked standalone — in that case the chain is empty
    # and this self-admission check trivially passes (depth 0 < default max 5).
    parser.add_argument("--agent-chain", default="",
                        help="(TCK-0416) Comma-separated delegation chain already "
                             "traversed before this invocation.")
    args = parser.parse_args()

    # TCK-0416/SPC-0054: recursion guard — self-admission check. This is the FIRST
    # governance gate (before run/ticket resolution) so judge refuses cleanly
    # whether invoked standalone or via pipeline-orchestrator.py. Fail-open is
    # preserved by RecursionGuard.check_delegation itself (internal errors return
    # allowed=True) — this block never lets a block become an unhandled exception
    # (SAFETY.md stop condition #8 / failed-fatal); it maps to paused-safety
    # instead, mirroring the existing paused-budget gate immediately below.
    _chain = [a.strip() for a in (args.agent_chain or "").split(",") if a.strip()]
    _decision = RecursionGuard().check_delegation("judge", _chain)
    if not _decision.allowed:
        logger.warning(
            "[TCK-0416] recursion guard BLOCKED judge invocation (chain=%s): %s",
            _chain, _decision.reason)
        logger.error("paused-safety: recursion guard blocked judge invocation — %s",
                     _decision.reason)
        # Best-effort: persist the recognizable paused-safety state into the
        # ticket's run.json when one is already resolvable. Never required for
        # the state to be "recognizable" — the stderr log above is the primary
        # channel (judge can run standalone with no run yet, same as the
        # existing paused-budget gate below).
        try:
            _run_dir = find_run(args.ticket, args.run)
            if _run_dir is not None and (_run_dir / "run.json").exists():
                _rj = _run_dir / "run.json"
                _rdata = json.loads(_rj.read_text())
                _rdata["final_status"] = "paused-safety"
                _rdata["paused_reason"] = f"recursion_guard[judge]: {_decision.reason}"
                _rj.write_text(json.dumps(_rdata, indent=2, ensure_ascii=False))
        except Exception as e:
            logger.warning("Failed to persist paused-safety status in run.json: %s", e)
        sys.exit(5)

    run_dir = find_run(args.ticket, args.run)
    ver_path = find_ver(run_dir) if run_dir else None

    # Budget gate: enforce_or_pause before any model-backed spend (F1.3/TCK-0312).
    # Judge analysis (dimension scoring, cognee verdict/lesson storage) constitutes
    # model spend. Fail-open: any budget.py error allows the judge to continue so
    # a cost-accounting failure never silently blocks post-delivery assessment.
    if run_dir is not None:
        try:
            from lib.pipeline_loop import budget_gate_or_halt
            if not budget_gate_or_halt(run_dir):
                logger.error("paused-budget: run budget cap exceeded — judge skipped")
                sys.exit(4)
        except Exception:
            pass  # fail-open: budget accounting error never blocks the judge

    # Carrega verify report
    verify_report = None
    iterations = 1
    if run_dir and (run_dir / "run.json").exists():
        run_data = json.loads((run_dir / "run.json").read_text())
        # TCK-2131: o contrato é `loop_iterations`; a chave crua `iterations`
        # (legado) com default 1 fabricava `success:first-pass` num run com 3
        # passos e um VER rejeitado no meio. O helper de runstate normaliza o
        # legado (runstate:265) — e `or 1` é o piso honesto: telemetria ausente
        # significa UMA passada, nunca "primeira tentativa comprovada".
        from lib.runstate import get_loop_iterations
        iterations = get_loop_iterations(run_data) or 1

    if ver_path:
        # Tenta extrair verify report do VER markdown ou busca JSON
        try:
            # Procura arquivo JSON relacionado
            json_candidates = list(ver_path.parent.glob(f"{ver_path.stem}*.json"))
            if json_candidates:
                verify_report = json.loads(json_candidates[0].read_text())
        except Exception:
            pass

    # Diff (limitado a 100KB, exclui indices grandes) — TCK-0576: resolução
    # consciente do fluxo commit-pós-verify (working tree > HEAD~1), com flag
    # de confiança quando o judge está cego. TCK-2131: resolvido ANTES do
    # fallback de verify, para que o fallback receba o diff que o judge JÁ tem.
    diff_text, low_confidence, diff_scope = resolve_judge_diff(
        run_dir, ticket_id=getattr(args, 'ticket', None))

    # Se não achou verify report, tenta rodar pipeline-verify
    if not verify_report:
        # TCK-0457: sem f-string em comando shell — input citado com shlex.quote
        # FUP-C (VER onda-2): sys.executable em vez de `python3` bare — o bare
        # pode ser um interpretador quebrado/abaixo do piso (3.9 nesta máquina)
        # e o fallback degradava em silêncio (exit 1 engolido).
        # TCK-2131: com diff resolvido, o verify o recebe via --diff-file (a
        # flag existia desde sempre; o caller é que não a usava) — sem isto o
        # verify afirmava "Nenhum arquivo alterado" contra um diff real.
        cmd = (shlex.quote(sys.executable) + " scripts/pipeline-verify.py --ticket "
               + shlex.quote(str(args.ticket)) + " --json")
        diff_tmp = None
        if diff_text.strip():
            import tempfile
            fd, diff_tmp = tempfile.mkstemp(prefix="judge-diff-", suffix=".patch")
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(diff_text)
            cmd += " --diff-file " + shlex.quote(diff_tmp)
        result = executor.run(cmd + " 2>/dev/null")
        if result.stdout:
            try:
                verify_report = json.loads(result.stdout)
            except json.JSONDecodeError:
                pass
        if diff_tmp:
            try:
                os.unlink(diff_tmp)
            except OSError:
                pass
    # TCK-0702: diff agregado de árvore inteira (modo onda) nunca diferencia
    # entre tickets — força low_confidence para o verdict final.
    low_confidence = scoped_low_confidence(diff_scope, low_confidence)
    # TCK-0589: 100KB truncava ondas reais (viu "1 test file" de 4 num diff de
    # 2295 linhas + docs) — 400KB cobre ondas multi-ticket; o marcador de
    # truncamento permanece para o VER detectar quando ainda estourar.
    if len(diff_text) > 400_000:
        diff_text = diff_text[:400_000] + "\n... (truncado, diff muito grande)"

    # Analisa dimensões
    # TCK-1193/D11: objective_alignment é a 6ª dimensão — mede a entrega
    # contra os objetivos (SPC/PLN) linkados, não só contra o ticket.
    dimensions = {
        "spec_compliance": analyze_spec_compliance(args.ticket, diff_text),
        # ADR-0037: escopo agregado = não resolvido. As dimensões devolvem
        # None e o calculate_overall as exclui do denominador, em vez de
        # diluir a média com medição feita no objeto errado.
        "code_quality": analyze_code_quality(
            diff_text, escopo_resolvido=diff_scope != "working_tree_aggregate"),
        "test_coverage": analyze_test_coverage(diff_text),
        "safety": analyze_safety(diff_text),
        "documentation": analyze_documentation(
            diff_text, escopo_resolvido=diff_scope != "working_tree_aggregate"),
        "objective_alignment": analyze_objective_alignment(args.ticket,
                                                           diff_text)
    }

    overall, score = calculate_overall(dimensions, verify_report, iterations)

    # SPC-0028 units 2/3 (TCK-0225/0228): advisory loop telemetry, extracted to a
    # tested function (tests/test_loop_wiring.py) that surfaces failures via
    # warn_telemetry instead of swallowing them — and never crashes the judge.
    lesson_utility, strategy_effectiveness = attach_loop_telemetry(run_dir, score, RUNS_DIR)

    verdict = {
        "ticket": args.ticket,
        "run": run_dir.name if run_dir else None,
        "timestamp": now_utc().isoformat(),  # TCK-0559: was bare datetime.now (naive/LOCAL)
        "overall": overall,
        "score": score,
        "low_confidence": low_confidence,
        "diff_scope": diff_scope,
        # TCK-1138/DES-0746: nota quando o escopo caiu no agregado (sem
        # commits do run resolúveis) — transparência sobre o que o verdict
        # mediu; None nos escopos resolvidos (run_artifact/ticket_range).
        "diff_scope_note": diff_scope_note(diff_scope),
        "dimensions": dimensions,
        # TCK-1193/D11: campo top-level para consumo direto pelo downstream
        # (lib/autonomy_ratchet, decision log) — int 0-100 ou null (sem spec
        # linkada). Autonomia nunca excede o alinhamento medido.
        "objective_alignment": dimensions["objective_alignment"]["score"],
        "what_went_right": extract_what_went_right(run_dir, ver_path, verify_report),
        "what_went_wrong": extract_what_went_wrong(verify_report, iterations),
        "root_causes": extract_root_causes(verify_report, iterations),
        "lessons": extract_lessons(verify_report, extract_root_causes(verify_report, iterations), args.ticket),
        "recommendations": verify_report.get("recommendations", []) if verify_report else [],
        "iterations": iterations,
        "lesson_utility": lesson_utility,
        "strategy_effectiveness": strategy_effectiveness
    }

    # TCK-1181/PLN-0017 D7: lição POSITIVA para entrega notavelmente
    # eficiente — a memória também precisa aprender "what good looks like".
    # Minta no máximo UMA, específica (anti-noise), severity low; persiste
    # pelo MESMO write path das lições de falha (verdict["lessons"] →
    # persist_verdict_and_lessons → lib.db.add_lesson, quarentena inclusa).
    ticket_content = _read_ticket_content(args.ticket)
    success_lesson = extract_success_lesson(
        overall, iterations, verify_report, dimensions, diff_text, args.ticket,
        ticket_content=ticket_content,
        has_playbook=_ticket_has_playbook(ticket_content))
    if success_lesson:
        verdict["lessons"].append(success_lesson)

    # Adiciona recomendacoes se score baixo
    if score < 75:
        verdict["recommendations"].append("Considerar revisão de design antes de próxima execução")
    if score < 50:
        verdict["recommendations"].append("RECOMENDADO: Escalar para revisão humana antes de merge")

    # TCK-1193/D11: entrega que casa com o ticket mas diverge dos objetivos
    # linkados gera nota explícita — o ratchet não deve ler spec_compliance
    # sozinho como proxy de alinhamento.
    divergence = objective_divergence_note(dimensions)
    if divergence:
        verdict["recommendations"].append(divergence)

    # TCK-1222/PLN-0017 D9: fecha o loop do decision log — as decisões
    # autônomas do ticket (triage/design-approval/done-closure) recebem o
    # outcome derivado do verdict, e o ratchet passa a medir precision real.
    # Idempotente (só outcome=null é alvo) e fail-open (loud).
    verdict["decision_outcome_backfill"] = backfill_decision_outcomes(
        args.ticket, overall, root=REPO_ROOT)

    # Armazena na memória — writers canônicos, loud em falha (TCK-0457)
    persist_verdict_and_lessons(verdict, args.ticket)

    # Salva arquivo
    if args.verdict_file:
        args.verdict_file.write_text(json.dumps(verdict, indent=2, ensure_ascii=False))

    if args.json:
        print(json.dumps(verdict, indent=2, ensure_ascii=False))
    else:
        print(f"{'='*60}")
        print(f"  JUDGE VERDICT — {args.ticket}")
        print(f"{'='*60}")
        print(f"Overall: {overall} ({score}/100)")
        print(f"Iterations: {iterations}")
        print()
        for dim, data in dimensions.items():
            dim_score = data["score"]
            # TCK-1193/D11: dimensão null (sem spec linkada) imprime 'null'
            score_txt = (f"{dim_score:3d}/100" if dim_score is not None
                         else "   null ")
            print(f"  {dim:20s}: {score_txt} — {data['notes'][:50]}")
        print()
        print("✅ What went right:")
        for w in verdict["what_went_right"]:
            print(f"  • {w}")
        print()
        print("❌ What went wrong:")
        for w in verdict["what_went_wrong"]:
            print(f"  • {w}")
        print()
        if verdict["root_causes"]:
            print("🔍 Root causes:")
            for c in verdict["root_causes"]:
                print(f"  • {c}")
        if verdict["lessons"]:
            print()
            print("📚 Lessons learned:")
            for l in verdict["lessons"]:
                print(f"  • [{l['severity']}] {l['lesson'][:60]}")
        if verdict["recommendations"]:
            print()
            print("💡 Recommendations:")
            for r in verdict["recommendations"]:
                print(f"  • {r}")

    sys.exit(0 if overall in ("EXCELLENT", "ACCEPTABLE") else 1)


if __name__ == "__main__":
    main()
