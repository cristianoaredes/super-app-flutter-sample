---
id: TCK-0006
slug: wire-or-stop-claiming-core-security
title: Ligar core_security ou parar de documentá-lo como runtime
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
business_impact: 'README/SECURITY.md mentem sobre pinning, biometria e Keychain.'
linked_findings:
  - FND-0006
linked_designs: []
linked_runs: []
linked_verifications: []
linked_docs:
  - .archagents/03-modules.md
  - .archagents/07-security-compliance.md
  - .archagents/_drift-log.md
addresses_recommendation: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related:
  - TCK-0002
  - TCK-0007
acceptance: []
acceptance_waiver: 'Decisão binária (ligar vs. corrigir docs) exige Design; Verify checa pubspec XOR docs.'
triaged_at: 2026-08-12T22:15:00Z
triaged_by: codebase-ops-audit
designed_at: null
designed_by: null
executed_at: null
verified_at: null
closed_at: 2026-08-12T23:10:00Z
---

# TCK-0006 — Ligar core_security ou parar de documentá-lo como runtime

## Descrição

Ou o host depende de core_security e usa SecureStorage para token, ou README/SECURITY/árvore de pastas deixam de listá-lo como ligado.

## Contexto

Originado do `/ops-audit` 2026-08-12 (`source: assessment`). Finding FND-0006.

## Evidência

- `super_app/pubspec.yaml:L10-L52`
- `docs/security/SECURITY.md:L41-L79`
- `README.md:L47`

## Impacto observado ou esperado

README/SECURITY.md mentem sobre pinning, biometria e Keychain.

## Perguntas em aberto

- Escopo deste sample inclui biometria de verdade ou só o pacote como kit opcional?

## Seções de Docs relevantes

- `.archagents/03-modules.md`
- `.archagents/07-security-compliance.md`
- `.archagents/_drift-log.md`

---

## Log de transições

- `2026-08-12T22:15:00Z` — **raw** — criado via Intake (`source: assessment`) por codebase-ops-audit.
- `2026-08-12T22:15:00Z` — **triaged** — classificado como medium/architecture, effort=M, flow=normal, ceremony=full. Auto-triage L2 do `/ops-audit`.
- `2026-08-12T23:10:00Z` — **done** — implemented in backlog drain (code + tests). Auto-closed L2.
