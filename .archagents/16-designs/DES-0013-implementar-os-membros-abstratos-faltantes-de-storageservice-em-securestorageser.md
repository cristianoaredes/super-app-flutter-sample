---
id: DES-0013
slug: implementar-os-membros-abstratos-faltantes-de-storageservice-em-securestorageser
title: "Implementar os membros abstratos faltantes de StorageService em SecureStorageService, sem tocar outro arquivo"
created_at: 2026-09-08T06:35:21Z
status: approved
ticket: TCK-0013
type: design
scope_files_new: []
scope_files_modified:
  - packages/core/core_security/lib/src/services/secure_storage_service.dart
scope_files_deleted: []
blast_radius: low
playbook: .archagents/16-designs/playbooks/DES-0013-playbook.md
acceptance_delta: unchanged
---
# DES-0013 - Implementar os membros abstratos faltantes de StorageService em SecureStorageService, sem tocar outro arquivo

## Problema

`melos exec --scope=core_security -- dart analyze .` reporta `error - non_abstract_class_inherits_abstract_member`
em `lib/src/services/secure_storage_service.dart:10:7` (gabarito 2026-09-05, linha 110). `SecureStorageServiceImpl`
declara `implements StorageService` (`packages/core/core_interfaces/lib/src/services/storage_service.dart:27-51`)
mas so implementa uma API antiga (`write`/`read`/`delete`/`deleteAll` + helpers de token). Confirmado por leitura
direta dos dois arquivos: faltam exatamente 7 membros abstratos de `StorageService`:
`initialize()`, `setValue<T>(key, value)`, `getValue<T>(key)`, `removeValue(key)`, `clear()`,
`getApplicationDocumentsDirectory()`, e o getter `secureStorage` (retorna `SecureStorageService`,
a segunda interface no mesmo arquivo). `containsKey(String key)` ja bate por coincidencia de assinatura
com o metodo existente (sem `@override`, mas o Dart nao exige a anotacao).

## Solucao

Em `secure_storage_service.dart`, adicionar os 7 membros faltantes a `SecureStorageServiceImpl`,
reaproveitando `_storage`/`write`/`read`/`delete`/`deleteAll` internamente em vez de duplicar logica:
- `initialize()` — no-op assincrono (o `FlutterSecureStorage` nao exige setup explicito) ou delega a checagem
  de disponibilidade da plataforma, conforme o padrao ja usado no construtor.
- `setValue<T>(key, value)` — serializa `value` (via `toString()`/`jsonEncode` quando `T` nao for `String`) e
  chama `write`; retorna `true`/`false` conforme sucesso (hoje `write` lanca `StorageException` — capturar e
  converter para `false` para respeitar a assinatura `Future<bool>`).
- `getValue<T>(key)` — chama `read` e faz o cast/parse para `T`.
- `removeValue(key)` — delega a `delete`; retorna `bool` de sucesso.
- `clear()` — delega a `deleteAll`; retorna `bool` de sucesso.
- `getApplicationDocumentsDirectory()` — usa `path_provider` (ja dependencia transitiva do app) ou, se
  indisponivel no pacote `core_security`, documenta a limitacao e retorna caminho vazio com TODO — decisao
  fica para quem executa, conforme o que compilar sem introduzir nova dependencia de pacote fora do escopo.
- `secureStorage` (getter) — retorna `this` quando `SecureStorageServiceImpl` tambem puder implementar
  `SecureStorageService`, ou uma instancia interna dedicada — nao adicionar `implements SecureStorageService`
  sem necessidade; preferir a leitura mais simples que satisfaca o tipo de retorno.

Nao criar nem tocar outro arquivo (nem o pacote `core_interfaces`, nem consumidores) — o gabarito aponta um
unico erro num unico arquivo.

## Mudancas

- `packages/core/core_security/lib/src/services/secure_storage_service.dart`: adiciona os 7 membros faltantes
  a `SecureStorageServiceImpl` (nenhuma remocao dos metodos legados existentes, para nao quebrar chamadores
  atuais de `write`/`read`/`saveAccessToken`/etc.).

## Falsificador

Antes: `melos exec --scope=core_security -- dart analyze .` reporta `non_abstract_class_inherits_abstract_member`
em `secure_storage_service.dart:10:7` (linha 110 do gabarito). Depois: o mesmo comando roda sem esse `error`
para o pacote `core_security` (avisos/lints pre-existentes nao relacionados nao sao criterio de aceite aqui).

## Criterios de sucesso

- [ ] `melos exec --scope=core_security -- dart analyze .` sem `error` de `non_abstract_class_inherits_abstract_member`.
- [ ] Nenhum arquivo fora de `packages/core/core_security/lib/src/services/secure_storage_service.dart` modificado.
