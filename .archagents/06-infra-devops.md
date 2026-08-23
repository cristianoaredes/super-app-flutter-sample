# 06 — Infra e DevOps AS-IS

## Monorepo

Ferramenta: **Melos 3.x** (`pubspec.yaml:L9-L10`, `melos.yaml`).

```
packages:
  - packages/core/**
  - packages/shared/**
  - packages/micro_apps/**
  - packages/plugins/**    # pasta inexistente
  - super_app
```

Scripts (`melos.yaml:L17-L37`):

| Script | Comando |
|---|---|
| analyze | `flutter analyze --no-fatal-infos` em todos os pacotes |
| test | `flutter test` (`failFast: true`) |
| build_runner | `flutter pub run build_runner build --delete-conflicting-outputs` |
| version | `melos version` |
| publish | `melos publish` |

`bootstrap.usePubspecOverrides: true`. `sdkPath: auto`. Nome interno do workspace no Melos: `flutter_arqt` (`melos.yaml:L1-L2`); `repository:` no Melos aponta `github.com/cristianoaredes/flutter_arqt`; o remoto deste clone é `super-app-flutter-sample`.

`CONTRIBUTING.md` / onboarding citam `melos run format` e `melos run test:coverage` — **esses scripts não existem** em `melos.yaml`.

CI **não** usa filtro affected-only (rebuilda tudo) — equivalente MONO-004.

## CI/CD

Arquivo único: `.github/workflows/ci_cd.yaml`.

**Triggers** (`ci_cd.yaml:L3-L8`): push/PR em `master`, `main`, `develop`; tags `v*`. Flutter pin `3.29.2`.

**Branch default do git remoto:** `master` (working tree `master...origin/master`). **O workflow nunca dispara no default atual** — anomalia alta.

Jobs:

1. `analyze_and_test` — Ubuntu, Flutter **3.19.x** (`ci_cd.yaml:L16-L18`), `melos bootstrap`, `melos run build_runner`, `analyze`, `test`, upload Codecov.
2. `build_android` — se push `main` ou tag `v*`: `flutter build apk --release` em `super_app`, artifact `app-release`.
3. `build_ios` — macos, `flutter build ios --release --no-codesign`.
4. `publish_packages` — em tag `v*`: escreve credentials de pub privado placeholder + `melos run publish`.

Actions pinadas em `v3` (`actions/checkout@v3`, `codecov/codecov-action@v3`, `upload-artifact@v3`).

## Versões Flutter/Dart (drift interno)

| Fonte | Flutter | Dart |
|---|---|---|
| README | 3.29.2 | 3.7.2 |
| `super_app/pubspec.yaml` | `>=3.29.2` | `>=3.7.2 <4.0.0` |
| vários core/micro-apps | `>=3.19.0` | `>=3.3.0` |
| communication/flags/logging/navigation | `>=3.10.0` | `>=3.0.0` |
| CI | `3.19.x` | (do SDK da action) |

Sem `.fvm/`. Sem Codemagic/Bitrise/Fastlane.

## Ambientes / flavors

- `Environment` {development, staging, production} no contrato (`app_config.dart:L24-L28`).
- Host **sempre** registra `AppConfig.development()` + config de interfaces `environment: development` (`injection_container.dart:L34-L50`).
- Sem `main_dev.dart` / `main_prod.dart`.
- Sem `productFlavors` verificados no host. [A CONFIRMAR COM HUMANO] schemes iOS de flavor.

## Secrets

| Secret | Onde | Uso |
|---|---|---|
| `PUB_TOKEN` | GitHub Actions secret | job `publish_packages` (`ci_cd.yaml:L104`) |
| credenciais de demo | código-fonte | `user@example.com` / `password` |

Sem `.env` / `flutter_dotenv`. Sem keystore de release versionado (não inspecionado o `key.properties` — [A CONFIRMAR]).

## Observabilidade

- Logs: console (`ConsoleLogHandler`).
- Analytics: mock (web) ou `AnalyticsServiceImpl` (não-web) sem backend terceiro.
- `PerformanceMonitor` local, off em `production` (`injection_container.dart:L113-L120`).
- Codecov no CI — cobertura **não** medida neste bootstrap (não inventar %).
- Sem tracing/OpenTelemetry, sem dashboards.

## Como rodar (documentado no README)

```
flutter pub get          # raiz
cd super_app && flutter pub get && flutter run
```

README **não** exige `melos bootstrap`, embora o CI exija. Duas receitas.

## Análise estática

Um único `analysis_options.yaml` em `super_app/` incluindo `package:flutter_lints/flutter.yaml`, sem `strict-casts` / `very_good_analysis`. Pacotes filhos dependem do default do `flutter_lints` da respectiva versão (2.x / 3.x / 5.x).

## Testes

10 arquivos `*_test.dart`: auth (3), dashboard (2), account/cards/payments/pix/super_app (1 cada). Sem `integration_test/`. Sem golden.

## Leftovers de plataforma na raiz

`android/`, `ios/`, `web/` no root (além de `super_app/android|ios|macos|web`). `.gitignore` referencia `/android/app/debug` da raiz.

## Arquivos-fonte desta seção

- `melos.yaml`
- `pubspec.yaml`
- `super_app/pubspec.yaml`
- `.github/workflows/ci_cd.yaml`
- `README.md`
- `super_app/analysis_options.yaml`
- `super_app/lib/core/di/injection_container.dart`
