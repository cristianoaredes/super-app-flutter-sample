---
id: DES-0012
title: Bootstrap único de HydratedStorage (web + IO)
ticket: TCK-0012
created_at: 2026-08-12T23:05:00Z
status: approved
---

# DES-0012 — Bootstrap único de HydratedStorage

## Problema

`PaymentsCubit extends HydratedCubit`. `hydrate()` lê `HydratedBloc.storage` no construtor. O micro-app só chama `HydratedStorage.build` quando `!kIsWeb`. No Chrome o storage fica `null` → `StorageNotFound` → middleware `/error`.

## Decisão

1. Uma função `ensureHydratedStorage()` no pacote `payments` (único `HydratedCubit` hoje), exportada no barrel.
2. API oficial 9.x:
   - web: `HydratedStorage.webStorageDirectory`
   - IO: `Directory.systemTemp.createTempSync('hydrated_bloc')`
3. Idempotente: se o getter de `HydratedBloc.storage` já resolve, retorna; senão `build`.
4. O host chama `ensureHydratedStorage()` em `main()` **depois** de `WidgetsFlutterBinding.ensureInitialized()` e **antes** de inicializar micro-apps. Qualquer `HydratedCubit` futuro herda o storage.
5. `PaymentsMicroApp.onInitialize` também chama `ensureHydratedStorage()` (lazy init / testes do pacote / se o host esquecer).
6. Testes de cubit instalam um `Storage` in-memory; um teste de contrato prova `StorageNotFound` sem storage e construção após `ensure`.

## Fora de escopo

- Apagar o `PaymentsCubit` morto em `presentation/bloc/` (não é o usado em runtime).
- Remover `hydrated_bloc` dos pubspecs que não têm `HydratedCubit`.
- Trocar `HydratedCubit` por `Cubit` (perderia persistência de propósito no mobile).

## Rollback

Reverter o helper, o `main()` e o `onInitialize`. Sem migração de dados (Hive box `hydrated_box` no web é nova).
