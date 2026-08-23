---
id: TCK-0008
slug: fix-ci-branch-and-flutter-pin
title: Alinhar CI à branch default e ao Flutter do host
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: high
category: reliability
effort: S
flow: normal
ceremony: full
business_impact: 'Push em master não roda analyze/test; pin 3.19.x conflita com host >=3.29.2.'
linked_findings:
  - FND-0008
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/06-infra-devops.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0009
  - TCK-0011
acceptance:
  - check: 'rg -n "branches: \\[main, develop\\]|branches: \\[master" .github/workflows/ci_cd.yaml'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0008 — Alinhar CI à branch default e ao Flutter do host

## Descrição

Incluir master (ou migrar default para main) nos triggers. Pin Flutter do workflow = constraint do super_app. Remover ou implementar scripts Melos citados no CONTRIBUTING.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0008.

## Evidência

- `.github/workflows/ci_cd.yaml:L3-L18`
- `super_app/pubspec.yaml:L6-L8`

## Impacto observado ou esperado

Push em master não roda analyze/test; pin 3.19.x conflita com host >=3.29.2.

## Perguntas em aberto

- A branch canônica passa a ser main ou o workflow passa a ouvir master?

## Seções de Docs relevantes

- `.archagents/06-infra-devops.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como high/reliability, effort=S, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
