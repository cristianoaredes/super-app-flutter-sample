---
id: TCK-0004
slug: wire-login-to-host-auth-service
title: Ligar login do AuthBloc ao AuthService / splash
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: high
category: reliability
effort: M
flow: normal
ceremony: full
business_impact: "O sample nunca demonstra 'já logado → dashboard'; splash sempre vai a /login."
linked_findings:
  - FND-0004
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/02-architecture.md
  - .archagents/07-security-compliance.md
  - .archagents/10-runbooks.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0003
acceptance: []
acceptance_waiver: "Verify deve reproduzir splash após login mock: AuthService.isAuthenticated true OU navegação para /dashboard. O grep do emit Unauthenticated não é critério suficiente."
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0004 — Ligar login do AuthBloc ao AuthService / splash

## Descrição

AuthBloc.login deve atualizar AuthService (ou o splash deve consultar AuthRepository). _onCheckAuthStatus não pode emitir Unauthenticated sem ler o repositório.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0004.

## Evidência

- `packages/micro_apps/splash/lib/src/presentation/pages/splash_page.dart:L21-L34`
- `packages/micro_apps/auth/lib/src/presentation/bloc/auth_bloc.dart:L41-L61`
- `super_app/lib/core/services/auth_service_impl.dart:L18-L29`

## Impacto observado ou esperado

O sample nunca demonstra 'já logado → dashboard'; splash sempre vai a /login.

## Perguntas em aberto

- Após login, persistir token mock no secure storage?

## Seções de Docs relevantes

- `.archagents/02-architecture.md`
- `.archagents/07-security-compliance.md`
- `.archagents/10-runbooks.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como high/reliability, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
