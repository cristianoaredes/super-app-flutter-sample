# 00 — Overview

**Premium Bank / super-app-flutter-sample** é um repositório de **arquitetura de referência** Flutter: um super-app bancário fictício montado como monorepo Melos de micro-apps (auth, dashboard, account, cards, payments, pix, splash) orquestrados por um host fino (`super_app`).

**Para quem:** times que querem um ponto de partida de modularização Flutter (GetIt + GoRouter + BLoC/Cubit + Clean Architecture por feature). Não é um banco em produção (`README.md:L20-L26`).

**Problema que resolve:** mostrar como fatiar um app grande em pacotes com ciclo de vida (`BaseMicroApp`), DI lazy, rotas compostas e comunicação via `ApplicationHub`, em vez de um `lib/` monolítico.

**Stack:** Dart 3.x / Flutter 3.x · Melos · flutter_bloc 8 · hydrated_bloc · get_it 7 · go_router 12 · Dio 5 · Equatable · flutter_lints. Host declara Flutter `>=3.29.2` (`super_app/pubspec.yaml:L6-L8`); CI pinna `3.19.x`.

**Padrão:** Modular Monolith + Clean Architecture intra-micro-app. Ver `02-architecture.md`.

**Tamanho (medido 2026-08-12):** ~313 arquivos `.dart` · ~38 611 linhas Dart · 19 `pubspec.yaml` de pacote · 24 use cases · 10 `*_test.dart` · 41 commits no `master` (primeiro commit ~2025-04-01). Sem inventar cobertura %.

**Maturidade:** sample avançado (contratos `BaseMicroApp`, middleware de init, testes de BLoC em várias features, docs em `docs/`). Lacunas: `core_security` não ligado, CI desalinhado da branch `master`, mocks no lugar de API, sem flavors, sem AuthZ de rota.

**Integrações reais:** nenhuma de pagamento/identidade; HTTP aponta para `https://api.dev.example.com/v1` com `mock_data: true`.

## Arquivos-fonte

- `README.md`
- `super_app/pubspec.yaml`
- `super_app/lib/main.dart`
- `melos.yaml`
