---
id: TCK-0013
slug: core-security-securestorageservice-nao-implementa-7-membros-abstratos-de-storage
title: "core_security: SecureStorageService nao implementa 7 membros abstratos de StorageService (non_abstract_class_inherits_abstract_member em packages/core/core_security/lib/src/services/secure_storage_service.dart:10)"
source: audit
created_at: 2026-09-08T06:34:09Z
created_by: ops
updated_at: 2026-09-08T06:36:15Z
status: designed
severity: medium
category: bug
effort: S
flow: normal
ceremony: full
business_impact: ""
linked_findings: []
linked_designs:
  - DES-0013
linked_runs: []
linked_verifications: []
linked_docs: []
external_refs: []
external_sync: []
blocks: []
blocked_by: []
related: []
acceptance: []
---
# TCK-0013 - core_security: SecureStorageService nao implementa 7 membros abstratos de StorageService (non_abstract_class_inherits_abstract_member em packages/core/core_security/lib/src/services/secure_storage_service.dart:10)

## Contexto

Unico `error` do pacote `core_security` no gabarito de analise estatica (GABARITO-…-raw.txt:110):
`non_abstract_class_inherits_abstract_member` em `secure_storage_service.dart:10:7`.
`SecureStorageServiceImpl implements StorageService` mas so cobre uma API antiga
(`write`/`read`/`delete`/`deleteAll` + helpers de token) — faltam 7 membros abstratos de
`StorageService` (`packages/core/core_interfaces/lib/src/services/storage_service.dart:27-51`):
`initialize`, `setValue`, `getValue`, `removeValue`, `clear`, `getApplicationDocumentsDirectory`,
`secureStorage` (getter). Ver DES-0013 para o desenho da implementacao.

Criado via scripts/ops/ticket/create.py a partir de source=audit, como parte da ponte
codebase-ops (TCK-0262 no agrupador orqo-ecosystem) — este ticket e o DES-0013 existem para dar
ao gate de escopo (`check-scope`) um alvo real para medir no primeiro commit deste repositorio
sob governanca.

## Falsificador

A linha 110 do gabarito e o comando `melos exec --scope=core_security -- dart analyze .`.
Antes do fix: esse comando reporta `error - non_abstract_class_inherits_abstract_member` em
`lib/src/services/secure_storage_service.dart:10:7`. Depois: o mesmo comando roda sem esse
`error` para o pacote `core_security`.

## Log de transicoes

- 2026-09-08T06:34:09Z - **raw** - criado via scripts/ops/ticket/create.py.
- 2026-09-08T06:36:14Z - **linked** - links updated
- 2026-09-08T06:36:14Z - **triaged** - gabarito 2026-09-05 linha 110
- 2026-09-08T06:36:15Z - **designed** - DES-0013 aprovado (TCK-0262)
