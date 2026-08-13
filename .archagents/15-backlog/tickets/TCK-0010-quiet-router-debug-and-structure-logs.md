---
id: TCK-0010
slug: quiet-router-debug-and-structure-logs
title: Desligar debugLogDiagnostics em release e estruturar logs
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: observability
effort: S
flow: normal
ceremony: full
business_impact: 'Ruído de rota em release; impossível correlacionar falha de PIX.'
linked_findings:
  - FND-0010
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/06-infra-devops.md
  - .archagents/10-runbooks.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0001
acceptance:
  - check: 'rg -n "debugLogDiagnostics: true" super_app/lib/core/router/app_router.dart'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0010 — Desligar debugLogDiagnostics em release e estruturar logs

## Descrição

debugLogDiagnostics só em kDebugMode. Parar de misturar print com LoggingService nos injectors. Flag enable_crash_reporting ou some do default ou ganha um backend (mesmo que no-op documentado).

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0010.

## Evidência

- `super_app/lib/core/router/app_router.dart:L46`
- `super_app/lib/core/di/injection_container.dart:L103-L107`

## Impacto observado ou esperado

Ruído de rota em release; impossível correlacionar falha de PIX.

## Perguntas em aberto

- Crash reporting entra no escopo do sample?

## Seções de Docs relevantes

- `.archagents/06-infra-devops.md`
- `.archagents/10-runbooks.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/observability, effort=S, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
