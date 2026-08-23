---
id: TCK-0001
slug: redact-auth-and-http-logs
title: Redigir senha e corpo/headers HTTP nos logs
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: high
category: security
effort: S
flow: normal
ceremony: full
business_impact: 'Senha e Authorization vazam no console se o sample rodar em debug ou ligar Dio real.'
linked_findings:
  - FND-0001
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/07-security-compliance.md
  - .archagents/05-integrations.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0002
  - TCK-0010
acceptance:
  - check: 'rg -n "Password: \\$password" packages/micro_apps/auth/lib/src/data/datasources/auth_mock_datasource.dart'
    expect: '^$'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0001 — Redigir senha e corpo/headers HTTP nos logs

## Descrição

Remover print de senha no AuthMockDataSource e deixar de logar headers/body no LoggingInterceptor (ou mascarar Authorization e campos sensíveis).

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0001.

## Evidência

- `packages/micro_apps/auth/lib/src/data/datasources/auth_mock_datasource.dart:L12-L15`
- `packages/core/core_network/lib/src/interceptors/logging_interceptor.dart:L12-L35`

## Impacto observado ou esperado

Senha e Authorization vazam no console se o sample rodar em debug ou ligar Dio real.

## Perguntas em aberto

- Logs de debug devem existir atrás de flag enable_logs do AppConfig?

## Seções de Docs relevantes

- `.archagents/07-security-compliance.md`
- `.archagents/05-integrations.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como high/security, effort=S, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
