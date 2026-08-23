---
id: TCK-0007
slug: remove-dead-infra-and-fix-base-micro-app-import
title: Remover infra morta e corrigir import de BaseMicroApp
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: architecture
effort: M
flow: normal
ceremony: full
business_impact: 'Contratos mortos (hub/flags) e import inexistente em core_interfaces.'
linked_findings:
  - FND-0007
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/02-architecture.md
  - .archagents/03-modules.md
  - .archagents/08-conventions.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0006
acceptance:
  - check: 'test ! -f packages/core/core_interfaces/lib/src/micro_app_dependencies.dart; rg -n "micro_app_dependencies.dart" packages/core/core_interfaces/lib/src/base_micro_app.dart'
    expect: '^$'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0007 — Remover infra morta e corrigir import de BaseMicroApp

## Descrição

Corrigir import micro_app_dependencies.dart; declarar get_it em core_interfaces ou remover o import. Decidir: usar ApplicationHub/flags ou apagar do README. Remover impls mortas do host e a pasta payments duplicada.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0007.

## Evidência

- `packages/core/core_interfaces/lib/src/base_micro_app.dart:L1-L5`
- `super_app/lib/core/di/injection_container.dart:L34-L50`
- `super_app/lib/main.dart:L163-L178`

## Impacto observado ou esperado

Contratos mortos (hub/flags) e import inexistente em core_interfaces.

## Perguntas em aberto

- Hub e flags são roadmap ou dead code a apagar?

## Seções de Docs relevantes

- `.archagents/02-architecture.md`
- `.archagents/03-modules.md`
- `.archagents/08-conventions.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/architecture, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
