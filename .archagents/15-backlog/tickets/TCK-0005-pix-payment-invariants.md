---
id: TCK-0005
slug: pix-payment-invariants
title: Invariantes e idempotência nos use cases PIX/pagamento
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: reliability
effort: M
flow: normal
ceremony: full
business_impact: 'Retry de UI pode duplicar item na lista mock; fork com API herda double-submit.'
linked_findings:
  - FND-0005
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/01-business-domain.md
  - .archagents/04-data-model.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0009
acceptance: []
acceptance_waiver: 'Precisa de testes de use case novos; critério será a suíte desses testes no Verify.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0005 — Invariantes e idempotência nos use cases PIX/pagamento

## Descrição

SendPixUseCase deve rejeitar amount<=0 e, se houver saldo no mock, insuficiente. makePayment precisa de chave de idempotência ou dedupe por id.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0005.

## Evidência

- `packages/micro_apps/pix/lib/src/domain/usecases/send_pix_usecase.dart:L13-L26`
- `packages/micro_apps/payments/lib/src/domain/repositories/payment_repository.dart:L4-L16`

## Impacto observado ou esperado

Retry de UI pode duplicar item na lista mock; fork com API herda double-submit.

## Perguntas em aberto

- O sample deve simular saldo insuficiente com InsufficientFundsException?

## Seções de Docs relevantes

- `.archagents/01-business-domain.md`
- `.archagents/04-data-model.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/reliability, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
