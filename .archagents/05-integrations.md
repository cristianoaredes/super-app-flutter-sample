# 05 — Integrações AS-IS

Este repositório é um **sample**. As “integrações” são abstrações + mocks. Não há SDK de banco, DICT, PSP, Firebase ou analytics de terceiros ligado no host.

## HTTP / API REST (placeholder)

| Campo | Valor | Evidência |
|---|---|---|
| Tipo | `api-rest` (Dio) | `packages/core/core_network/lib/src/network_service_impl.dart:L1-L70` |
| Base URL | `https://api.dev.example.com/v1` | `super_app/lib/core/di/injection_container.dart:L38-L49` |
| Auth | interceptor opcional `AuthInterceptor` se `AuthService` passado a `createClient` | `network_service_impl.dart:L58-L61` |
| Timeouts | connect/receive/send 30s | `network_service_impl.dart:L44-L49` |
| Interceptors | Logging, Error; Auth e Cache opcionais | `network_service_impl.dart:L26-L68` |
| Consumidores | datasources `*_remote_datasource.dart` dos micro-apps, **quando** `mock_data != true` | `auth_injector.dart` (flag `mock_data`) |
| Runtime atual | `mock_data: true` + `NetworkServiceImpl.initialize()` **não** chamado no boot | `injection_container.dart:L45-L48`, `L72-L74` |

Factories `staging`/`production` existem no `AppConfig` **do host** (`https://api.staging.example.com/v1`, `https://api.example.com/v1`) e **não** são registradas no `init()`. Docs/`SecurityConfig` mencionam `api.premiumbank.com` — Dio **não** usa essas URLs.

Paths relativos dos remote DS (só se `mock_data` for false):

- Auth: `POST /auth/login`, `/auth/google`, `/auth/apple`, `/auth/register`, `/auth/reset-password`, `/auth/refresh-token`
- Account: `GET /account`, `/account/balance`, `/account/statement`; `POST /account/transfer`
- Dashboard: `GET /dashboard/account-summary`, `/dashboard/transaction-summary`, `/dashboard/quick-actions`
- Cards: `GET /cards`, `/cards/:id`, `/cards/:id/statement`; `POST /cards/:id/block`, `/cards/:id/unblock`
- Payments: `GET /payments`, `/payments/:id`; `POST /payments`; `DELETE /payments/:id`
- Pix: `GET/POST/DELETE /pix/keys`; `POST /pix/send`, `/pix/receive`, `/pix/qrcode/generate`, `/pix/qrcode/read`

`AuthInterceptor` só manda `Authorization: Bearer` se `AuthService.isAuthenticated`. Como o login do micro-app não seta o `AuthService` do host, o Bearer **não** é anexado após login na UI.

## Storage local

| Integração | Pacote | Tipo | Onde | Observação |
|---|---|---|---|---|
| SharedPreferences | `shared_preferences` | sdk-terceiro | `core_storage`, host `super_app/pubspec.yaml:L65` | `StorageServiceImpl` no host não-web |
| Web storage | implementação própria | — | `super_app/lib/core/services/web_storage_service.dart` | escolhida se `kIsWeb` (`injection_container.dart:L76-L78`) |
| Hive | `hive` / `hive_flutter` | sdk-terceiro | `core_storage`, `core_network` (cache) | cache de HTTP opcional |
| flutter_secure_storage | `flutter_secure_storage` | sdk-terceiro | `core_storage` e `core_security` | **host não registra** `SecureStorageServiceImpl` de `core_security` |

## Analytics

| Campo | Valor | Evidência |
|---|---|---|
| Tipo | `analytics` | `core_analytics` |
| Web | `MockAnalyticsService` | `injection_container.dart:L80-L83` |
| Não-web | `AnalyticsServiceImpl` | `injection_container.dart:L85-L88` |
| Init | só se storage inicializou; via `CoreLibrary.initialize` | `main.dart:L113-L126` |
| Terceiros | nenhum (sem Firebase/Amplitude/Mixpanel no pubspec do host) | `super_app/pubspec.yaml` |

## Feature flags

Tipo: serviço local (não LaunchDarkly/Firebase Remote Config). `FeatureFlagsServiceImpl.synchronize()` é no-op com delay (`feature_flags_service_impl.dart:L91-L94`). Nenhum micro-app chama `isEnabled`. A impl **não** é `CoreLibrary`, então o init do host só registra o warning (`main.dart:L163-L178`).

## Event bus interno

`ApplicationHub` / `ApplicationHubImpl` (`core_communication`). Não é integração externa; é IPC in-process.

## Auth social (stubs)

`LoginUseCase.executeWithGoogle` / `executeWithApple` (`login_usecase.dart:L16-L23`) delegam ao repositório. Mock devolve usuários fake sem `google_sign_in` / `sign_in_with_apple` no `pubspec` de `auth`. **Não** há SDK social instalado.

## PIX / pagamentos brasileiros

Não há pacote `efi_pay`, `pagseguro`, `mercadopago` ou cliente DICT/Bacen. PIX é domínio + mock datasource (`packages/micro_apps/pix/lib/src/data/datasources/`). Tipo efetivo: **nenhuma integração externa de pagamento**.

## Logging / crash

`ConsoleLogHandler` no host (`injection_container.dart:L103-L105`). Flag `enable_crash_reporting` existe mas **não** há Sentry/Crashlytics no pubspec do host.

## Push / biometria / maps

Flags `enable_push_notifications` e `enable_biometrics` existem. `local_auth` está só em `core_security` (não wired). Sem `firebase_messaging` / `onesignal` no host.

## Pub privado (CI)

Job `publish_packages` escreve `~/.pub-cache/credentials.json` para `https://seu-servidor-pub-privado.com` com `${{ secrets.PUB_TOKEN }}` (`.github/workflows/ci_cd.yaml:L97-L107`). Placeholder — servidor não existe neste repo.

## Performance monitor

`PerformanceMonitor` local, habilitado fora de `production` (`injection_container.dart:L113-L130`). Não é APM externo.

## Arquivos-fonte desta seção

- `super_app/lib/core/di/injection_container.dart`
- `super_app/pubspec.yaml`
- `packages/core/core_network/lib/src/network_service_impl.dart`
- `packages/core/core_feature_flags/lib/src/feature_flags_service_impl.dart`
- `.github/workflows/ci_cd.yaml`
- `packages/micro_apps/auth/lib/src/di/auth_injector.dart`
