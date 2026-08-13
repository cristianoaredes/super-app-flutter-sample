---
id: TCK-0003
slug: guard-authenticated-routes
title: Guardar rotas de negócio com sessão autenticada
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: security
effort: M
flow: normal
ceremony: full
business_impact: 'Deep link /pix ou /dashboard abre a área logada sem login.'
linked_findings:
  - FND-0003
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/02-architecture.md
  - .archagents/07-security-compliance.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0004
acceptance: []
acceptance_waiver: 'Requer teste de widget/router ainda inexistente; Verify deve exercitar redirect sem sessão → /login.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0003 — Guardar rotas de negócio com sessão autenticada

## Descrição

MicroAppInitializerMiddleware (ou redirect do GoRouter) deve exigir sessão para prefixos /dashboard|/pix|/payments|/cards|/account e mandar para /login se ausente.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0003.

## Evidência

- `super_app/lib/core/router/route_middleware.dart:L23-L38`
- `super_app/lib/core/router/route_middleware.dart:L41-L120`

## Impacto observado ou esperado

Deep link /pix ou /dashboard abre a área logada sem login.

## Perguntas em aberto

- Fonte da sessão: AuthService do host ou AuthRepository?

## Seções de Docs relevantes

- `.archagents/02-architecture.md`
- `.archagents/07-security-compliance.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/security, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
