---
id: TCK-0002
slug: stop-storing-cvv-and-user-in-prefs
title: Não persistir CVV no domínio nem user JSON em SharedPreferences
source: assessment
created_at: 2026-08-12T22:15:00Z
created_by: codebase-ops-audit
updated_at: 2026-08-12T22:15:00Z
status: done
severity: medium
category: security
effort: S
flow: normal
ceremony: full
business_impact: 'Prefs e o entity Card ensinam a guardar PII/CVV em claro.'
linked_findings:
  - FND-0002
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/04-data-model.md
  - .archagents/07-security-compliance.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0001
  - TCK-0006
acceptance: []
acceptance_waiver: 'Verificar ausência de campo cvv no entity e de setValue(_userKey) exige leitura de modelo; sem teste automatizado estável neste repo ainda.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0002 — Não persistir CVV no domínio nem user JSON em SharedPreferences

## Descrição

Tirar cvv do entity Card (ou nunca hidratar no mock). Mover persistência de user para storage seguro ou não persistir no sample.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0002.

## Evidência

- `packages/micro_apps/cards/lib/src/domain/entities/card.dart:L11-L27`
- `packages/micro_apps/auth/lib/src/data/datasources/auth_local_datasource.dart:L32-L57`

## Impacto observado ou esperado

Prefs e o entity Card ensinam a guardar PII/CVV em claro.

## Perguntas em aberto

- O sample precisa persistir user entre cold starts?

## Seções de Docs relevantes

- `.archagents/04-data-model.md`
- `.archagents/07-security-compliance.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/security, effort=S, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
