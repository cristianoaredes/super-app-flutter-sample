---
run_id: RUN-20260813-035500-audit-drain
ticket: TCK-0012
covers: [TCK-0001, TCK-0002, TCK-0003, TCK-0004, TCK-0005, TCK-0006, TCK-0007, TCK-0008, TCK-0009, TCK-0010, TCK-0011, TCK-0012]
design: DES-0012
status: completed
ceremony: full
mode: live
operator: grok-execute
start_time: 2026-08-12T22:00:00Z
end_time: 2026-08-13T03:55:00Z
commits: [9b60119]
files_modified: []
test_result:
  status: pass
  summary: "Focused suites: payments 12, dashboard widgets 6, pix domain 3, auth session 4, super_app 5. All passed. gitleaks rc=0."
---

# RUN-20260813-035500 — Audit drain + HydratedStorage + overflow + Bloc close

## Resumo

Bootstrap `.archagents/`, auditoria 7-dim, drain TCK-0001–0011, depois TCK-0012 (HydratedStorage web), overlays de overflow de UI e `BlocProvider.create` fechando singletons. Verify desta run é o gate de `/ops-ship`.

## Mudanças

- **Criados:** `.archagents/**` (exceto snapshots), `AGENTS.md`/`CLAUDE.md`, testes de sessão/overflow/hydrated, `payments/.../hydrated_storage_bootstrap.dart`
- **Modificados:** auth/session, rotas, interceptor, CI, temas, micro-apps, iOS/macOS deployment
- **Deletados:** nenhum

## Testes + Evidence Gate

| Gate | Comando | Resultado |
|---|---|---|
| payments | `flutter test` em payments (bootstrap+cubit+domain) | pass 12 |
| dashboard | `flutter test test/presentation/widgets` | pass 6 |
| pix | `flutter test test/domain` | pass 3 |
| auth | session repository + bloc tests | pass 4 |
| super_app | auth_redirect + auth_service + widget_test | pass 5 |
| secrets | `gitleaks-scan.sh` | rc=0 |

Live Chrome: Payments init + `payments_loaded count:3`; Pix close-error após `BlocProvider.create` (corrigido com `.value` + recreate).

## Rollback

`git revert` do commit de ship na branch `ops/audit-drain-tck-0001-0012`. Sem migrate de dados.

## Problemas

- Sem RUN formal durante o drain (esta pasta é o registro tardio para o gate de ship).
- iOS Simulator ainda bloqueado por ML Kit / `mobile_scanner`.
