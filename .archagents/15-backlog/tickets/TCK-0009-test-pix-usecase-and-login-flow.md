---
id: TCK-0009
slug: test-pix-usecase-and-login-flow
title: Testar SendPixUseCase e o fluxo splash→login
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: test-coverage
effort: M
flow: normal
ceremony: full
business_impact: 'Regras de PIX e o bug de sessão podem regressar sem o CI ver.'
linked_findings:
  - FND-0009
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/08-conventions.md
  - .archagents/01-business-domain.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0005
  - TCK-0004
acceptance: []
acceptance_waiver: 'Arquivos de teste ainda não existem; Verify rodará flutter test nos pacotes auth e pix após o execute.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0009 — Testar SendPixUseCase e o fluxo splash→login

## Descrição

Suite de use case PIX (amount inválido, sucesso). Um teste de widget/router do splash sem AuthService autenticado → /login e, após TCK-0004, autenticado → /dashboard.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0009.

## Evidência

- `packages/micro_apps/pix/test/presentation/bloc/pix_bloc_test.dart:L396-L429`
- `packages/micro_apps/pix/lib/src/domain/usecases/send_pix_usecase.dart:L13-L26`

## Impacto observado ou esperado

Regras de PIX e o bug de sessão podem regressar sem o CI ver.

## Perguntas em aberto

- Vale um integration_test do host ou só testes de pacote?

## Seções de Docs relevantes

- `.archagents/08-conventions.md`
- `.archagents/01-business-domain.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/test-coverage, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
