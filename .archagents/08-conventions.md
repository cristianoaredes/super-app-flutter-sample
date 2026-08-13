# 08 — Convenções em uso (AS-IS)

Convenções **observadas no código**, não o guia teórico de `docs/guides/MICRO_APP_STANDARDS.md`. Conflito guia↔código: o código vence.

## Nomenclatura

- Arquivos Dart: `snake_case` (`auth_bloc.dart`, `login_usecase.dart`).
- Classes: `PascalCase` com sufixos `MicroApp`, `Bloc`/`Cubit`, `UseCase`, `Repository` / `RepositoryImpl`, `DataSource`, `Page`, `Service`, `ServiceImpl`.
- Pacotes path: `core_*`, micro-apps com nome curto (`auth`, `pix`, `payments`).
- Rotas: kebab-case de path (`/reset-password`, `/pix/keys/register`).
- IDs de micro-app: strings iguais ao instanceName do GetIt (`'auth'`, `'pix'`, …) — `AuthMicroApp.id => 'auth'` (`auth_micro_app.dart:L29-L30`).

## Organização

- **Monorepo Melos**, feature = pacote.
- Dentro do micro-app: **layer-first** (`data/`, `domain/`, `presentation/`) + `di/` + `router/` (auth tem `AuthRoutes` **e** `routes` no MicroApp; o host usa o mapa do MicroApp, `app_router.dart:L110-L114`).
- Host: `super_app/lib/core/{di,router,services,theme,widgets,config}`.

## Idioma

- Identificadores: **inglês**.
- Comentários e logs: **português** majoritário (`main.dart:L49`, `base_micro_app.dart:L108-L130`).
- UI: português (`'Página não encontrada'`, `app_router.dart:L67-L96`; título `'Premium Bank - Arquitetura Modular'`).
- README raiz: inglês (SEO). `docs/` em português.

## State management

- Padrão dominante: **BLoC** (`AuthBloc`, `PixBloc`, `DashboardBloc`, `AccountBloc`, `CardsBloc`, `ThemeBloc`).
- Exceção: **Cubit** em payments (`PaymentsCubit`).
- `hydrated_bloc` declarado em vários pubspecs; uso concreto visto em payments (storage em temp dir).
- Host `SuperApp` é `StatefulWidget` só para guardar o router (`main.dart:L282-L304`) — não compete com BLoC de feature.
- Widgets recebem BLoC via `BlocProvider.value` (auth/dashboard/account/cards) ou `BlocProvider(create:)` (pix/payments).

## DI

- GetIt service locator, registro manual (sem `injectable`/`@injectable`).
- Host: `sl` em `injection_container.dart:L31`; `main.dart` usa `getIt`.
- Micro-apps: `*Injector.register(getIt)` no `onInitialize`.
- Instâncias nomeadas para `MicroApp` e para `initializeMicroApp`.

## Routing

- GoRouter 12.x no host. Micro-apps exportam `Map<String, GoRouteBuilder>` (contrato próprio em `core_interfaces`, **não** `List<RouteBase>` do go_router — o README diz “cada micro-app declara RouteBase”; o código adapta o mapa).
- Deep link: GoRouter `path` + `debugLogDiagnostics: true` (`app_router.dart:L46`).
- Params validados por `RouteParamsValidator` em cards/payments/dashboard.

## Erros

- Sem `Either`/`Result`.
- Hierarquia em `core_interfaces` (`InitializationException`, `InvalidStateException`, …) usada pelo `BaseMicroApp`.
- Datasources mock lançam `Exception('Invalid credentials')` (`auth_mock_datasource.dart:L28`).
- Redirect de falha de init → `/error` (`route_middleware.dart:L105`).

## Testes

- `bloc_test` + `mockito` nos pubspecs de micro-apps.
- Cobertura real: 10 `*_test.dart`, concentrada em presentation/bloc. Pouco teste de use case isolado (auth tem repository test).
- `super_app/test/widget_test.dart` — template típico Flutter.

## Formatação / lint

- `flutter_lints` (versões 2 / 3 / 5 conforme o pacote).
- Um `analysis_options.yaml` só no host; include default, **sem** `strict-casts` / `prefer_single_quotes` ativo (`super_app/analysis_options.yaml:L10-L25`).
- Sem `very_good_analysis`.

## Imutabilidade / codegen

- `Equatable` + `copyWith` manual nas entidades (exceto `Payment`).
- `freezed` / `json_serializable` / `build_runner` no host e no CI (`melos run build_runner`); entidades de domínio lidas **não** usam Freezed.

## Imports

- Pacotes internos via `package:<name>/...`.
- Vários `hide` / prefixos para colisão `BlocProvider` / `AppConfig` / `GoRouterState` (`main.dart:L1-L3`, `auth_micro_app.dart:L1-L3`). Contrato de navegação **duplica** um `GoRouterState` próprio (`micro_app.dart:L19-L28`).

## Commits / repo

- Histórico recente: fases “Phase 1B BaseMicroApp”, testes Phase 2, security Phase 4, rewrite README. Default branch `master`.
- `.gitignore` raiz ignora `/*.md` com exceções só para `README.md`, `README_en.md` e `docs/**/*.md` — **AGENTS.md/CLAUDE.md seriam ignorados** sem negação extra (ajustado na Fase 8 do bootstrap).

## Anomalias de convenção

- Versões de SDK/`flutter_lints`/`go_router` não unificadas (Melos não tem catalog).
- `AuthRoutes` (`auth_routes.dart`) e `dashboard_routes.dart` convivem com `MicroApp.routes` — o host só usa o mapa do MicroApp.
- Domain do dashboard depende de `IconData` (Flutter).
- Payments: sem injector; pasta morta `presentation/bloc` + `data/sources/` ao lado de `cubits` / `datasources`.
- `PixMicroApp` e `PaymentsMicroApp` usam `BlocProvider(create:)` em vez de `.value` (o guia `MICRO_APP_STANDARDS.md` pede `.value`).
- `pix_micro_app.dart.bak` versionado em `packages/micro_apps/pix/lib/src/`.
- `print`/`debugPrint` nos injectors e mocks apesar de `avoid_print` no lint pack.

## Arquivos-fonte desta seção

- `super_app/analysis_options.yaml`
- `super_app/lib/main.dart`
- `packages/core/core_interfaces/lib/src/micro_app.dart`
- `packages/micro_apps/auth/lib/src/auth_micro_app.dart`
- `packages/micro_apps/payments/lib/src/payments_micro_app.dart`
- `.gitignore`
- `docs/guides/MICRO_APP_STANDARDS.md` (cruzamento)
