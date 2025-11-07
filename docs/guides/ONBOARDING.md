# Guia de Onboarding - Premium Bank Super App

Bem-vindo ao time de desenvolvimento do Premium Bank Super App! Este guia vai te ajudar a configurar seu ambiente e entender como contribuir para o projeto.

## Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Configuração do Ambiente](#configuração-do-ambiente)
3. [Estrutura do Projeto](#estrutura-do-projeto)
4. [Primeiro Build](#primeiro-build)
5. [Entendendo a Arquitetura](#entendendo-a-arquitetura)
6. [Desenvolvimento Local](#desenvolvimento-local)
7. [Criando um Novo Micro App](#criando-um-novo-micro-app)
8. [Rodando Testes](#rodando-testes)
9. [Fluxo de Trabalho](#fluxo-de-trabalho)
10. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

### Software Necessário

- **Flutter SDK**: 3.29.2 ou superior
- **Dart SDK**: 3.7.2 ou superior (incluído no Flutter)
- **IDE**: VS Code ou Android Studio
- **Git**: Para controle de versão
- **Melos**: Para gerenciamento de monorepo

### Verificando Instalações

```bash
# Verificar Flutter
flutter --version
# Deve mostrar: Flutter 3.29.2 ou superior

# Verificar Dart
dart --version
# Deve mostrar: Dart 3.7.2 ou superior

# Verificar Git
git --version

# Instalar Melos globalmente
dart pub global activate melos

# Verificar Melos
melos --version
```

### Conhecimentos Recomendados

- ✅ Dart básico/intermediário
- ✅ Flutter widgets e navegação
- ✅ BLoC/Cubit pattern
- ✅ Clean Architecture
- ✅ Git flow básico
- 📚 Testes (será aprendido no projeto)
- 📚 Arquitetura de micro apps (será aprendido no projeto)

---

## Configuração do Ambiente

### 1. Clonar o Repositório

```bash
# Clone o repositório
git clone https://github.com/your-org/super-app-flutter-sample.git
cd super-app-flutter-sample
```

### 2. Configurar o Monorepo

```bash
# Bootstrap do Melos (instala dependências de todos os pacotes)
melos bootstrap

# Isso vai:
# - Instalar dependências de todos os pacotes
# - Linkar pacotes locais
# - Gerar arquivos necessários
```

### 3. Gerar Código (Build Runner)

```bash
# Gerar código para todos os pacotes
melos run build_runner

# Ou para um pacote específico
cd packages/micro_apps/auth
dart run build_runner build --delete-conflicting-outputs
```

### 4. Configurar IDE

#### VS Code

Instale as extensões:
- **Flutter** (Dart-Code.flutter)
- **Dart** (Dart-Code.dart-code)
- **Bloc** (FelixAngelov.bloc)
- **Error Lens** (usernamehw.errorlens)

Configuração recomendada (`.vscode/settings.json`):
```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  "[dart]": {
    "editor.rulers": [80],
    "editor.tabSize": 2
  }
}
```

#### Android Studio

Instale os plugins:
- **Flutter**
- **Dart**
- **Bloc**

---

## Estrutura do Projeto

```
super-app-flutter-sample/
├── .github/              # CI/CD workflows
├── docs/                 # Documentação
│   ├── architecture/     # Docs de arquitetura
│   └── guides/          # Guias e tutoriais
├── packages/
│   ├── core/            # Pacotes core (interfaces, network, storage)
│   ├── shared/          # Pacotes compartilhados (design system, utils)
│   └── micro_apps/      # Micro apps (auth, dashboard, payments, etc)
├── super_app/           # Aplicativo principal
├── melos.yaml           # Configuração do Melos
├── PLAN.md              # Plano de desenvolvimento
├── TODO-*.md            # TODOs categorizados
└── README.md            # README principal
```

### Pacotes Importantes

#### Core Packages

| Pacote | Descrição |
|--------|-----------|
| `core_interfaces` | Interfaces compartilhadas, BaseMicroApp, exceções |
| `core_network` | Cliente HTTP, interceptors |
| `core_storage` | Persistência local (SharedPreferences, Hive) |
| `core_analytics` | Tracking de eventos |

#### Shared Packages

| Pacote | Descrição |
|--------|-----------|
| `design_system` | Componentes UI, temas, cores |
| `shared_utils` | Utilitários, extensions, validators |

#### Micro Apps

| Micro App | Funcionalidade |
|-----------|---------------|
| `auth` | Autenticação (login, registro, reset senha) |
| `dashboard` | Dashboard principal, resumo da conta |
| `payments` | Pagamentos e boletos |
| `pix` | Transferências PIX |
| `cards` | Gerenciamento de cartões |
| `account` | Conta bancária, extrato |
| `splash` | Tela inicial |

---

## Primeiro Build

### 1. Build do Aplicativo

```bash
# Voltar para a raiz do projeto
cd super-app-flutter-sample

# Entrar no diretório do app
cd super_app

# Verificar dispositivos disponíveis
flutter devices

# Rodar em modo debug
flutter run

# Ou especificar dispositivo
flutter run -d chrome     # Web
flutter run -d macos      # macOS
flutter run -d <device-id> # Dispositivo específico
```

### 2. Hot Reload

Durante o desenvolvimento:
- **r**: Hot reload (recarrega código)
- **R**: Hot restart (reinicia app)
- **q**: Quit

### 3. Build de Produção

```bash
# Android
flutter build apk --release

# iOS (requer macOS)
flutter build ios --release

# Web
flutter build web --release
```

---

## Entendendo a Arquitetura

### Micro Apps Pattern

Cada funcionalidade é um **micro app independente**:

```dart
/// 1. Interface MicroApp
abstract class MicroApp {
  String get id;
  String get name;
  Future<void> initialize(MicroAppDependencies dependencies);
  Map<String, GoRouteBuilder> get routes;
  Future<void> dispose();
}

/// 2. Implementação usando BaseMicroApp
class AuthMicroApp extends BaseMicroApp {
  AuthBloc? _authBloc;

  @override
  String get id => 'auth';

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Setup de dependências
    AuthInjector.register(getIt);
    _authBloc = getIt<AuthBloc>();
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
    '/login': (context, state) => const LoginPage(),
    '/register': (context, state) => const RegisterPage(),
  };
}
```

### Clean Architecture Layers

```
lib/
└── src/
    ├── domain/           # Regras de negócio (puras)
    │   ├── entities/    # Objetos de negócio
    │   ├── repositories/# Contratos
    │   └── usecases/    # Casos de uso
    │
    ├── data/            # Implementação de dados
    │   ├── models/      # DTOs
    │   ├── datasources/ # APIs, Local Storage
    │   └── repositories/# Implementações
    │
    └── presentation/    # UI
        ├── bloc/        # Gerenciamento de estado
        ├── pages/       # Telas
        └── widgets/     # Componentes
```

### Fluxo de Dados

```
User Action → BLoC Event → UseCase → Repository → DataSource
                                                       ↓
User sees ← UI Update ← BLoC State ← Entity ← Model ←┘
```

Para mais detalhes, leia [ARCHITECTURE.md](../architecture/ARCHITECTURE.md).

---

## Desenvolvimento Local

### Scripts Úteis do Melos

```bash
# Ver todos os comandos disponíveis
melos run

# Analisar código
melos run analyze

# Formatar código
melos run format

# Rodar testes
melos run test

# Rodar testes com cobertura
melos run test:coverage

# Limpar todos os pacotes
melos clean

# Build runner para todos os pacotes
melos run build_runner

# Pub get para todos os pacotes
melos bootstrap
```

### Desenvolvimento de um Micro App

#### 1. Navegue para o micro app

```bash
cd packages/micro_apps/auth
```

#### 2. Faça suas alterações

```bash
# Abra no VS Code
code .
```

#### 3. Rode testes localmente

```bash
# Testes do micro app
flutter test

# Com cobertura
flutter test --coverage
```

#### 4. Verifique análise

```bash
flutter analyze
```

---

## Criando um Novo Micro App

### 1. Criar Estrutura de Diretórios

```bash
cd packages/micro_apps
mkdir -p new_feature/lib/src/{domain,data,presentation,di}
mkdir -p new_feature/test/{domain,data,presentation}
```

### 2. Criar pubspec.yaml

```yaml
name: new_feature
description: Descrição do micro app
version: 0.1.0
publish_to: none

environment:
  sdk: ">=3.3.0 <4.0.0"
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter

  # Core packages
  core_interfaces:
    path: ../../core/core_interfaces

  # Shared packages
  design_system:
    path: ../../shared/design_system
  shared_utils:
    path: ../../shared/shared_utils

  # State management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.7

  # DI
  get_it: ^7.6.4

  # Navigation
  go_router: ^12.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.2
  bloc_test: ^9.1.4
  build_runner: ^2.4.6
```

### 3. Implementar MicroApp

```dart
// lib/src/new_feature_micro_app.dart
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';

class NewFeatureMicroApp extends BaseMicroApp {
  NewFeatureBloc? _bloc;

  NewFeatureMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'new_feature';

  @override
  String get name => 'New Feature';

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Register dependencies
    NewFeatureInjector.register(getIt);
    _bloc = getIt<NewFeatureBloc>();
  }

  @override
  Future<void> onDispose() async {
    await _bloc?.close();
    _bloc = null;
  }

  @override
  Future<bool> checkHealth() async {
    if (_bloc == null) return false;
    try {
      return _bloc!.state != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
    '/new-feature': (context, state) => const NewFeaturePage(),
  };

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return const NewFeaturePage();
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register(_bloc!);
  }
}
```

### 4. Registrar no App Principal

```dart
// super_app/lib/main.dart
void setupMicroApps(GetIt getIt) {
  // ... outros micro apps ...

  getIt.registerLazySingleton<MicroApp>(
    () => NewFeatureMicroApp(getIt: getIt),
    instanceName: 'new_feature',
  );
}
```

### 5. Adicionar Testes

Veja exemplos em:
- `packages/micro_apps/auth/test/`
- `packages/micro_apps/dashboard/test/`

---

## Rodando Testes

### Testes Unitários

```bash
# Todos os testes
melos run test

# Micro app específico
cd packages/micro_apps/auth
flutter test

# Arquivo específico
flutter test test/presentation/bloc/auth_bloc_test.dart

# Com cobertura
flutter test --coverage
```

### Testes de Widget

```bash
# Rodar testes de widget
flutter test test/presentation/pages/

# Com verbose
flutter test --verbose
```

### Cobertura de Testes

```bash
# Gerar cobertura
flutter test --coverage

# Ver cobertura (requer lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Metas de Cobertura

Seguindo a estratégia de testes:
- **Unit Tests**: 50% do esforço
- **Widget Tests**: 30% do esforço
- **Integration Tests**: 15% do esforço
- **E2E Tests**: 5% do esforço

---

## Fluxo de Trabalho

### 1. Pegar uma Task

```bash
# Criar branch a partir da main
git checkout main
git pull origin main
git checkout -b feature/nova-funcionalidade
```

### 2. Desenvolver

```bash
# Fazer alterações
# ...

# Ver status
git status

# Adicionar mudanças
git add .

# Commitar
git commit -m "feat: adiciona nova funcionalidade"
```

### 3. Testar

```bash
# Rodar testes
melos run test

# Analisar código
melos run analyze

# Verificar formatação
melos run format --set-exit-if-changed
```

### 4. Push e PR

```bash
# Push para remote
git push origin feature/nova-funcionalidade

# Criar Pull Request no GitHub
# - Descreva as mudanças
# - Referencie issues relacionadas
# - Aguarde code review
```

### Conventional Commits

Use prefixos semânticos:
- `feat:` Nova funcionalidade
- `fix:` Correção de bug
- `refactor:` Refatoração de código
- `test:` Adição/modificação de testes
- `docs:` Alterações em documentação
- `chore:` Tarefas de manutenção
- `style:` Mudanças de formatação

Exemplos:
```bash
git commit -m "feat(auth): add biometric login"
git commit -m "fix(payments): correct amount calculation"
git commit -m "test(dashboard): add bloc tests"
git commit -m "docs: update onboarding guide"
```

---

## Troubleshooting

### Problema: `flutter packages get` falha

**Solução**:
```bash
# Limpar cache
flutter clean
flutter pub cache repair

# Reinstalar dependências
melos clean
melos bootstrap
```

### Problema: Build runner não gera mocks

**Solução**:
```bash
# Deletar arquivos gerados anteriormente
rm -rf **/*.g.dart **/*.mocks.dart

# Regenerar
dart run build_runner build --delete-conflicting-outputs
```

### Problema: Imports não resolvidos no IDE

**Solução**:
```bash
# Recarregar packages
flutter pub get

# VS Code: Ctrl+Shift+P → "Dart: Restart Analysis Server"
# Android Studio: File → Invalidate Caches → Restart
```

### Problema: Testes falhando com "Bad state: Cannot add new events after calling close"

**Solução**:
Certifique-se de chamar `bloc.close()` no `tearDown`:
```dart
tearDown(() {
  bloc.close();
});
```

### Problema: Hot reload não funciona

**Solução**:
```bash
# Hot restart completo
# Pressione 'R' no terminal

# Ou pare e inicie novamente
# Pressione 'q' e depois 'flutter run'
```

### Problema: Conflitos de versão entre pacotes

**Solução**:
```bash
# Ver dependências
melos list --graph

# Atualizar todas as dependências
melos exec -- flutter pub upgrade
```

---

## Recursos Adicionais

### Documentação do Projeto

- 📖 [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) - Arquitetura detalhada
- 📖 [TESTING_STRATEGY.md](TESTING_STRATEGY.md) - Estratégia de testes
- 📖 [MICRO_APP_STANDARDS.md](MICRO_APP_STANDARDS.md) - Padrões de micro apps
- 📖 [ERROR_HANDLING_GUIDE.md](ERROR_HANDLING_GUIDE.md) - Tratamento de erros

### Links Externos

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [BLoC Library](https://bloclibrary.dev/)
- [Clean Architecture (Uncle Bob)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

### Comunidade

- Slack: `#mobile-team`
- Reuniões: Diárias às 10h
- Code reviews: Pelo menos 2 approvals necessários

---

## Checklist do Primeiro Dia

- [ ] Clonar repositório
- [ ] Instalar Flutter 3.29.2+
- [ ] Instalar Melos
- [ ] Rodar `melos bootstrap`
- [ ] Rodar `melos run build_runner`
- [ ] Fazer primeiro build: `cd super_app && flutter run`
- [ ] Rodar testes: `melos run test`
- [ ] Ler ARCHITECTURE.md
- [ ] Explorar um micro app (recomendado: auth)
- [ ] Criar branch de teste
- [ ] Fazer commit de teste
- [ ] Pedir code review do seu buddy

---

## Próximos Passos

Após completar este onboarding:

1. ✅ Pair programming com um dev sênior
2. ✅ Pegar sua primeira task (bug fix recomendado)
3. ✅ Participar de uma code review
4. ✅ Apresentar seu trabalho no stand-up
5. ✅ Explorar todos os micro apps
6. ✅ Ler docs de teste e criar alguns testes
7. ✅ Contribuir para documentação

---

**Bem-vindo ao time! 🎉**

Se tiver dúvidas, não hesite em perguntar no Slack ou pedir ajuda ao seu buddy. Estamos aqui para ajudar!
