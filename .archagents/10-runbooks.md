# 10 — Runbooks

> Maioria `[A DETALHAR]`. Este sample não tem on-call. Procedimentos abaixo são os que o repositório documenta ou o CI executa.

## Dev: subir o app

**Receita README** (`README.md:L156-L169`):

```bash
git clone https://github.com/cristianoaredes/super-app-flutter-sample.git
cd super-app-flutter-sample
flutter pub get
cd super_app
flutter pub get
flutter run
```

**Receita CI** (`.github/workflows/ci_cd.yaml:L20-L28`):

```bash
dart pub global activate melos
melos bootstrap
melos run build_runner
# depois, no host:
cd super_app && flutter run
```

Credenciais de teste: `user@example.com` / `password` (`README.md:L174-L177`).

## Testes e análise

```bash
melos run analyze
melos run test
```

Host isolado: `cd super_app && flutter analyze && flutter test`.

## Build

- Android APK: `cd super_app && flutter build apk --release` (CI `build_android`).
- iOS: `cd super_app && flutter build ios --release --no-codesign` (CI `build_ios`).

Flavors: não há. Sempre `AppConfig.development()` + `mock_data: true`.

## Incidente: micro-app “Cannot emit after close” / estado inválido

Sintoma esperado pelo próprio middleware: `microApp.build(context)` lança → dispose + `initializeMicroApp` (`route_middleware.dart:L59-L94`). Se a reinicialização já está em curso, redirect para `/dashboard`. Falha de init → `/error`.

`[A DETALHAR]` métricas / logs estruturados para diagnosticar em dispositivo.

## Incidente: CI não roda no push

Branch default é `master`; workflow escuta `main`/`develop` (`ci_cd.yaml:L3-L8`). Push em `master` **não** dispara. Workaround: abrir PR contra `main` (se existir) ou alterar o workflow. `[A CONFIRMAR COM HUMANO]` se `main` ainda é usada.

## Incidente: Flutter 3.29 vs CI 3.19

Host `environment.flutter: ">=3.29.2"`. CI instala `3.19.x`. Risco: `melos bootstrap` / analyze falha no GitHub e passa local (ou o inverso). Alinhar pinos antes de tratar CI como gate.

## Rollback de release

Não há store listing, feature flag remoto nem pipeline de deploy de app. Job de publish de pacotes aponta pub privado placeholder — **não executar** como se fosse produção (SC-2).

## Secrets

Se `PUB_TOKEN` vazar: rotacionar no GitHub; o hostname no YAML é fictício. Credenciais demo **não** se rotacionam — são parte do sample.

## Alertas de registries de aprendizado

Nenhum `99-memory/regression-catalog` no projeto neste bootstrap.
