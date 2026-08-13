---
id: TCK-0012
slug: hydrate-storage-before-payments-cubit
title: Bootstrap HydratedStorage em todos os alvos antes de HydratedCubit
source: bug
created_at: 2026-08-12T23:05:00Z
created_by: codebase-ops
updated_at: 2026-08-12T23:05:00Z
status: done
severity: high
category: reliability
effort: S
flow: hotfix
ceremony: light
business_impact: 'Aba Pagamentos no Chrome redireciona para #/error; feature inutilizável no único target que sobe localmente.'
linked_findings:
  - FND-0012
linked_designs:
  - DES-0012
linked_runs: []
linked_verifications:
  - VER-20260813-035600-audit-drain
linked_docs:
  - .archagents/02-architecture.md
  - .archagents/10-runbooks.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0005
acceptance:
  - 'ensureHydratedStorage() não lança em kIsWeb (webStorageDirectory) nem em IO (temp dir).'
  - 'Chamar ensureHydratedStorage() duas vezes é no-op (sem segundo build).'
  - 'PaymentsCubit() sem storage lança StorageNotFound; após ensure, constrói.'
  - 'payments_micro_app.onInitialize não contém if (!kIsWeb) em volta do HydratedStorage.build.'
  - 'super_app main() chama ensureHydratedStorage() antes de inicializar micro-apps.'
acceptance_waiver: null
triaged_at: 2026-08-12T23:05:00Z
triaged_by: codebase-ops
designed_at: 2026-08-12T23:05:00Z
designed_by: codebase-ops
executed_at: 2026-08-12T23:20:00Z
verified_at: 2026-08-12T23:20:00Z
closed_at: 2026-08-12T23:20:00Z
---

# TCK-0012 — Bootstrap HydratedStorage em todos os alvos antes de HydratedCubit

## Descrição

Inicializar `HydratedBloc.storage` no host (web + nativo) e no micro-app de pagamentos de forma idempotente, usando a API oficial do `hydrated_bloc` 9.x. Remover o skip `if (!kIsWeb)` que deixa o cubit construir sem storage.

## Contexto

Reproduzido em `/ops-work` live run Chrome 2026-08-12 ao abrir Pagamentos. `source=bug`.

## Evidência

- `packages/micro_apps/payments/lib/src/payments_micro_app.dart:L85-L132`
- `packages/micro_apps/payments/lib/src/presentation/cubits/payments_cubit.dart:L10-L23`
- `super_app/lib/core/router/route_middleware.dart:L132-L136`
- Mensagem: `Storage was accessed before it was initialized.`

## Impacto observado ou esperado

`#/payments` → `#/error`. Qualquer `HydratedCubit` futuro quebra no web da mesma forma.

## Perguntas em aberto

Nenhuma. Decisão em DES-0012.

## Seções de Docs relevantes

- `.archagents/02-architecture.md`
- `.archagents/10-runbooks.md`

---

## Log de transições

- `2026-08-12T23:05:00Z` — **raw** — intake de bug (Pagamentos web) por codebase-ops.
- `2026-08-12T23:05:00Z` — **triaged** — high/reliability, effort=S, flow=hotfix. Evidência de run Chrome.
- `2026-08-12T23:05:00Z` — **designed** — DES-0012 (host bootstrap + ensure no micro-app).
- `2026-08-12T23:05:00Z` — **in_progress** — execução L2 autorizada pelo operador ("formalize and fix fully").
- `2026-08-12T23:20:00Z` — **done** — ensureHydratedStorage no host + micro-app; 12 testes payments passando (StorageNotFound sem storage; cubit constrói após ensure).
- `2026-08-12T23:25:00Z` — follow-up: `BlocProvider.create` em payments/pix/account fechava o singleton ao sair da rota (`Cannot emit after close`). Trocado para `.value`.
