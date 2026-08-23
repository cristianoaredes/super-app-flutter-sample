#!/usr/bin/env python3
"""criteria-check.py — Criteria Gate mecânico (TCK-0049, Verify Dimensão 0).

Lê o frontmatter `acceptance:` de um ticket e EXECUTA cada critério literalmente
somente quando o ticket é tratado como trusted-local:

    acceptance:
      - check: "python3 -m pytest -k pix -q"        # comando shell; pass = exit 0
        expect: "passed"                              # (opcional) regex no stdout+stderr
        timeout: 120                                  # (opcional) segundos, default 120

usage:
  python3 scripts/criteria-check.py --ticket TCK-NNNN [--root DIR] [--json]
  python3 scripts/criteria-check.py --file <ticket.md> [--json]
  python3 scripts/criteria-check.py --file <ticket.md> --untrusted --dry-run

Exit codes:
  0 = todos os critérios passaram (ou, com --expect-red, todos RED-limpos)
  1 = >=1 critério falhou
  3 = ticket sem acceptance[] (Verify exige waiver humano logado no VER)
  4 = ticket não encontrado / frontmatter inválido
  5 = origem não confiável tentou executar acceptance[] sem --dry-run
  6 = (--expect-red) validação RED reprovou: check QUEBRADO ou VERDE-prematuro

A autonomia é função da clareza dos critérios (ai-dlc.dev): este script é o que
torna o DoD verificável por máquina em vez de declarado pelo agente.
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import subprocess
import sys
from pathlib import Path

from lib.frontmatter import parse_frontmatter  # parser canônico (TCK-0041)
from lib.hermetic import external_paths as hermetic_external_paths  # TCK-1419
from lib.expect_contract import evaluate as evaluate_expect  # TCK-1349
from lib.acceptance_quality import tautological_reasons  # TCK-1522
# F0.8-T3: the P11 refusal logic now lives in the shared trust boundary so the
# autonomous pipeline-verify path enforces the same rule. UNTRUSTED_REFUSAL is
# imported (no longer defined here) — see scripts/lib/trust_boundary.py.
# FND-0047: validate_shell_command rejects injection patterns before execution.
from lib.trust_boundary import UNTRUSTED_REFUSAL, evaluate, validate_shell_command

DEFAULT_TIMEOUT = 120
MAX_TIMEOUT = 900  # TCK-1260: hard cap — never hang a gate forever


def find_ticket(root: Path, ticket_id: str) -> Path | None:
    # F0.7-T6: one resolver (active + archive); None on miss preserves the contract.
    from lib.artifacts import resolve_artifact
    try:
        return resolve_artifact("TCK", ticket_id, root=root, include_archive=True)
    except FileNotFoundError:
        return None


def _clamp_timeout(raw: object) -> int:
    """Parse timeout seconds; clamp to (1, MAX_TIMEOUT]."""
    try:
        t = int(raw)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        t = DEFAULT_TIMEOUT
    if t <= 0:
        t = DEFAULT_TIMEOUT
    return min(t, MAX_TIMEOUT)


def _normalize_check_for_root(check: str, root: Path) -> str:
    """TCK-1260: make relative script paths robust when cwd drifts.

    If the check starts with a relative path that exists under *root*, leave it
    (cwd=root). If it references ``scripts/`` or ``tests/`` without prefix and
    exists under root, prefer that form. Does not rewrite shell pipelines.
    """
    stripped = check.strip()
    # Already absolute or complex shell — leave alone
    if stripped.startswith("/") or any(op in stripped for op in ("|", "&&", ";", ">", "<", "`", "$(")):
        return stripped
    # python3 scripts/foo → ensure scripts/foo exists under root
    parts = stripped.split()
    for i, tok in enumerate(parts):
        if tok.startswith("-"):
            continue
        # skip interpreter tokens
        if tok in ("python3", "python", "bash", "sh", "pytest"):
            continue
        candidate = Path(tok)
        if candidate.is_absolute():
            continue
        under_root = root / tok
        if under_root.exists():
            # keep relative form; cwd is root
            continue
        # try common prefixes when author wrote bare "criteria-check.py"
        for prefix in ("scripts/", "scripts/gates/", "tests/"):
            alt = root / prefix / tok
            if alt.exists():
                parts[i] = str(Path(prefix) / tok)
                break
    return " ".join(parts)


def detect_external_paths(check: str, root: Path) -> list[str]:
    """TCK-1419 (FND-0103) — delega a `lib.hermetic`, dono único da regra.

    Sinal, não bloqueio: `criteria-check` reporta em `external_paths`; o gate
    que barra é o `dor-check`, na entrada (P9 — adicionar gate é livre, invalidar
    retroativamente o acervo existente não).
    """
    return hermetic_external_paths(check, root)


def run_check(item: dict, cwd: Path, *, dry_run: bool = False) -> dict:
    check = str(item.get("check", "")).strip()
    expect = item.get("expect")
    timeout = _clamp_timeout(item.get("timeout") or DEFAULT_TIMEOUT)
    result = {"check": check, "expect": expect, "status": "fail",
              "exit_code": None, "matched": None, "output_tail": "",
              "timeout_s": timeout,
              "external_paths": detect_external_paths(check, cwd),
              # TCK-1522: sinal (nunca bloqueio) de critério que não consegue
              # ficar vermelho. O gate que barra é o dor-check, na entrada.
              "tautological": tautological_reasons(check, expect)}
    if not check:
        result["output_tail"] = "critério sem campo 'check'"
        return result
    if dry_run:
        result["status"] = "dry-run"
        result["output_tail"] = "não executado (--dry-run)"
        return result

    check = _normalize_check_for_root(check, cwd)
    result["check"] = check

    # FND-0047: validate command for shell injection patterns before execution.
    validation = validate_shell_command(check)
    if not validation.safe:
        result["output_tail"] = f"FND-0047 shell safety: {validation.reason}"
        result["status"] = "fail"
        return result

    try:
        # FND-0047: prefer shell=False with parsed argv for simple commands.
        # For commands with shell features (pipes, &&, redirects), wrap in bash -c.
        if validation.needs_shell:
            proc_args = ["bash", "-c", check]
            use_shell = False
        else:
            proc_args = validation.argv
            use_shell = False

        proc = subprocess.run(proc_args, shell=use_shell, cwd=str(cwd),
                              capture_output=True, text=True, timeout=timeout)
        output = (proc.stdout or "") + (proc.stderr or "")
        result["exit_code"] = proc.returncode
        result["output_tail"] = output[-400:].strip()
        # TCK-1349: veredito vem do contrato único (lib/expect_contract) — o
        # mesmo consumido por pipeline-verify. Antes, regex inválida em
        # `expect` levantava re.PatternError e MATAVA o gate (fail-open por
        # crash); agora vira status "error".
        verdict = evaluate_expect(expect=expect, exit_code=proc.returncode,
                                  output=output)
        result["matched"] = verdict["matched"]
        result["status"] = verdict["status"]
        if verdict["reason"] and verdict["status"] == "error":
            result["output_tail"] = verdict["reason"]
    except subprocess.TimeoutExpired:
        # TCK-1260: distinct status so expect-red / judge can classify QUEBRADO vs RED
        result["output_tail"] = (
            f"timeout após {timeout}s (cwd={cwd}; "
            f"subir timeout no acceptance[] ou quebrar o check)"
        )
        result["status"] = "timeout"
        result["exit_code"] = None
    except FileNotFoundError as exc:
        result["output_tail"] = (
            f"comando/arquivo não encontrado: {exc.filename or exc} "
            f"(cwd={cwd}; use paths relativos à raiz do repo)"
        )
        result["status"] = "fail"
        result["exit_code"] = 127
    except OSError as exc:
        result["output_tail"] = f"OS error ao executar check: {exc}"
        result["status"] = "fail"
        result["exit_code"] = 126
    return result


def _advisory_acceptance_delta(fm: dict, root) -> None:
    """TCK-2156: linha advisory DES × aceite (nunca altera o veredito)."""
    import re as _re
    linked = fm.get("linked_designs") or []
    if isinstance(linked, str):
        linked = [linked] if linked.strip() else []
    if not linked:
        return
    from lib.acceptance_delta import _resolve_design  # fonte única de resolução
    path = _resolve_design(Path(root), str(linked[-1]).strip())
    if path is None:
        return
    texto = path.read_text(encoding="utf-8", errors="replace")
    m = _re.search(r"## Crit[ée]rios de sucesso\n(.*?)(?:\n## |$)", texto, _re.S)
    if not m:
        return
    n_des = len(_re.findall(r"^\s*(?:\d+\.|[-*]) ", m.group(1), _re.M))
    n_acc = len(fm.get("acceptance") or [])
    if n_des > n_acc:
        print(f"[ops:advisory] {linked[-1]} fixa {n_des} critério(s) de sucesso; "
              f"o acceptance[] do ticket tem {n_acc} — o DES declara "
              f"acceptance_delta, mas vale conferir a cobertura (TCK-2156)",
              file=sys.stderr)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    ap = argparse.ArgumentParser(description="Criteria Gate mecânico (Verify Dimensão 0)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--ticket", help="ID do ticket (TCK-NNNN)")
    g.add_argument("--file", help="path direto do ticket markdown")
    ap.add_argument("--root", default=".", help="raiz do projeto (default: cwd)")
    ap.add_argument("--json", action="store_true", help="output JSON machine-readable")
    ap.add_argument("--untrusted", action="store_true",
                    help="trata acceptance[] como conteúdo não confiável; recusa executar sem --dry-run")
    ap.add_argument("--dry-run", action="store_true",
                    help="lista critérios sem executar comandos shell")
    # PLN-0009/A10: validação RED em tempo de compilação de spec/ticket.
    # Um acceptance recém-escrito (pré-implementação) deve EXECUTAR limpo e
    # REPROVAR — três estados: RED-LIMPO (ok), QUEBRADO (erro de sintaxe/comando,
    # indistinguível de vermelho a olho nu) e VERDE-PREMATURO (critério que já
    # passa antes do trabalho existir = não distingue done de não-feito).
    ap.add_argument("--expect-red", action="store_true",
                    help="valida acceptance PRÉ-implementação: todo check deve executar "
                         "limpo e reprovar (RED). QUEBRADO ou VERDE-prematuro → exit 6")
    args = ap.parse_args()
    if args.expect_red and args.dry_run:
        logging.error("--expect-red exige execução real; incompatível com --dry-run")
        return 4

    root = Path(args.root).resolve()
    path = Path(args.file).resolve() if args.file else find_ticket(root, args.ticket)
    if not path or not path.exists():
        logging.error("ticket não encontrado: %s", args.ticket or args.file)
        return 4
    try:
        data = parse_frontmatter(path.read_text(encoding="utf-8"))
    except Exception as e:  # frontmatter inválido
        logging.error("frontmatter inválido em %s: %s", path, e)
        return 4

    acceptance = data.get("acceptance")
    ticket_id = data.get("id", path.stem)
    if not acceptance or not isinstance(acceptance, list):
        msg = {"ticket": ticket_id, "acceptance": [],
               "verdict": "no-acceptance",
               "note": "sem acceptance[] — Verify exige waiver humano logado no VER (acceptance_waiver)"}
        print(json.dumps(msg, ensure_ascii=False) if args.json
              else f"⚠️  {ticket_id}: sem acceptance[] no frontmatter — waiver humano obrigatório no Verify")
        return 3

    decision = evaluate(untrusted=args.untrusted, dry_run=args.dry_run)
    if decision.refused:
        msg = {"ticket": ticket_id, "verdict": "refused-untrusted",
               "note": decision.reason}
        if args.json:
            print(json.dumps(msg, ensure_ascii=False))
        else:
            logging.error("%s: %s", ticket_id, decision.reason)
        return 5

    results = [run_check(item if isinstance(item, dict) else {"check": item}, root, dry_run=args.dry_run)
               for item in acceptance]

    if args.expect_red:
        # Heurística calibrada nos dois defeitos reais da compilação da onda 1
        # do PLN-0009 (2026-07-02): grep usage-error exit=2 e timeout/None eram
        # QUEBRADOS disfarçados de vermelho; python "can't open file" exit=2 é
        # RED-limpo (o alvo ainda não foi implementado). Ambíguo → QUEBRADO
        # (fail-closed: melhor exigir um olhar do que aceitar em silêncio).
        _BROKEN_PATTERNS = ("unrecognized option", "invalid option", "usage:",
                            "command not found", "syntax error")

        def _classify(r: dict) -> str:
            if r["status"] == "pass":
                return "VERDE-PREMATURO"
            # TCK-1260: explicit timeout is a broken criterion for RED validation
            # (indistinguishable from hang) — treat as QUEBRADO, not RED-limpo.
            if r.get("status") == "timeout":
                return "QUEBRADO"
            ec = r["exit_code"]
            tail = (r["output_tail"] or "").lower()
            if ec is None or ec in (126, 127):
                return "QUEBRADO"
            # Erro de execução mascarado por `|| echo ...` (exit 0, mas o stderr
            # denuncia): o caso real do grep com flag mangled na onda 1.
            if any(p in tail for p in _BROKEN_PATTERNS):
                return "QUEBRADO"
            if ec == 2 and not ("no such file" in tail or "can't open file" in tail):
                return "QUEBRADO"
            return "RED-LIMPO"

        classes = [_classify(r) for r in results]
        ok = all(c == "RED-LIMPO" for c in classes)
        red_verdict = "red-clean" if ok else "red-defective"
        if args.json:
            print(json.dumps({"ticket": ticket_id, "verdict": red_verdict,
                              "classes": classes, "total": len(results),
                              "results": results}, ensure_ascii=False, indent=2))
        else:
            n_ok = sum(1 for c in classes if c == "RED-LIMPO")
            print(f"RED Validation — {ticket_id}: {n_ok}/{len(classes)} RED-limpos (pré-implementação)")
            for r, c in zip(results, classes):
                mark = "✅" if c == "RED-LIMPO" else "❌"
                print(f"  {mark} [{c}] exit={r['exit_code']}  {r['check'][:120]}")
                if c != "RED-LIMPO" and r["output_tail"]:
                    print(f"      └─ {r['output_tail'][:200]}")
            print(f"Veredito: {red_verdict.upper()}")
        return 0 if ok else 6

    # TCK-2156 (DES-1052 D6): advisory de reconciliação — compara nº de itens
    # em "## Criterios de sucesso" do DES mais recente com o nº de critérios
    # do acceptance[]. Heurística de prosa: NUNCA muda o rc (o gate real é a
    # marca acceptance_delta na transição). Em stderr, como todo aviso daqui.
    try:
        _advisory_acceptance_delta(data, root)
    except Exception:
        pass  # advisory é best-effort por contrato

    passed = sum(1 for r in results if r["status"] == "pass")
    dry = sum(1 for r in results if r["status"] == "dry-run")
    # timeout counts as fail (not pass)
    verdict = "dry-run" if args.dry_run else ("pass" if passed == len(results) else "fail")

    # TCK-1679: a tautologia passa a CONTAR no veredito.
    #
    # `tautological_reasons` era chamado desde o TCK-1522 e o resultado ia para
    # `result["tautological"]` — **calculado e descartado**. O veredito olhava
    # só o status dos checks, então um critério que não pode falhar passava
    # como qualquer outro.
    #
    # É a classe que esta sessão inteira perseguiu, no gate que existe para
    # caçá-la: instrumento cabeado, executado, sem consequência. E há prova de
    # que custou — o TCK-1320 fechou com
    # `... | grep -c '...' || true` / `expect: 0`, que o linter já marcava
    # (`força-exit-zero`) desde antes.
    #
    # Duas famílias, ambas inúteis:
    #   - nunca fica VERMELHO (`|| true`, `echo`, `exit 0`) — passa sempre;
    #   - nunca fica VERDE (`rg -c` com expect zero) — trava o ticket e parece
    #     defeito do código.
    #
    # Impacto medido antes de ligar: **1** critério em todo o backlog, num
    # ticket já `done`. Nenhum ticket aberto afetado — catraca barata (P9).
    tautologicos = [r for r in results if r.get("tautological")]
    if tautologicos and not args.dry_run and verdict == "pass":
        verdict = "fail"
        # TUDO em stderr: `--json` escreve o relatório em stdout, e texto solto
        # ali quebra o parse do consumidor. Peguei isto na suíte
        # (`test_json_output` com JSONDecodeError) depois de imprimir os dois
        # primeiros avisos em stdout — o mesmo descuido que o gate acusa,
        # cometido pelo gate.
        print("\n⛔ criteria-check: critério(s) que não conseguem discriminar:",
              file=sys.stderr)
        for r in tautologicos:
            print(f"   [{','.join(r['tautological'])}] "
                  f"{str(r.get('check',''))[:70]}", file=sys.stderr)
        print("   Um critério que não pode ficar vermelho não é evidência; um "
              "que não pode ficar verde trava o ticket.", file=sys.stderr)

    # SPC-0057/C2.2 (DES-0213 §3.2): execução REAL flipa o acceptance-lock —
    # este runner e o pipeline-verify são os únicos escritores legítimos.
    # --dry-run/--expect-red nunca tocam o lock (não são evidência).
    if not args.dry_run:
        try:
            from lib.acceptancelock import set_passes
            set_passes(root, ticket_id, verdict == "pass", "criteria-check")
        except Exception as e:  # lock é camada de evidência, não deve mudar o exit
            logging.warning("acceptance-lock não atualizado: %s", e)
        # TCK-1417 (SPC-0092 módulo B): persiste a série de tentativas do gate —
        # o loop que de fato converge (agente corrige até o verde) não aparecia
        # em telemetria alguma. Append-only (P6), fail-open.
        try:
            from lib.criteria_attempts import record_attempt
            record_attempt(
                root, ticket_id, verdict=verdict, passed=passed,
                total=len(results),
                failed_checks=[str(r.get("check", "")) for r in results
                               if r.get("status") != "pass"],
            )
        except Exception as e:  # medição nunca altera o veredito do gate
            logging.warning("criteria-attempts não registrado: %s", e)

    if args.json:
        print(json.dumps({"ticket": ticket_id, "verdict": verdict,
                          "passed": passed, "dry_run": dry, "total": len(results),
                          "results": results}, ensure_ascii=False, indent=2))
    else:
        mode = "DRY-RUN" if args.dry_run else "EXECUTE"
        print(f"Criteria Gate — {ticket_id}: {passed}/{len(results)} ({mode})")
        for r in results:
            if r["status"] == "dry-run":
                mark = "DRY"
            elif r["status"] == "pass":
                mark = "✅"
            elif r["status"] == "timeout":
                mark = "⏱"
            else:
                mark = "❌"
            extra = "" if r["matched"] is None else f" (expect {'ok' if r['matched'] else 'NÃO bateu'})"
            print(f"  {mark} exit={r['exit_code']}{extra}  {r['check']}")
            if r["status"] in ("fail", "timeout") and r["output_tail"]:
                print(f"      └─ {r['output_tail'][:200]}")
        print(f"Veredito: {verdict.upper()}")
    return 0 if verdict in ("pass", "dry-run") else 1


if __name__ == "__main__":
    sys.exit(main())
