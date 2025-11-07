# 🔴 TODO - Issues Críticos (PRIORIDADE ALTA)

**Fase:** 1 - Fundação
**Prazo:** 2 semanas
**Status:** 🔴 Não iniciado

> ⚠️ **IMPORTANTE:** Estes issues devem ser resolvidos ANTES de adicionar novas features.
> Eles afetam a estabilidade, consistência e manutenibilidade do projeto.

---

## CRIT-001: Padronizar Gerenciamento de Ciclo de Vida dos BLoCs

### 📍 Descrição
Atualmente, diferentes micro apps implementam estratégias completamente diferentes para gerenciar o ciclo de vida dos BLoCs, causando inconsistência e possíveis memory leaks.

### 🎯 Objetivo
Estabelecer e implementar um padrão único de gerenciamento de ciclo de vida de BLoCs em todos os micro apps.

### 📂 Arquivos Afetados
- `/packages/micro_apps/pix/lib/src/pix_micro_app.dart` (linhas 33-68)
- `/packages/micro_apps/payments/lib/src/payments_micro_app.dart` (linhas 33-50)
- `/packages/micro_apps/auth/lib/src/auth_micro_app.dart`
- `/packages/micro_apps/dashboard/lib/src/dashboard_micro_app.dart`
- `/packages/micro_apps/cards/lib/src/cards_micro_app.dart`
- `/packages/micro_apps/account/lib/src/account_micro_app.dart`

### 🔍 Problema Atual

**PixMicroApp:** Fecha e recria BLoC a cada acesso
```dart
PixBloc get pixBloc {
  _ensureInitialized();
  // ❌ Sempre cria nova instância, fecha a anterior
  if (_pixBloc != null) {
    _pixBloc!.close();
  }
  _pixBloc = _getIt<PixBloc>();
  return _pixBloc!;
}
```

**PaymentsMicroApp:** Recria apenas se null
```dart
PaymentsCubit get paymentsCubit {
  if (_paymentsCubit == null) {
    _createCubit();
  }
  return _paymentsCubit!;
}
```

**AuthMicroApp:** Retorna instância sem verificações
```dart
AuthBloc get authBloc {
  if (!_initialized) {
    throw StateError(/*...*/);
  }
  return _authBloc!;
}
```

### ✅ Solução Proposta

#### Passo 1: Criar classe base abstrata

Criar arquivo: `/packages/core/core_interfaces/lib/src/base_micro_app.dart`

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'micro_app.dart';
import 'bloc_registry.dart';

/// Classe base abstrata que implementa padrões comuns para todos os micro apps
abstract class BaseMicroApp implements MicroApp {
  final GetIt getIt;
  bool _initialized = false;
  MicroAppDependencies? _dependencies;

  BaseMicroApp({GetIt? getIt}) : getIt = getIt ?? GetIt.instance;

  @override
  bool get isInitialized => _initialized;

  /// Retorna as dependências armazenadas
  MicroAppDependencies get dependencies {
    if (_dependencies == null) {
      throw StateError(
        '$name MicroApp não foi inicializado. Chame initialize() primeiro.',
      );
    }
    return _dependencies!;
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) {
      this.dependencies.loggingService?.warning(
        'MicroApp $name já foi inicializado. Ignorando nova inicialização.',
      );
      return;
    }

    _dependencies = dependencies;

    try {
      // Hook para inicialização customizada de cada micro app
      await onInitialize(dependencies);

      _initialized = true;

      dependencies.loggingService?.info(
        'MicroApp $name inicializado com sucesso',
      );
    } catch (e) {
      dependencies.loggingService?.error(
        'Erro ao inicializar MicroApp $name: $e',
      );
      rethrow;
    }
  }

  /// Hook para inicialização customizada. Subclasses devem implementar.
  @protected
  Future<void> onInitialize(MicroAppDependencies dependencies);

  @override
  Future<void> dispose() async {
    if (!_initialized) return;

    try {
      await onDispose();
      _initialized = false;
      _dependencies = null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Erro ao fazer dispose do MicroApp $name: $e',
      );
      rethrow;
    }
  }

  /// Hook para dispose customizado. Subclasses devem implementar.
  @protected
  Future<void> onDispose();

  @override
  Future<bool> isHealthy() async {
    if (!_initialized) return false;

    try {
      // Hook para verificações de saúde customizadas
      return await checkHealth();
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para MicroApp $name: $e',
      );
      return false;
    }
  }

  /// Hook para verificações de saúde customizadas.
  /// Por padrão, retorna true se estiver inicializado.
  @protected
  Future<bool> checkHealth() async => true;

  /// Garante que o micro app está inicializado
  @protected
  void ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        '$name MicroApp não foi inicializado. Chame initialize() primeiro.',
      );
    }
  }
}
```

#### Passo 2: Atualizar interface MicroApp

Adicionar método `isHealthy()` em `/packages/core/core_interfaces/lib/src/micro_app.dart`:

```dart
abstract class MicroApp {
  String get id;
  String get name;
  Map<String, GoRouteBuilder> get routes;
  bool get isInitialized => true;

  Future<void> initialize(MicroAppDependencies dependencies);
  Widget build(BuildContext context);
  void registerBlocs(BlocRegistry registry);
  Future<void> dispose();

  /// ✨ NOVO: Verifica se o micro app está em estado saudável
  /// Retorna true se o micro app está funcionando corretamente,
  /// false caso contrário (ex: BLoCs em estado inválido)
  Future<bool> isHealthy() async => isInitialized;
}
```

#### Passo 3: Refatorar AuthMicroApp para usar BaseMicroApp

```dart
class AuthMicroApp extends BaseMicroApp {
  AuthBloc? _authBloc;

  AuthMicroApp({GetIt? getIt}) : super(getIt: getIt);

  @override
  String get id => 'auth';

  @override
  String get name => 'Auth';

  // Getter simples que apenas retorna a instância
  AuthBloc get authBloc {
    ensureInitialized();
    return _authBloc!;
  }

  @override
  Map<String, GoRouteBuilder> get routes => {
    '/login': (context, state) {
      ensureInitialized();
      return BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const LoginPage(),
      );
    },
    // ... outras rotas
  };

  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // Registrar dependências específicas
    AuthInjector.register(getIt);

    // Criar BLoC
    _authBloc = getIt<AuthBloc>();
  }

  @override
  Future<void> onDispose() async {
    if (_authBloc != null) {
      await _authBloc!.close();
      _authBloc = null;
    }
  }

  @override
  Future<bool> checkHealth() async {
    if (_authBloc == null) return false;

    try {
      // Verifica se o BLoC está em estado válido
      final state = _authBloc!.state;
      return state != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return BlocProvider.value(
      value: authBloc,
      child: const LoginPage(),
    );
  }

  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register(authBloc);
  }
}
```

#### Passo 4: Aplicar padrão em todos os micro apps

Refatorar todos os micro apps para usar `BaseMicroApp`:
- ✅ AuthMicroApp
- ⏳ DashboardMicroApp
- ⏳ PaymentsMicroApp
- ⏳ PixMicroApp
- ⏳ CardsMicroApp
- ⏳ AccountMicroApp
- ⏳ SplashMicroApp

### 📋 Checklist de Implementação

- [ ] Criar classe `BaseMicroApp`
- [ ] Adicionar método `isHealthy()` à interface `MicroApp`
- [ ] Atualizar `AuthMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `DashboardMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `PaymentsMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `PixMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `CardsMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `AccountMicroApp` para usar `BaseMicroApp`
- [ ] Atualizar `SplashMicroApp` para usar `BaseMicroApp`
- [ ] Adicionar testes unitários para `BaseMicroApp`
- [ ] Adicionar testes para cada micro app refatorado
- [ ] Atualizar documentação (MICRO_APP_STANDARDS.md)
- [ ] Code review
- [ ] Merge

### 🧪 Testes Necessários

```dart
// test/core_interfaces/base_micro_app_test.dart
void main() {
  group('BaseMicroApp', () {
    test('should throw StateError if accessing dependencies before initialization', () {
      // ...
    });

    test('should initialize successfully with valid dependencies', () async {
      // ...
    });

    test('should not re-initialize if already initialized', () async {
      // ...
    });

    test('should return true for isHealthy after successful initialization', () async {
      // ...
    });

    test('should dispose successfully and reset state', () async {
      // ...
    });
  });
}
```

### 📊 Critérios de Sucesso

- ✅ Todos os micro apps herdam de `BaseMicroApp`
- ✅ Padrão de ciclo de vida consistente em todos os micro apps
- ✅ Método `isHealthy()` implementado em todos
- ✅ Testes cobrindo 100% da `BaseMicroApp`
- ✅ Zero memory leaks detectados em testes
- ✅ Documentação atualizada

### ⏱️ Estimativa de Esforço
**8-12 horas** de desenvolvimento + 4 horas de testes

---

## CRIT-002: Remover Lógica Hardcoded de Reinicialização

### 📍 Descrição
A função de inicialização sob demanda em `main.dart` contém lógica hardcoded específica para micro apps `payments` e `pix`, usando `dynamic` casts e violando type safety.

### 🎯 Objetivo
Usar o método `isHealthy()` implementado em CRIT-001 para verificação genérica de estado.

### 📂 Arquivos Afetados
- `/super_app/lib/main.dart` (linhas 199-284)
- `/super_app/lib/core/router/route_middleware.dart` (linhas 58-69)

### 🔍 Problema Atual

```dart
// ❌ RUIM: Lógica hardcoded e type-unsafe
if (microAppName == 'payments') {
  try {
    (microApp as dynamic).paymentsCubit;
    return;
  } catch (e) {
    await microApp.dispose();
  }
} else if (microAppName == 'pix') {
  try {
    (microApp as dynamic).pixBloc;
    return;
  } catch (e) {
    await microApp.dispose();
  }
}
```

### ✅ Solução Proposta

Substituir por:

```dart
// ✅ BOM: Type-safe e genérico
if (microApp.isInitialized) {
  final isHealthy = await microApp.isHealthy();

  if (isHealthy) {
    loggingService.info(
      'Micro app $microAppName já está inicializado e saudável',
    );
    return;
  }

  loggingService.warning(
    'Micro app $microAppName está em estado inválido, reinicializando',
  );

  try {
    await microApp.dispose();
  } catch (e) {
    loggingService.error(
      'Erro ao fazer dispose de $microAppName: $e',
    );
  }
}
```

### 📋 Checklist de Implementação

- [ ] Aguardar conclusão de CRIT-001 (depende de `isHealthy()`)
- [ ] Refatorar função em `main.dart` (linha 199-284)
- [ ] Refatorar middleware em `route_middleware.dart` (linha 58-69)
- [ ] Remover todo código com `as dynamic`
- [ ] Adicionar testes de integração para verificar reinicialização
- [ ] Code review
- [ ] Merge

### 🧪 Testes Necessários

```dart
// test/integration/micro_app_initialization_test.dart
void main() {
  group('MicroApp On-Demand Initialization', () {
    test('should initialize micro app on first access', () async {
      // ...
    });

    test('should not reinitialize if already healthy', () async {
      // ...
    });

    test('should reinitialize if unhealthy', () async {
      // ...
    });

    test('should handle initialization failures gracefully', () async {
      // ...
    });
  });
}
```

### 📊 Critérios de Sucesso

- ✅ Zero uso de `dynamic` casts
- ✅ Lógica genérica funciona para todos os micro apps
- ✅ Type safety preservada
- ✅ Testes de integração passando

### ⏱️ Estimativa de Esforço
**4-6 horas** de desenvolvimento + 2 horas de testes

---

## CRIT-003: Remover Duplicação de Lógica de Inicialização

### 📍 Descrição
Micro apps têm lógica de inicialização duplicada entre os métodos `initialize()` e `_ensureInitialized()`.

### 🎯 Objetivo
Consolidar lógica de inicialização e fazer `_ensureInitialized()` apenas validar estado.

### 📂 Arquivos Afetados
- `/packages/micro_apps/auth/lib/src/auth_micro_app.dart` (linhas 64-86)
- `/packages/micro_apps/dashboard/lib/src/dashboard_micro_app.dart` (linhas 65-87)
- Todos os outros micro apps com padrão similar

### 🔍 Problema Atual

```dart
// ❌ DUPLICAÇÃO
void _ensureInitialized() {
  if (!_initialized) {
    AuthInjector.register(_getIt);  // Duplicado
    _authBloc = _getIt<AuthBloc>();  // Duplicado
    _initialized = true;
  }
}

Future<void> initialize(MicroAppDependencies dependencies) async {
  if (_initialized) return;
  AuthInjector.register(_getIt);  // Duplicado
  _authBloc = _getIt<AuthBloc>();  // Duplicado
  _initialized = true;
}
```

### ✅ Solução Proposta

Com `BaseMicroApp` (de CRIT-001), isso é resolvido automaticamente:

```dart
// ✅ SEM DUPLICAÇÃO
@protected
void ensureInitialized() {
  if (!_initialized) {
    throw StateError('MicroApp não inicializado');
  }
}

Future<void> onInitialize(MicroAppDependencies dependencies) async {
  // Lógica de inicialização APENAS aqui
  AuthInjector.register(getIt);
  _authBloc = getIt<AuthBloc>();
}
```

### 📋 Checklist de Implementação

- [ ] Aguardar conclusão de CRIT-001
- [ ] Este issue será resolvido automaticamente ao usar `BaseMicroApp`
- [ ] Verificar que nenhum micro app tem lógica duplicada
- [ ] Code review
- [ ] Merge

### 📊 Critérios de Sucesso

- ✅ Zero duplicação de lógica entre métodos
- ✅ Inicialização acontece apenas via `initialize()`
- ✅ `ensureInitialized()` apenas valida estado

### ⏱️ Estimativa de Esforço
**Incluído em CRIT-001** (sem esforço adicional)

---

## CRIT-004: Implementar Política Consistente de Error Handling

### 📍 Descrição
O tratamento de erros é inconsistente em todo o projeto. Alguns lugares ignoram erros, outros re-lançam, alguns usam `debugPrint`, outros `LoggingService`.

### 🎯 Objetivo
Estabelecer e implementar política clara e consistente de error handling em todo o projeto.

### 📂 Arquivos Afetados
- Todos os micro apps
- Todos os services
- Todos os BLoCs/Cubits

### 🔍 Problema Atual

**Exemplo 1: Erro silencioso**
```dart
try {
  await _paymentsCubit!.close();
} catch (e) {
  // ❌ Ignora exceção
  debugPrint('Erro ao fechar PaymentsCubit: $e');
}
```

**Exemplo 2: Erro re-lançado**
```dart
} catch (e) {
  loggingService.error('Falha ao inicializar $microAppName: $e');
  throw Exception('Falha ao inicializar $microAppName: $e'); // ✅ Re-lança
}
```

### ✅ Solução Proposta

#### Passo 1: Criar exceções customizadas

Criar arquivo: `/packages/core/core_interfaces/lib/src/exceptions/app_exceptions.dart`

```dart
/// Exceção base para todas as exceções do app
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'AppException{code: $code, message: $message}';
  }
}

/// Exceção relacionada a micro apps
class MicroAppException extends AppException {
  final String microAppId;

  MicroAppException({
    required this.microAppId,
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  String toString() {
    return 'MicroAppException{microApp: $microAppId, code: $code, message: $message}';
  }
}

/// Exceção de inicialização
class InitializationException extends AppException {
  InitializationException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'initialization_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exceção de estado inválido
class InvalidStateException extends AppException {
  InvalidStateException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'invalid_state',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
```

#### Passo 2: Criar política de error handling

Criar arquivo: `/docs/guides/ERROR_HANDLING_GUIDE.md` (será criado separadamente)

**Regras:**
1. **SEMPRE** use `LoggingService` ao invés de `debugPrint`
2. **NUNCA** ignore exceções silenciosamente
3. **USE** exceções customizadas ao invés de `Exception` genérico
4. **RE-LANCE** exceções em camadas que não podem recuperar
5. **CAPTURE** e trate exceções em camadas de apresentação

#### Passo 3: Aplicar política em BaseMicroApp

```dart
@override
Future<void> initialize(MicroAppDependencies dependencies) async {
  if (_initialized) {
    dependencies.loggingService?.warning(
      'MicroApp $name já foi inicializado',
    );
    return;
  }

  _dependencies = dependencies;

  try {
    await onInitialize(dependencies);
    _initialized = true;
    dependencies.loggingService?.info(
      'MicroApp $name inicializado com sucesso',
    );
  } catch (e, stackTrace) {
    // ✅ Log completo do erro
    dependencies.loggingService?.error(
      'Erro ao inicializar MicroApp $name: $e',
      error: e,
      stackTrace: stackTrace,
    );

    // ✅ Lança exceção customizada
    throw InitializationException(
      message: 'Falha ao inicializar micro app $name',
      code: 'micro_app_init_failed',
      originalError: e,
      stackTrace: stackTrace,
    );
  }
}
```

### 📋 Checklist de Implementação

- [ ] Criar exceções customizadas (AppException, MicroAppException, etc.)
- [ ] Criar ERROR_HANDLING_GUIDE.md
- [ ] Atualizar BaseMicroApp para usar nova política
- [ ] Refatorar todos os micro apps para usar exceções customizadas
- [ ] Refatorar todos os services para usar LoggingService
- [ ] Substituir todos `debugPrint` por `LoggingService`
- [ ] Adicionar error boundary widgets no Flutter
- [ ] Adicionar testes para error handling
- [ ] Code review
- [ ] Merge

### 🧪 Testes Necessários

```dart
// test/core_interfaces/error_handling_test.dart
void main() {
  group('Error Handling', () {
    test('should throw InitializationException on initialization failure', () async {
      // ...
    });

    test('should log error before throwing', () async {
      // ...
    });

    test('should include stack trace in exception', () async {
      // ...
    });
  });
}
```

### 📊 Critérios de Sucesso

- ✅ Zero uso de `debugPrint` em código de produção
- ✅ Todas as exceções são customizadas (herdam de AppException)
- ✅ 100% dos erros são logados via LoggingService
- ✅ Policy documentada em ERROR_HANDLING_GUIDE.md
- ✅ Error boundaries implementados

### ⏱️ Estimativa de Esforço
**12-16 horas** de desenvolvimento + 4 horas de testes

---

## CRIT-005: Substituir Teste Placeholder por Testes Reais

### 📍 Descrição
O único teste existente (`widget_test.dart`) é um placeholder que testa um contador inexistente no app.

### 🎯 Objetivo
Criar testes reais que validem funcionalidades do app (splash, navegação, inicialização).

### 📂 Arquivos Afetados
- `/super_app/test/widget_test.dart`

### 🔍 Problema Atual

```dart
testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  await tester.pumpWidget(const SuperApp());

  // ❌ App não tem contador
  expect(find.text('0'), findsOneWidget);
  expect(find.text('1'), findsNothing);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();

  expect(find.text('0'), findsNothing);
  expect(find.text('1'), findsOneWidget);
});
```

### ✅ Solução Proposta

Substituir por testes reais:

```dart
// test/widget/splash_screen_test.dart
void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('should display app logo and name', (WidgetTester tester) async {
      await tester.pumpWidget(const SuperApp());
      await tester.pump();

      expect(find.text('Premium Bank'), findsOneWidget);
      // Adicionar mais expectativas baseadas na splash screen real
    });

    testWidgets('should navigate to login after splash', (WidgetTester tester) async {
      await tester.pumpWidget(const SuperApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verifica se navegou para login
      expect(find.text('Login'), findsOneWidget);
    });
  });
}

// test/integration/navigation_test.dart
void main() {
  group('Navigation Integration Tests', () {
    testWidgets('should navigate between main screens', (WidgetTester tester) async {
      // Setup de login mock
      // Teste de navegação entre Dashboard, Pix, Payments, etc.
    });
  });
}
```

### 📋 Checklist de Implementação

- [ ] Remover teste placeholder
- [ ] Criar testes de widget para SplashScreen
- [ ] Criar testes de widget para LoginPage
- [ ] Criar testes de integração para navegação
- [ ] Criar testes de inicialização de micro apps
- [ ] Configurar mocks necessários
- [ ] Garantir que testes passam no CI/CD
- [ ] Code review
- [ ] Merge

### 🧪 Testes a Criar

1. **Widget Tests:**
   - Splash screen display
   - Login form validation
   - Navigation bar functionality

2. **Integration Tests:**
   - Login flow completo
   - Navegação entre telas principais
   - Inicialização de micro apps sob demanda

### 📊 Critérios de Sucesso

- ✅ Zero testes placeholder
- ✅ Mínimo 5 testes de widget criados
- ✅ Mínimo 3 testes de integração criados
- ✅ Todos os testes passando
- ✅ CI/CD executando testes com sucesso

### ⏱️ Estimativa de Esforço
**8-10 horas** de desenvolvimento

---

## 📊 Resumo de Prioridades

| ID | Issue | Esforço | Dependências | Status |
|----|-------|---------|--------------|--------|
| CRIT-001 | Padronizar Ciclo de Vida BLoCs | 12-16h | Nenhuma | ⏳ |
| CRIT-002 | Remover Lógica Hardcoded | 6-8h | CRIT-001 | ⏳ |
| CRIT-003 | Remover Duplicação Inicialização | Incluído | CRIT-001 | ⏳ |
| CRIT-004 | Política Error Handling | 16-20h | Nenhuma | ⏳ |
| CRIT-005 | Testes Reais | 8-10h | Nenhuma | ⏳ |

**Total Estimado:** 42-54 horas (~1-2 semanas com 1 dev full-time)

---

## ✅ Critérios de Conclusão da Fase 1

- [ ] Todos os 5 issues críticos resolvidos
- [ ] Todos os testes passando
- [ ] Code review aprovado para todos os PRs
- [ ] Documentação atualizada
- [ ] Zero regressões identificadas
- [ ] Equipe treinada nos novos padrões

---

**Última Atualização:** 2025-11-07
**Próxima Revisão:** Diária durante implementação
