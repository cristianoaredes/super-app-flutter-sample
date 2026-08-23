# Findings

> Assessment `/ops-audit` 2026-08-12. Dimensões default: security, reliability, performance, architecture, test-coverage, observability, dependency.
>
> **Medição mecânica (`audit-measure.py`):** instrumentos do framework não se aplicam a este consumidor (sem `scripts/` vendorado). Estados `achado` contra paths do skill **não** viraram FND (P2). `quebrado`/`nao_medido` declarados no relatório, não como “ok”.
>
> **Não executado:** `--compliance`, `--martech`, `--inventory`, agentic-security (sem superfície LLM/MCP; hit `installments` é falso positivo).

## FND-0001 — Senha e corpo HTTP em log de debug

- **Categoria:** security
- **Severidade:** high
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/auth/lib/src/data/datasources/auth_mock_datasource.dart:L12-L15`
  - `packages/micro_apps/auth/lib/src/data/datasources/auth_mock_datasource.dart:L67-L70`
  - `packages/core/core_network/lib/src/interceptors/logging_interceptor.dart:L12-L35`
- **Ticket:** TCK-0001

### Descrição

O mock de auth faz `print` de email **e senha** em `kDebugMode`. O `LoggingInterceptor` registra method, URL, **headers** e **body** do request (e response). Se `mock_data` for desligado, o interceptor vaza `Authorization` e payload.

### Impacto concreto

Em um fork que ligue API real ou rode debug em dispositivo compartilhado, credenciais e tokens aparecem no console / logcat. CWE-532.

### Área de negócio afetada

Login e qualquer chamada Dio autenticada.

### Dependências entre findings

- related: [FND-0002, FND-0010]

---

## FND-0002 — PII e CVV no modelo / storage local inseguro

- **Categoria:** security
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/cards/lib/src/domain/entities/card.dart:L11-L27`
  - `packages/micro_apps/auth/lib/src/data/datasources/auth_local_datasource.dart:L32-L57`
- **Ticket:** TCK-0002

### Descrição

`Card` carrega `cvv` como `String` no domínio. `AuthLocalDataSource` persiste o user como JSON na chave SharedPreferences `user` (não no secure storage). Token teria `access_token` no secure storage, mas o mock de login não grava token.

### Impacto concreto

Backup/extração de prefs no sample (e em qualquer fork que mantenha o padrão) expõe e-mail e perfil. CVV no entity ensina um anti-padrão PCI a quem clonar o repo.

### Área de negócio afetada

Cartões; sessão persistida.

### Dependências entre findings

- related: [FND-0001, FND-0006]

---

## FND-0003 — Rotas de negócio sem AuthZ

- **Categoria:** security
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `super_app/lib/core/router/route_middleware.dart:L23-L38`
  - `super_app/lib/core/router/route_middleware.dart:L41-L120`
  - `super_app/lib/core/router/app_router.dart:L42-L61`
- **Ticket:** TCK-0003

### Descrição

O redirect do GoRouter só inicializa micro-apps. Não consulta sessão. `/dashboard`, `/pix`, `/payments`, `/cards`, `/account` são montados sem guarda. AuthZ por role não existe.

### Impacto concreto

Deep link ou `go('/pix')` abre a área logada sem login. No sample isso é UX quebrada; num fork com API real é bypass de AuthZ (SEC-005).

### Área de negócio afetada

Todas as features pós-login.

### Dependências entre findings

- blocked_by: []
- related: [FND-0004]

---

## FND-0004 — Login do AuthBloc não autentica o AuthService do host

- **Categoria:** reliability
- **Severidade:** high
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/splash/lib/src/presentation/pages/splash_page.dart:L21-L34`
  - `packages/micro_apps/auth/lib/src/presentation/bloc/auth_bloc.dart:L41-L61`
  - `super_app/lib/core/services/auth_service_impl.dart:L18-L29`
- **Ticket:** TCK-0004

### Descrição

O splash espera 2s e navega com `AuthService.isAuthenticated`. O login da UI passa por `AuthBloc`/`LoginUseCase` e **não** chama `AuthService.login`. `_onCheckAuthStatus` emite `UnauthenticatedState` sem ler o repositório (corpo vazio).

### Impacto concreto

Após o splash, o destino é sempre `/login`, mesmo depois de um login bem-sucedido na mesma sessão se o usuário voltar a `/`. Restart perde qualquer noção de sessão. O sample não demonstra o fluxo “já logado → dashboard”.

### Área de negócio afetada

Onboarding / autenticação.

### Dependências entre findings

- related: [FND-0003]

---

## FND-0005 — Use cases PIX/pagamento sem invariantes nem idempotência

- **Categoria:** reliability
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/pix/lib/src/domain/usecases/send_pix_usecase.dart:L13-L26`
  - `packages/micro_apps/payments/lib/src/domain/repositories/payment_repository.dart:L4-L16`
- **Ticket:** TCK-0005

### Descrição

`SendPixUseCase.execute` só encaminha ao repositório: sem `amount > 0`, saldo, limite ou chave de idempotência. `InsufficientFundsException` existe em `core_interfaces` e nenhum use case a lança. Pagamentos: `makePayment`/`cancelPayment` sem idempotency key.

### Impacto concreto

No mock, retry de UI pode duplicar transações na lista. Em fork com API, double-submit de PIX/boleto. Calibrado **medium** (sample, sem backend real) — seria high/critical com PSP ligado.

### Área de negócio afetada

PIX send; pagamento de contas.

### Dependências entre findings

- related: [FND-0009]

---

## FND-0006 — `core_security` e o guia SECURITY.md não estão no runtime

- **Categoria:** architecture
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `super_app/pubspec.yaml:L10-L52` (sem `core_security`)
  - `docs/security/SECURITY.md:L41-L79`
  - `README.md:L47`
  - `packages/core/core_security/lib/src/services/secure_storage_service.dart:L10-L21`
- **Ticket:** TCK-0006

### Descrição

O pacote `core_security` (secure storage, `local_auth`, validators, pins) existe e **não** é dependência do host nem de micro-apps. README e `SECURITY.md` descrevem essas práticas como se estivessem ligadas.

### Impacto concreto

Quem clona o repo acredita ter pinning, biometria e token no Keychain. O host registra `StorageServiceImpl` / `WebStorageService` e token fake em memória.

### Área de negócio afetada

Segurança transversal; onboarding de contribuidores.

### Dependências entre findings

- related: [FND-0002, FND-0007]
- related_drift: DRIFT-20260812-01, DRIFT-20260812-02

---

## FND-0007 — Infraestrutura morta e duplicada (hub, flags, impls do host)

- **Categoria:** architecture
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `super_app/lib/core/di/injection_container.dart:L34-L50` (dois `AppConfig`)
  - `super_app/lib/core/di/injection_container.dart:L99-L111`
  - `packages/core/core_interfaces/lib/src/base_micro_app.dart:L1-L5`
  - `packages/core/core_feature_flags/lib/src/feature_flags_service_impl.dart:L53-L56`
  - `super_app/lib/main.dart:L163-L178`
- **Ticket:** TCK-0007

### Descrição

`ApplicationHub` está no GetIt; nenhum micro-app chama `publish`/`subscribe` (grep só nas impls). `isEnabled` de flags não é chamado fora da impl; `FeatureFlagsServiceImpl` não é `CoreLibrary`, então o init só loga warning. Host registra `AppConfig.development()` sem consumidor; `super_app/lib/core/services/network_service_impl.dart` e `storage_service_impl.dart` não entram no container. `BaseMicroApp` importa `micro_app_dependencies.dart` inexistente; `core_interfaces` importa `get_it` sem declará-lo. Payments tem `presentation/bloc` + `presentation/cubits` e `data/sources` + `data/datasources`.

### Impacto concreto

Custo de manutenção e onboarding: contratos que “existem” mas não governam o runtime. Import quebrado em `core_interfaces` é bomba-relógio de analyze.

### Área de negócio afetada

Plataforma / DX.

### Dependências entre findings

- related: [FND-0006]
- related_drift: DRIFT-20260812-05

---

## FND-0008 — CI não dispara no `master` e pinna Flutter incompatível

- **Categoria:** reliability
- **Severidade:** high
- **Confiança:** confirmed
- **Evidência:**
  - `.github/workflows/ci_cd.yaml:L3-L18`
  - `super_app/pubspec.yaml:L6-L8`
  - `README.md:L5-L8`
  - `melos.yaml:L17-L25`
- **Ticket:** TCK-0008

### Descrição

O workflow escuta `main`/`develop` e tags `v*`. O default deste clone é `master`. Flutter no CI é `3.19.x`; o host exige `>=3.29.2`. `CONTRIBUTING` cita `melos run format` / `test:coverage` que não existem no `melos.yaml`.

### Impacto concreto

Push/PR no branch que o GitHub mostra como default **não roda** analyze/test/build. Mesmo se alguém criar `main`, o pin 3.19 pode recusar o constraint do host.

### Área de negócio afetada

Qualidade do repositório de referência; confiança de quem faz fork.

### Dependências entre findings

- related: [FND-0009, FND-0011]
- related_drift: DRIFT-20260812-03, DRIFT-20260812-04

---

## FND-0009 — Testes de PIX/pagamentos exercitam mocks, não regras de domínio

- **Categoria:** test-coverage
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/pix/test/presentation/bloc/pix_bloc_test.dart:L396-L429`
  - `packages/micro_apps/pix/lib/src/domain/usecases/send_pix_usecase.dart:L13-L26`
  - ausência de `integration_test/`
- **Ticket:** TCK-0009

### Descrição

Há 10 `*_test.dart`. PIX testa o BLoC com `SendPixUseCase` mockado (happy + fail genérico). O use case em si não tem teste de invariante. Não há `integration_test/` do fluxo splash→login→dashboard. Auth está melhor (repo + página + erro de credencial).

### Impacto concreto

`SendPixUseCase` pode continuar pass-through para sempre sem o CI reclamar. Docs pedem 75%+; a métrica agregada não foi medida (instrumento `nao_medido`) — o finding é o **gap de caminho crítico**, não o percentual.

### Área de negócio afetada

PIX; pagamentos.

### Dependências entre findings

- related: [FND-0005]

---

## FND-0010 — Sem agregação de crash; debug de rota sempre ligado; logs sem correlação

- **Categoria:** observability
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `super_app/lib/core/router/app_router.dart:L46` (`debugLogDiagnostics: true`)
  - `super_app/lib/core/di/injection_container.dart:L103-L107`
  - `super_app/pubspec.yaml` (sem sentry/crashlytics)
  - `packages/core/core_feature_flags/lib/src/feature_flags_service_impl.dart:L27-L28` (`enable_crash_reporting` sem backend)
- **Ticket:** TCK-0010

### Descrição

Logging é `ConsoleLogHandler` + `print` nos mocks. Sem correlation id. `debugLogDiagnostics` do GoRouter está sempre true. Flag `enable_crash_reporting` não liga Sentry/Crashlytics. Sem métricas RED.

### Impacto concreto

Em um dispositivo de demo, falha de PIX só existe como snackbar. Diagnóstico de “não abre o dashboard” (FND-0004) não deixa trilha correlacionada.

### Área de negócio afetada

Operação do sample; debug de fork.

### Dependências entre findings

- related: [FND-0001]

---

## FND-0011 — Constraints de SDK e lint divergentes entre pacotes

- **Categoria:** dependency
- **Severidade:** medium
- **Confiança:** confirmed
- **Evidência:**
  - `super_app/pubspec.yaml:L6-L8` (`>=3.7.2` / Flutter `>=3.29.2`, `flutter_lints ^5.0.0`)
  - `packages/core/core_communication/pubspec.yaml` (`sdk: '>=3.0.0'`, `flutter_lints ^2.0.0`)
  - `packages/micro_apps/auth/pubspec.yaml` (`>=3.3.0` / `>=3.19.0`, `flutter_lints ^3.0.0`)
- **Ticket:** TCK-0011

### Descrição

Workspace Melos sem catalog de versões. Host, core “novo” e core “velho” pedem Dart/Flutter/`flutter_lints` diferentes. `go_router` é `^12.1.3` no host e `^12.1.1` em core_navigation. CVE scan (`dart pub outdated` / OSV) **não** foi executado neste audit — dimensão `nao_medido` para CVEs.

### Impacto concreto

`melos bootstrap` resolve o menor denominador; CI 3.19.x vs host 3.29.2 (FND-0008) é o sintoma. Analyze local pode passar onde o CI (se um dia rodar) falha.

### Área de negócio afetada

Build / DX.

### Dependências entre findings

- related: [FND-0008]

---

## FND-0012 — HydratedCubit de pagamentos acessa storage antes do init (web)

- **Categoria:** reliability
- **Severidade:** high
- **Confiança:** confirmed
- **Evidência:**
  - `packages/micro_apps/payments/lib/src/payments_micro_app.dart:L85-L132` (`if (!kIsWeb)` + `PaymentsCubit()`)
  - `packages/micro_apps/payments/lib/src/presentation/cubits/payments_cubit.dart:L10-L23` (`HydratedCubit` → `hydrate()`)
  - `super_app/lib/core/router/route_middleware.dart:L132-L136` (catch → `/error`)
  - Run Chrome 2026-08-12: `Storage was accessed before it was initialized` ao abrir `#/payments`
- **Ticket:** TCK-0012

### Descrição

`PaymentsCubit` é `HydratedCubit`. O storage só é criado fora da web. No Chrome o construtor chama `hydrate()` com `HydratedBloc.storage == null` e lança `StorageNotFound`. O middleware redireciona para `#/error`.

Padrão similar: `hydrated_bloc` está no pubspec de auth/cards/dashboard/pix/account/design_system sem `HydratedCubit` (exceto payments). `AuthBloc` importa `hydrated_bloc` e estende `Bloc`. Há um `PaymentsCubit` morto em `presentation/bloc/` (Cubit comum) que não é o usado em runtime.

### Impacto concreto

Aba Pagamentos no web é inutilizável. Qualquer `HydratedCubit` futuro herda o mesmo crash se o host não bootstrapar storage.

### Área de negócio afetada

Pagamentos (listagem / criação / histórico) no target web.

### Dependências entre findings

- related: [FND-0008]
