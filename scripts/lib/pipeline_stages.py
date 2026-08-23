#!/usr/bin/env python3
"""pipeline_stages.py — Individual pipeline stage functions (FND-0054).

Extracted from pipeline-orchestrator.py for single-responsibility and testability.
Stage functions accept an optional ``executor`` parameter (dependency injection)
so callers (the orchestrator, tests) can pass their own CmdExecutor instance.
Falls back to the module-level ``_default_executor`` for standalone use.
"""

import json
import logging
import shlex
import subprocess
import sys
from pathlib import Path

from lib.cmd_utils import CmdExecutor

logger = logging.getLogger(__name__)

from lib.bootstrap import get_repo_root

REPO_ROOT = get_repo_root()
RUNS_DIR = REPO_ROOT / ".archagents" / "13-execution" / "runs"

# Fallback executor for standalone use (not via orchestrator).
_default_executor = CmdExecutor(timeout=60, max_retries=2, backoff_factor=1.5)


def _get_exec(executor):
    """Return the supplied executor, or the module-level default."""
    return executor if executor is not None else _default_executor


def _run(executor, cmd: str, **kwargs):
    """Run subprocess anchored at REPO_ROOT (TCK-1031)."""
    kwargs.setdefault("cwd", REPO_ROOT)
    return _get_exec(executor).run(cmd, **kwargs)


# ---------------------------------------------------------------------------
# STAGE FUNCTIONS
# ---------------------------------------------------------------------------


def preflight(ticket_id: str, dry_run: bool, executor=None) -> dict:
    """Verificações antes de iniciar pipeline."""
    checks = {"ok": True, "warnings": [], "errors": []}

    # 1. Ticket existe
    result = _run(executor,
                  f"{shlex.quote(sys.executable)} scripts/context-query.py --ticket {ticket_id} --verbose")
    if not result.success or "não encontrado" in result.stdout.lower():
        checks["errors"].append(f"Ticket {ticket_id} não encontrado")
        checks["ok"] = False
        return checks

    # 2. Git status limpo (ou mudanças stashed)
    result = _run(executor, "git status --porcelain | head -5")
    if result.stdout.strip():
        checks["warnings"].append(
            f"Git working tree não está limpo:\n{result.stdout[:200]}")

    # 2b. TCK-0434: Enforce git-flow branch prefix and base alignment (pre-flight)
    # Real enforcement (errors block pipeline): fails if branch does not follow
    # (feature|bugfix|chore|hotfix)/... or does not contain ticket id.
    # origin/HEAD remains advisory warning (DES-0192).
    result = _run(executor, "git rev-parse --abbrev-ref HEAD")
    current_branch = (result.stdout or "").strip()
    valid_prefixes = ("feature/", "bugfix/", "chore/", "hotfix/")
    if current_branch and not any(current_branch.startswith(p) for p in valid_prefixes):
        checks["errors"].append(
            f"Branch atual '{current_branch}' não segue prefixo git-flow (feature/|bugfix/|chore/|hotfix/). "
            "Crie branch via /ops-work ou git checkout -b <prefix>/TCK-NNNN-<slug> a partir de develop.")
        checks["ok"] = False
    if current_branch and ticket_id.lower() not in current_branch.lower():
        checks["errors"].append(
            f"Branch '{current_branch}' não referencia o ticket {ticket_id}. "
            "Use convenção feature/TCK-NNNN-<slug> (DES-0192).")
        checks["ok"] = False
    # origin/HEAD alignment advisory (TCK-0434)
    result = _run(executor, "git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo ''")
    origin_head = (result.stdout or "").strip()
    if "refs/remotes/origin/main" in origin_head and "develop" not in origin_head:
        checks["warnings"].append(
            "origin/HEAD aponta para main (refs/remotes/origin/main). "
            "Alinhe para develop por DES-0192: git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop")

    # 3. Verifica se já existe RUN para este ticket
    existing_runs = list(RUNS_DIR.glob(
        f"RUN-*{ticket_id.lower().replace('-', '')}*"))
    if existing_runs:
        checks["warnings"].append(
            f"RUN existente encontrado: {existing_runs[-1].name}")

    # 4. Valida acceptance criteria (GAP-003)
    result = _run(executor,
                  f"{shlex.quote(sys.executable)} scripts/validate-criteria.py --ticket {ticket_id} --json",
                  timeout_override=30)
    if not result.success:
        try:
            validation = json.loads(result.stdout)
            issues = validation.get("issues", [])
            if issues:
                checks["errors"].append(
                    f"Acceptance criteria inválidos ({len(issues)} issues):")
                for issue in issues[:3]:
                    checks["errors"].append(
                        f"  - [{issue['severity']}] {issue['issue']}")
                if len(issues) > 3:
                    checks["errors"].append(
                        f"  ... e mais {len(issues) - 3} issues")
                checks["ok"] = False
        except json.JSONDecodeError:
            checks["errors"].append(
                f"Falha ao validar acceptance criteria: {result.stderr}")
            checks["ok"] = False

    # TCK-0434: invoke standalone checker; treat non-ok as error (enforcement)
    try:
        import json as _json
        gf = _run(executor,
                  f"{shlex.quote(sys.executable)} scripts/check-git-flow.py --ticket {ticket_id} --json",
                  timeout_override=15)
        if gf.success:
            data = _json.loads(gf.stdout or "{}")
            for w in data.get("warnings", []):
                if w not in checks.get("warnings", []):
                    checks["warnings"].append(f"[git-flow] {w}")
            if not data.get("ok", True):
                for e in data.get("errors", []):
                    if e not in checks.get("errors", []):
                        checks["errors"].append(f"[git-flow] {e}")
                checks["ok"] = False
    except Exception:
        pass  # fail-open on checker error itself

    if dry_run:
        checks["warnings"].append(
            "[dry-run] Nenhuma ação mutadora será executada")

    return checks


def execute_iteration(ticket_id: str, iteration: int, correction_note: str, dry_run: bool,
                      lessons_summary: str = "", executor=None) -> dict:
    """Delega execução ao executor. Retorna diff e status.

    W3a/PLN-0011: when TCK-0488 push injects lessons locally, IDs are returned
    in ``pushed_lesson_ids`` so the orchestrator can merge into
    ``lessons_consulted`` before ``generate_run_report``.
    """
    result: dict = {"ok": False, "diff": "", "error": "", "pushed_lesson_ids": []}

    if dry_run:
        result["ok"] = True
        result["diff"] = "[dry-run] Diff simulado"
        return result

    # Prepara nota de correção se for re-execução
    context = f"Ticket: {ticket_id} | Iteração: {iteration}"
    if lessons_summary:
        context += f"\nLições relevantes (advisory): {lessons_summary}"
    if correction_note:
        context += f"\nCorreções necessárias da iteração anterior:\n{correction_note}"

    # TCK-0415/SPC-0053: `context` (lessons_summary + correction_note) used to be
    # built here and then discarded — context-query.py never received it, so
    # what a prior failed iteration learned never reached the next attempt.
    # When there is real signal (a correction_note from a prior FAIL, or
    # relevant lessons), route it through context-query.py's EXISTING --query
    # flag so THIS attempt's context selection is actually steered by it — no
    # new CLI surface (--query already exists alongside --ticket). Iteração 1 sem lições no índice mantém o call --ticket-only.
    # TCK-0488/SPC-0057-C1.6: memória PUSH — lições entram já na 1ª iteração,
    # mesmo quando o chamador não passou lessons_summary (advisory, fail-open;
    # o marcador de corrupção do TCK-0455 nunca vira lição).
    # W3a/PLN-0011: also return pushed IDs for orchestrator telemetry merge.
    if not lessons_summary:
        try:
            _raw_lessons = consult_lessons(ticket_id)
            # TCK-1135: marcador de corrupção (TCK-0455) torna o índice SUSPEITO
            # — nunca cai no fallback cross-ticket sobre ele (política W3b).
            _index_suspect = any(
                isinstance(l, dict) and l.get("error") for l in _raw_lessons)
            _pushed = [l for l in _raw_lessons
                       if not (isinstance(l, dict) and l.get("error"))]
            if not _pushed and not _index_suspect:
                # TCK-1135/DES-0659: ticket novo (zero histórico próprio) —
                # fallback cross-ticket com lições REAIS severity-ordered
                # (ruído FND-0089 filtrado em lib.lesson_channel). Sem isto o
                # canal de consumo fica write-only para qualquer ticket sem
                # lições prévias — o estado morto observado desde ~2026-07-11.
                from lib.lesson_channel import cross_consult_lessons
                # root = module-global REPO_ROOT — monkeypatchável e sincronizado
                # pelo orquestrador (_stages.REPO_ROOT = REPO_ROOT, TCK-1135);
                # NUNCA paths.REPO_ROOT estático (vazaria a store real nos testes).
                _pushed = cross_consult_lessons(root=str(REPO_ROOT), limit=3)
            if _pushed:
                # TCK-0889: needles via lesson_needles (texto > id) — ver
                # lib/db.py; ids inteiros nunca casam em mark_lessons_applied.
                from lib.db import lesson_needles
                result["pushed_lesson_ids"] = lesson_needles(_pushed[:3])
                lessons_summary = "; ".join(
                    str(l.get("lesson", ""))[:160] for l in _pushed[:3])
                context += f"\nLições relevantes (advisory): {lessons_summary}"
        except Exception:
            pass

    if lessons_summary or correction_note:
        query_text = f"{ticket_id} {context}".replace("\n", " ").strip()[:2000]
        cmd_result = _run(executor,
                          f"{shlex.quote(sys.executable)} scripts/context-query.py --query {shlex.quote(query_text)}",
                          timeout_override=30)
    else:
        cmd_result = _run(executor,
                          f"{shlex.quote(sys.executable)} scripts/context-query.py --ticket {ticket_id}",
                          timeout_override=30)
    if not cmd_result.success:
        result["error"] = f"Falha ao carregar contexto: {cmd_result.stderr}"
        return result

    # Gera diff após execução (limitado, exclui indices grandes)
    # TCK-2485: `HEAD` obrigatório. Sem ele o `git diff` mostra só o que está
    # NÃO-staged, e o executor real roda `git add` antes de terminar — medido
    # em fixture: com a mudança no índice, `git diff` devolve 0 linhas e
    # `git diff HEAD` devolve o diff inteiro. Como este `result["diff"]` é o
    # que o judge julga, o veredito saía sobre uma entrega invisível.
    #
    # O TCK-2483 corrigiu exatamente isto em `pipeline-driver.py`; este é o
    # produtor IRMÃO, achado pelo verify da onda. Passou batido porque a busca
    # foi pelo NOME do arquivo em vez de pelo PADRÃO do comando.
    diff_result = _run(executor,
                       "git diff HEAD -- '*.py' '*.mjs' '*.ts' '*.md' '*.sh' "
                       "':(exclude).archagents/.index/*'")
    diff_out = diff_result.stdout
    # TCK-0629/N5: 100KB truncava ondas reais e divergia do cap do judge
    # (pipeline-judge.py, 400KB desde TCK-0589) — mesmo diff, dois caps
    # diferentes. Alinhado a 400_000 por consistência.
    if len(diff_out) > 400_000:
        diff_out = diff_out[:400_000] + "\n... (truncado)"
    result["diff"] = diff_out
    result["ok"] = True

    return result


def verify_iteration(ticket_id: str, diff_text: str, iteration: int, executor=None,
                     run_dir=None) -> dict:
    """Roda verificação adversarial.

    TCK-0415/SPC-0053: run_dir (when provided) is forwarded to
    pipeline-verify.py --run-dir so the ALREADY-implemented verify-side budget
    gate (pipeline-verify.py:349-358) becomes reachable from the real
    execution path, not just from isolated tests. Optional/backward-compatible
    — omitting it keeps today's exact command shape.
    """
    # Salva diff temporário
    tmp_diff = REPO_ROOT / f".tmp-pipeline-diff-{ticket_id}-{iteration}.txt"
    tmp_diff.write_text(diff_text)

    try:
        cmd = (f"{shlex.quote(sys.executable)} scripts/pipeline-verify.py --ticket {ticket_id} "
              f"--diff-file {tmp_diff} --json")
        if run_dir is not None:
            cmd += f" --run-dir {run_dir}"
        result = _run(executor, cmd, timeout_override=120)
        if result.stdout:
            return json.loads(result.stdout)
        return {"overall": "ERROR", "error": result.stderr or "empty output from verify"}
    except (json.JSONDecodeError, ValueError):
        return {"overall": "ERROR", "error": "Invalid JSON from verify"}
    except (OSError, subprocess.TimeoutExpired) as e:
        logger.warning("Verify subprocess error: %s", e)
        return {"overall": "ERROR", "error": str(e)}
    except Exception as e:
        logger.warning("Unexpected error in verify_iteration: %s", e)
        return {"overall": "ERROR", "error": str(e)}
    finally:
        tmp_diff.unlink(missing_ok=True)


def generate_correction_note(verify_report: dict) -> str:
    """Gera nota de correção baseada nos failures do verify."""
    notes = []
    for check in verify_report.get("checks", []):
        if check["status"] != "PASS":
            notes.append(
                f"Check #{check['id']} ({check['status']}): {check['check']}\n"
                f"  Esperado: {check.get('expect', 'N/A')}\n"
                f"  Obtido: {check.get('actual', 'N/A')[:200]}"
            )
    return "\n---\n".join(notes) if notes else "Nenhuma correção necessária (verify passou)"


def consult_asis_docs(ticket_id: str, ticket_path: str | None = None) -> dict:
    """TCK-0831: mechanical AS-IS doc consumption for design/pre-flight."""
    try:
        from lib.docs_consume import preflight_docs_consulted
        from pathlib import Path as _P
        return preflight_docs_consulted(
            ticket_id,
            ticket_path=_P(ticket_path) if ticket_path else None,
        )
    except Exception as e:
        logger.warning("AS-IS docs consult failed (fail-open): %s", e)
        return {"ticket": ticket_id, "docs_consulted": [], "n": 0}


def consult_lessons(ticket_id: str) -> list:
    """Return the FULL list of prior lessons for a ticket from the canonical SQLite
    index (lib/db.query_lessons) — never a bool. F1.1/SPC-0041.

    Fail-open for ordinary errors (missing/rebuildable index etc.) — returns [].
    EXCEPTION (TCK-0455/SPC-0057-A2): LessonStoreError means TRUE index corruption
    and is fail-closed by design in lib/db — surfaced via logger.error + a marker
    entry [{"error": "index_corrupt"}] that the orchestrator prints loudly.
    Corrupção NUNCA se disfarça de "ticket sem histórico". Never raises/sys.exit."""
    try:
        from lib.db import LessonStoreError, get_db, query_lessons_ranked
    except Exception as e:  # import do modulo falhou: fail-open classico
        logger.warning("Lesson consultation failed (advisory, fail-open): %s", e)
        return []
    try:
        db = get_db(str(REPO_ROOT))
        try:
            # TCK-0837: prefer higher utility_score (lessons.json) over the
            # plain severity/id order when a utility signal is available;
            # query_lessons_ranked fails open to severity order otherwise.
            return list(query_lessons_ranked(db, ticket=ticket_id, limit=3,
                                              root=str(REPO_ROOT)))
        finally:
            db.close()
    except LessonStoreError as e:
        logger.error(
            "Lesson index CORRUPT (fail-closed, TCK-0455): %s — rode "
            "scripts/build-index.py para reconstruir o índice.", e)
        return [{"error": "index_corrupt", "detail": str(e)}]
    except Exception as e:
        logger.warning(
            "Lesson consultation failed (advisory, fail-open): %s", e)
        return []
