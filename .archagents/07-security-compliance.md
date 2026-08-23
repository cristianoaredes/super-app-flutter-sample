# 07 — Segurança e compliance AS-IS

> Contexto: **sample / referência**, não instituição financeira. Implicações Bacen/LGPD abaixo são *do que o código simula*, não de um produto em produção. `docs/security/SECURITY.md` descreve práticas **alvo** (secure storage, defense in depth) que **não** estão ligadas no host.

## AuthN / AuthZ

**AuthN (dois caminhos):**

1. Micro-app `auth`: `LoginUseCase` → `AuthRepository` → `AuthMockDataSource` se `mock_data: true` (`auth_injector` + `injection_container.dart:L45-L48`). Credencial aceita: email `user@example.com`, senha `password` (`auth_mock_datasource.dart:L19-L26`). Google/Apple: sempre suceder no mock, sem OAuth.
2. Host `AuthServiceImpl`: mesmo par email/senha; grava `_accessToken = 'fake_token'` e `_userId = 'user_123'` **em memória** (`auth_service_impl.dart:L18-L29`). `refreshToken()` troca para `'new_fake_token'` (`L42-L51`). Sem persistência, sem expiry, sem refresh rotativo real.

**AuthZ:** sem roles. Prefixo de negócio (`/dashboard`, `/pix`, `/payments`, `/cards`, `/account`) exige `AuthService.isAuthenticated`; caso contrário redirect `/login` (`authRedirectForPath`). Rotas públicas: `/`, `/login`, `/register`, `/reset-password`, `/error`.

Sessão: `AuthBloc` chama `AuthService.establishSession` no login; repositório grava token `session_<userId>` no secure storage; user JSON também vai para secure storage (não SharedPreferences).

## Segredos e credenciais no código

| Item | Local | Classificação |
|---|---|---|
| Senha de demo `password` | `auth_service_impl.dart:L22`, `auth_mock_datasource.dart:L19`, `README.md:L174-L177`, comentário em `auth_micro_app.dart:L20-L23` | sample intencional; **não** é secret de produção, mas é credencial em fonte |
| Tokens `fake_token` / `new_fake_token` | `auth_service_impl.dart:L23`, `L47` | placeholder |
| `PUB_TOKEN` | CI (`ci_cd.yaml:L104`) | secret de GitHub; o **hostname** do pub é placeholder |
| Password logado em debug | removido no drain TCK-0001 | — |

Grep de `apiKey`/`secret`/`password` em Dart encontra sobretudo estes mocks e validators — não uma chave de cloud. **Não copiar valores para traces.**

## Criptografia

- **Em trânsito:** Dio usa HTTPS na base URL de exemplo. **Certificate pinning ausente** (sem `badCertificateCallback` / pinning no `core_network`). FLUTTER-009.
- **Em repouso:** `flutter_secure_storage` implementado em `core_security` (`secure_storage_service.dart:L10-L21`, Keychain / EncryptedSharedPreferences) e também em `core_storage`. Host registra `StorageServiceImpl()` / `WebStorageService()` — **não** o secure storage (`injection_container.dart:L76-L78`). Token de auth **não** vai para storage.
- **Em memória:** `Card` não carrega mais CVV (removido do entity).

## Dados sensíveis (PII)

Modelo carrega CPF/CNPJ (`PixKeyType`, `PixKey._formatCpf`), `holderDocument`, `PixParticipant.document`, número de cartão + CVV, e-mail. Tudo em sample/mock.

`LoggingInterceptor` registra **headers e body** do request (`logging_interceptor.dart:L12-L35`) — se um client real for ligado, Authorization e payload vazam no log/console.

## LGPD (aparente)

Não há: tela de consentimento, base legal, opt-in de analytics ligado a UI, fluxo de exclusão, DSR, retention policy no código. Flag `enable_analytics` default `!kDebugMode` (`feature_flags_service_impl.dart:L27`) — em release ficaria on sem consent UI.

Tratar como **ausência**, não como conformidade.

## Conformidade setorial (Bacen / PIX)

O domínio **simula** PIX (chaves, E2E id, QR estático/dinâmico, send/receive) sem:

- cliente DICT
- certificado ICP-Brasil
- segregação homolog/produção Bacen
- rate limit de iniciação
- limites regulamentares no `SendPixUseCase` (pass-through puro)

Resolução 4.658 etc. **não se aplicam a este binário** enquanto sample. Qualquer fork que ligue API real precisa de threat model novo (piso SC-3 / área sensível).

## Superfície agentic / MCP

Sem `mcpServers` no repo, sem `_capabilities.json`. SC-9 não dispara neste codebase.

## Superfície nativa

Permissões Android/iOS: [A CONFIRMAR COM HUMANO] inventário completo de `AndroidManifest` / `Info.plist` do host `super_app` vs leftovers da raiz. `core_security` puxa `local_auth` e `device_info_plus` mas o host não depende do pacote.

ProGuard/R8: não verificado neste bootstrap (`android/app/proguard-rules.pro` do host). [A CONFIRMAR]

Root/jailbreak detection: não encontrada.

## Docs vs código (drift de segurança)

`docs/security/SECURITY.md:L41-L79` ensina `FlutterSecureStorage` como prática do app. O host **não** usa essa classe. Registrar como divergência permanente até alguém ligar `core_security`.

## Candidatos a finding (assessment)

| Sev | Tema | Evidência |
|---|---|---|
| high (se alguém ligar API real) | AuthZ ausente nas rotas | `route_middleware.dart` |
| medium | Senha impressa em debug | `auth_mock_datasource.dart:L12-L15` |
| medium | Interceptor loga headers/body | `logging_interceptor.dart:L18-L34` |
| medium | CVV no entity | `card.dart:L11` |
| medium | Token só em memória + fake | `auth_service_impl.dart:L3-L29` |
| medium | `core_security` morto | não está no pubspec do host |
| low | Pinning ausente | `network_service_impl.dart` |
| info | Credencial de demo no README | esperado num sample |

## Arquivos-fonte desta seção

- `super_app/lib/core/services/auth_service_impl.dart`
- `packages/micro_apps/auth/lib/src/data/datasources/auth_mock_datasource.dart`
- `packages/core/core_network/lib/src/interceptors/logging_interceptor.dart`
- `packages/core/core_security/lib/src/services/secure_storage_service.dart`
- `packages/micro_apps/cards/lib/src/domain/entities/card.dart`
- `docs/security/SECURITY.md`
- `super_app/lib/core/router/route_middleware.dart`
