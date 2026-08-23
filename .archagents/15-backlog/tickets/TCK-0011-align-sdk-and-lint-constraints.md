---
id: TCK-0011
slug: align-sdk-and-lint-constraints
title: Unificar SDK Flutter/Dart e flutter_lints no Melos
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: dependency
effort: S
flow: normal
ceremony: full
business_impact: 'Bootstrap/CI resolvem o menor denominador; analyze diverge entre máquinas.'
linked_findings:
  - FND-0011
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/06-infra-devops.md
  - .archagents/03-modules.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0008
acceptance: []
acceptance_waiver: 'Unificação é um conjunto de pubspecs; Verify deve comparar environment: entre super_app e um core legado.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0011 — Unificar SDK Flutter/Dart e flutter_lints no Melos

## Descrição

Alinhar environment.sdk/flutter e flutter_lints entre host e pacotes (ou documentar o piso no README). CVE scan (dart pub outdated / OSV) ficou fora deste audit.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0011.

## Evidência

- `super_app/pubspec.yaml:L6-L8`
- `packages/core/core_communication/pubspec.yaml`

## Impacto observado ou esperado

Bootstrap/CI resolvem o menor denominador; analyze diverge entre máquinas.

## Perguntas em aberto

- Piso oficial é 3.29.2 (README) ou 3.19 (pacotes core)?

## Seções de Docs relevantes

- `.archagents/06-infra-devops.md`
- `.archagents/03-modules.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/dependency, effort=S, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
