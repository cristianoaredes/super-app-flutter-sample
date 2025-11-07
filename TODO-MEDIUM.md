# 🟡 TODO - Issues Médios (PRIORIDADE MÉDIA)

**Fase:** 2 - Testes e Qualidade
**Prazo:** 2 semanas
**Status:** 🟡 Aguardando Fase 1

> 💡 **NOTA:** Estes issues devem ser abordados após a conclusão dos issues críticos.
> Eles melhoram a qualidade, testabilidade e robustez do código.

---

## MED-001: Implementar Thread-Safety no BlocRegistry

### 📍 Descrição
A classe `BlocRegistry` não é thread-safe, o que pode causar race conditions se múltiplos micro apps tentarem registrar BLoCs simultaneamente.

### 🎯 Objetivo
Tornar o `BlocRegistry` thread-safe para evitar problemas de concorrência.

### 📂 Arquivos Afetados
- `/packages/core/core_interfaces/lib/src/bloc_registry.dart`

### 🔍 Problema Atual

```dart
class BlocRegistry {
  final Map<Type, dynamic> _blocs = {};

  void register<T>(T bloc) {
    _blocs[bloc.runtimeType] = bloc;  // ❌ Não é thread-safe
  }

  T? get<T>() {
    for (final entry in _blocs.entries) {  // ❌ Pode mudar durante iteração
      if (entry.value is T) {
        return entry.value as T;
      }
    }
    return null;
  }
}
```

### ✅ Solução Proposta

#### Opção 1: Usar synchronized package (Recomendado)

```yaml
# packages/core/core_interfaces/pubspec.yaml
dependencies:
  synchronized: ^3.1.0
```

```dart
import 'package:synchronized/synchronized.dart';

class BlocRegistry {
  final Map<Type, dynamic> _blocs = {};
  final _lock = Lock();

  /// Registra um BLoC no registry de forma thread-safe
  Future<void> register<T>(T bloc) async {
    await _lock.synchronized(() {
      _blocs[bloc.runtimeType] = bloc;
    });
  }

  /// Registra um BLoC com tipo específico de forma thread-safe
  Future<void> registerWithType<T>(Type type, T bloc) async {
    await _lock.synchronized(() {
      _blocs[type] = bloc;
    });
  }

  /// Busca um BLoC registrado de forma thread-safe
  Future<T?> get<T>() async {
    return await _lock.synchronized(() {
      for (final entry in _blocs.entries) {
        if (entry.value is T) {
          return entry.value as T;
        }
      }
      return null;
    });
  }

  /// Verifica se contém um BLoC do tipo especificado
  Future<bool> contains<T>() async {
    return await _lock.synchronized(() {
      for (final entry in _blocs.entries) {
        if (entry.value is T) {
          return true;
        }
      }
      return false;
    });
  }

  /// Remove um BLoC do tipo especificado
  Future<void> remove<T>() async {
    await _lock.synchronized(() {
      final keysToRemove = <Type>[];
      for (final entry in _blocs.entries) {
        if (entry.value is T) {
          keysToRemove.add(entry.key);
        }
      }
      for (final key in keysToRemove) {
        _blocs.remove(key);
      }
    });
  }

  /// Remove um BLoC por tipo específico
  Future<void> removeByType(Type type) async {
    await _lock.synchronized(() {
      _blocs.remove(type);
    });
  }

  /// Limpa todos os BLoCs registrados
  Future<void> clear() async {
    await _lock.synchronized(() {
      _blocs.clear();
    });
  }

  /// Retorna cópia imutável dos BLoCs registrados
  Future<Map<Type, dynamic>> get blocs async {
    return await _lock.synchronized(() {
      return Map.unmodifiable(_blocs);
    });
  }
}
```

#### Opção 2: Usar Isolates (Para casos extremos)

Se thread-safety for crítico, considerar usar Isolates para comunicação entre micro apps.

### 📋 Checklist de Implementação

- [ ] Adicionar dependência `synchronized` ao pubspec.yaml
- [ ] Atualizar classe `BlocRegistry` com Lock
- [ ] Tornar todos os métodos async
- [ ] Atualizar todos os usos de BlocRegistry no código
- [ ] Atualizar `BaseMicroApp` para usar novos métodos async
- [ ] Adicionar testes de concorrência
- [ ] Verificar impacto de performance
- [ ] Documentar mudanças de API
- [ ] Code review
- [ ] Merge

### 🧪 Testes Necessários

```dart
// test/core_interfaces/bloc_registry_test.dart
void main() {
  group('BlocRegistry Thread-Safety', () {
    test('should handle concurrent registrations safely', () async {
      final registry = BlocRegistry();

      // Simula múltiplas threads registrando ao mesmo tempo
      await Future.wait([
        registry.register(MockBlocA()),
        registry.register(MockBlocB()),
        registry.register(MockBlocC()),
        registry.register(MockBlocD()),
      ]);

      expect(await registry.contains<MockBlocA>(), true);
      expect(await registry.contains<MockBlocB>(), true);
      expect(await registry.contains<MockBlocC>(), true);
      expect(await registry.contains<MockBlocD>(), true);
    });

    test('should handle concurrent reads safely', () async {
      final registry = BlocRegistry();
      await registry.register(MockBlocA());

      // Simula múltiplas leituras simultâneas
      final results = await Future.wait([
        registry.get<MockBlocA>(),
        registry.get<MockBlocA>(),
        registry.get<MockBlocA>(),
        registry.get<MockBlocA>(),
      ]);

      expect(results.every((r) => r != null), true);
    });

    test('should handle concurrent register and remove safely', () async {
      final registry = BlocRegistry();

      await Future.wait([
        registry.register(MockBlocA()),
        registry.remove<MockBlocB>(),
        registry.register(MockBlocC()),
        registry.clear(),
      ]);

      // Não deve crashar
      expect(true, true);
    });
  });
}
```

### 📊 Critérios de Sucesso

- ✅ Todos os métodos do BlocRegistry são thread-safe
- ✅ Testes de concorrência passando
- ✅ Sem degradação significativa de performance (< 5%)
- ✅ Documentação atualizada

### ⏱️ Estimativa de Esforço
**6-8 horas** de desenvolvimento + 4 horas de testes

---

## MED-002: Adicionar Validação de Parâmetros em Rotas

### 📍 Descrição
Rotas parametrizadas usam force unwrap (`!`) sem validação, causando crashes se parâmetros estiverem ausentes.

### 🎯 Objetivo
Adicionar validação robusta para todos os parâmetros de rota.

### 📂 Arquivos Afetados
- `/packages/micro_apps/payments/lib/src/payments_micro_app.dart:72-74`
- `/packages/micro_apps/dashboard/lib/src/dashboard_micro_app.dart:54-56`
- `/packages/micro_apps/pix/lib/src/pix_micro_app.dart:114-116`
- Todas as rotas com parâmetros

### 🔍 Problema Atual

```dart
'/payments/:id': (context, state) {
  _ensureInitialized();
  final id = state.params['id']!;  // ❌ Force unwrap, pode crashar

  return flutter_bloc.BlocProvider<PaymentsCubit>(
    create: (context) => paymentsCubit,
    child: PaymentDetailPage(id: id),
  );
},
```

### ✅ Solução Proposta

#### Passo 1: Criar helper para validação de parâmetros

Criar arquivo: `/packages/shared/shared_utils/lib/src/route_params_validator.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteParamsValidator {
  /// Valida e retorna um parâmetro obrigatório da rota
  static String getRequiredParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = params[paramName];

    if (value == null || value.isEmpty) {
      throw RouteParamMissingException(
        'Parâmetro obrigatório "$paramName" não encontrado na rota',
      );
    }

    return value;
  }

  /// Valida e retorna um parâmetro opcional da rota
  static String? getOptionalParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = params[paramName];
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Valida um UUID
  static String getUuidParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(value)) {
      throw RouteParamInvalidException(
        'Parâmetro "$paramName" deve ser um UUID válido, recebido: $value',
      );
    }

    return value;
  }

  /// Valida um número inteiro
  static int getIntParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw RouteParamInvalidException(
        'Parâmetro "$paramName" deve ser um número inteiro, recebido: $value',
      );
    }

    return parsed;
  }

  /// Valida um enum
  static T getEnumParam<T extends Enum>(
    Map<String, String> params,
    String paramName,
    List<T> values,
  ) {
    final value = getRequiredParam(params, paramName);

    try {
      return values.firstWhere((e) => e.name == value);
    } catch (e) {
      throw RouteParamInvalidException(
        'Parâmetro "$paramName" deve ser um dos valores: ${values.map((e) => e.name).join(", ")}, recebido: $value',
      );
    }
  }
}

/// Exceção quando parâmetro obrigatório está ausente
class RouteParamMissingException implements Exception {
  final String message;
  RouteParamMissingException(this.message);

  @override
  String toString() => 'RouteParamMissingException: $message';
}

/// Exceção quando parâmetro tem formato inválido
class RouteParamInvalidException implements Exception {
  final String message;
  RouteParamInvalidException(this.message);

  @override
  String toString() => 'RouteParamInvalidException: $message';
}
```

#### Passo 2: Criar página de erro para parâmetros inválidos

```dart
// super_app/lib/core/widgets/invalid_param_error_page.dart
class InvalidParamErrorPage extends StatelessWidget {
  final String message;

  const InvalidParamErrorPage({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parâmetro Inválido'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Parâmetro Inválido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Passo 3: Atualizar rotas com validação

```dart
// ✅ COM VALIDAÇÃO
'/payments/:id': (context, state) {
  _ensureInitialized();

  try {
    final id = RouteParamsValidator.getRequiredParam(
      state.params,
      'id',
    );

    return flutter_bloc.BlocProvider<PaymentsCubit>(
      create: (context) => paymentsCubit,
      child: PaymentDetailPage(id: id),
    );
  } on RouteParamMissingException catch (e) {
    return InvalidParamErrorPage(message: e.message);
  } on RouteParamInvalidException catch (e) {
    return InvalidParamErrorPage(message: e.message);
  }
},
```

Para UUIDs:
```dart
'/cards/:cardId': (context, state) {
  _ensureInitialized();

  try {
    final cardId = RouteParamsValidator.getUuidParam(
      state.params,
      'cardId',
    );

    return BlocProvider<CardsBloc>.value(
      value: cardsBloc,
      child: CardDetailPage(cardId: cardId),
    );
  } on RouteParamException catch (e) {
    return InvalidParamErrorPage(message: e.message);
  }
},
```

### 📋 Checklist de Implementação

- [ ] Criar classe `RouteParamsValidator`
- [ ] Criar exceções customizadas (RouteParamMissingException, etc.)
- [ ] Criar página `InvalidParamErrorPage`
- [ ] Atualizar todas as rotas em PaymentsMicroApp
- [ ] Atualizar todas as rotas em DashboardMicroApp
- [ ] Atualizar todas as rotas em PixMicroApp
- [ ] Atualizar todas as rotas em CardsMicroApp
- [ ] Atualizar todas as rotas em AccountMicroApp
- [ ] Adicionar testes unitários para RouteParamsValidator
- [ ] Adicionar testes de widget para InvalidParamErrorPage
- [ ] Adicionar testes de integração para rotas inválidas
- [ ] Documentar padrão de validação
- [ ] Code review
- [ ] Merge

### 🧪 Testes Necessários

```dart
// test/shared_utils/route_params_validator_test.dart
void main() {
  group('RouteParamsValidator', () {
    test('should return required param if present', () {
      final params = {'id': '123'};
      final result = RouteParamsValidator.getRequiredParam(params, 'id');
      expect(result, '123');
    });

    test('should throw RouteParamMissingException if required param is missing', () {
      final params = <String, String>{};
      expect(
        () => RouteParamsValidator.getRequiredParam(params, 'id'),
        throwsA(isA<RouteParamMissingException>()),
      );
    });

    test('should return null for optional param if missing', () {
      final params = <String, String>{};
      final result = RouteParamsValidator.getOptionalParam(params, 'id');
      expect(result, null);
    });

    test('should validate UUID format correctly', () {
      final params = {'id': '550e8400-e29b-41d4-a716-446655440000'};
      final result = RouteParamsValidator.getUuidParam(params, 'id');
      expect(result, '550e8400-e29b-41d4-a716-446655440000');
    });

    test('should throw RouteParamInvalidException for invalid UUID', () {
      final params = {'id': 'invalid-uuid'};
      expect(
        () => RouteParamsValidator.getUuidParam(params, 'id'),
        throwsA(isA<RouteParamInvalidException>()),
      );
    });

    test('should parse int param correctly', () {
      final params = {'count': '42'};
      final result = RouteParamsValidator.getIntParam(params, 'count');
      expect(result, 42);
    });

    test('should throw for invalid int param', () {
      final params = {'count': 'not-a-number'};
      expect(
        () => RouteParamsValidator.getIntParam(params, 'count'),
        throwsA(isA<RouteParamInvalidException>()),
      );
    });
  });
}
```

### 📊 Critérios de Sucesso

- ✅ Zero force unwraps (`!`) em parâmetros de rota
- ✅ Todas as rotas parametrizadas validadas
- ✅ Página de erro amigável para parâmetros inválidos
- ✅ Testes cobrindo todos os casos de validação

### ⏱️ Estimativa de Esforço
**10-12 horas** de desenvolvimento + 4 horas de testes

---

## MED-003: Padronizar Uso de BlocProvider (create vs value)

### 📍 Descrição
Diferentes micro apps usam abordagens inconsistentes: alguns usam `BlocProvider.value` (compartilha instância), outros `BlocProvider(create:)` (cria nova instância).

### 🎯 Objetivo
Definir e documentar quando usar cada abordagem, e padronizar o código.

### 📂 Arquivos Afetados
- Todos os micro apps (rotas)

### 🔍 Problema Atual

**PixMicroApp:** Cria nova instância
```dart
'/pix': (context, state) {
  return BlocProvider<PixBloc>(
    create: (context) => _getIt<PixBloc>(),  // ❌ Cria nova
    child: const PixHomePage(),
  );
},
```

**PaymentsMicroApp:** Usa instância compartilhada
```dart
'/payments': (context, state) {
  return flutter_bloc.BlocProvider<PaymentsCubit>(
    create: (context) => paymentsCubit,  // ✅ Compartilha
    child: const PaymentsPage(),
  );
},
```

### ✅ Solução Proposta

#### Regra de Decisão:

1. **Use `.value`** quando:
   - Quer compartilhar estado entre múltiplas telas
   - BLoC tem lifecycle gerenciado pelo micro app
   - Estado precisa persistir durante navegação

2. **Use `create:`** quando:
   - Cada tela precisa de instância independente
   - Estado não deve ser compartilhado
   - BLoC é descartado ao sair da tela

#### Para este projeto (Recomendação):

**Use `.value` SEMPRE** - Como temos lazy singletons gerenciados pelo micro app:

```dart
'/payments': (context, state) {
  _ensureInitialized();

  try {
    final id = RouteParamsValidator.getRequiredParam(state.params, 'id');

    // ✅ Usa .value para compartilhar instância singleton
    return BlocProvider<PaymentsCubit>.value(
      value: paymentsCubit,
      child: PaymentDetailPage(id: id),
    );
  } catch (e) {
    return InvalidParamErrorPage(message: e.toString());
  }
},
```

### 📋 Checklist de Implementação

- [ ] Decidir estratégia oficial (recomendado: `.value`)
- [ ] Documentar decisão em MICRO_APP_STANDARDS.md
- [ ] Atualizar PixMicroApp para usar `.value`
- [ ] Verificar todos os outros micro apps
- [ ] Padronizar todos os usos
- [ ] Adicionar lint rule customizada (se possível)
- [ ] Adicionar comentários explicativos
- [ ] Code review
- [ ] Merge

### 📊 Critérios de Sucesso

- ✅ 100% das rotas seguem padrão definido
- ✅ Documentação clara sobre quando usar cada abordagem
- ✅ Comentários em código explicam escolha

### ⏱️ Estimativa de Esforço
**4-6 horas** de desenvolvimento

---

## MED-004: Adicionar Documentação em APIs Públicas

### 📍 Descrição
Interfaces públicas como `MicroApp`, `BaseMicroApp`, services, etc. não têm dartdoc comments.

### 🎯 Objetivo
Adicionar documentação completa em todas as APIs públicas usando dartdoc.

### 📂 Arquivos Afetados
- `/packages/core/core_interfaces/lib/src/micro_app.dart`
- `/packages/core/core_interfaces/lib/src/base_micro_app.dart` (quando criado)
- Todos os services em `core_interfaces`
- Classes públicas em todos os packages

### 🔍 Problema Atual

```dart
// ❌ SEM DOCUMENTAÇÃO
abstract class MicroApp {
  String get id;
  String get name;
  Map<String, GoRouteBuilder> get routes;
  bool get isInitialized => true;
  Future<void> initialize(MicroAppDependencies dependencies);
  Widget build(BuildContext context);
  void registerBlocs(BlocRegistry registry);
  Future<void> dispose();
}
```

### ✅ Solução Proposta

```dart
/// Interface base para todos os micro apps do sistema.
///
/// Um MicroApp representa um módulo funcional independente que pode ser
/// carregado sob demanda (lazy loading). Cada micro app gerencia suas
/// próprias rotas, dependências, e estado (BLoCs/Cubits).
///
/// ## Implementação
///
/// Micro apps devem estender [BaseMicroApp] ao invés de implementar esta
/// interface diretamente, pois [BaseMicroApp] fornece implementação padrão
/// para gerenciamento de ciclo de vida.
///
/// ```dart
/// class MyMicroApp extends BaseMicroApp {
///   @override
///   String get id => 'my_module';
///
///   @override
///   String get name => 'My Module';
///
///   @override
///   Future<void> onInitialize(MicroAppDependencies dependencies) async {
///     // Inicialização customizada
///   }
///
///   @override
///   Map<String, GoRouteBuilder> get routes => {
///     '/my-route': (context, state) => MyPage(),
///   };
/// }
/// ```
///
/// ## Ciclo de Vida
///
/// 1. Registro no GetIt (lazy singleton)
/// 2. Inicialização sob demanda via [initialize]
/// 3. Registro de BLoCs via [registerBlocs]
/// 4. Uso normal
/// 5. Dispose via [dispose] quando não mais necessário
///
/// Veja também:
/// - [BaseMicroApp] para implementação base
/// - [MicroAppDependencies] para dependências injetadas
abstract class MicroApp {
  /// Identificador único do micro app.
  ///
  /// Deve ser único em todo o sistema e seguir convenção snake_case.
  /// Exemplo: 'auth', 'dashboard', 'payments'
  String get id;

  /// Nome legível do micro app.
  ///
  /// Usado para logging e debugging.
  /// Exemplo: 'Authentication', 'Dashboard', 'Payments'
  String get name;

  /// Mapa de rotas fornecidas por este micro app.
  ///
  /// A chave é o path da rota (ex: '/login', '/payments/:id')
  /// O valor é um builder que constrói o widget para aquela rota.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// Map<String, GoRouteBuilder> get routes => {
  ///   '/login': (context, state) => LoginPage(),
  ///   '/profile/:userId': (context, state) {
  ///     final userId = state.params['userId']!;
  ///     return ProfilePage(userId: userId);
  ///   },
  /// };
  /// ```
  Map<String, GoRouteBuilder> get routes;

  /// Indica se o micro app foi inicializado.
  ///
  /// Retorna `true` após [initialize] ser chamado com sucesso,
  /// `false` caso contrário.
  bool get isInitialized => true;

  /// Inicializa o micro app com as dependências fornecidas.
  ///
  /// Este método deve:
  /// - Registrar dependências específicas no DI container
  /// - Criar instâncias de BLoCs/Cubits
  /// - Configurar services necessários
  /// - Preparar o micro app para uso
  ///
  /// [dependencies] contém todos os services core necessários.
  ///
  /// Throws [InitializationException] se a inicialização falhar.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// @override
  /// Future<void> initialize(MicroAppDependencies dependencies) async {
  ///   // Registrar repositórios e use cases
  ///   MyModuleInjector.register(getIt);
  ///
  ///   // Criar BLoC
  ///   _myBloc = getIt<MyBloc>();
  /// }
  /// ```
  Future<void> initialize(MicroAppDependencies dependencies);

  /// Constrói o widget principal do micro app.
  ///
  /// Geralmente retorna a tela inicial ou homepage do módulo.
  ///
  /// [context] é o BuildContext do Flutter.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return BlocProvider.value(
  ///     value: myBloc,
  ///     child: const MyHomePage(),
  ///   );
  /// }
  /// ```
  Widget build(BuildContext context);

  /// Registra os BLoCs/Cubits deste micro app no registry global.
  ///
  /// Permite que outros módulos acessem os BLoCs se necessário.
  ///
  /// [registry] é o [BlocRegistry] global onde BLoCs são registrados.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// @override
  /// void registerBlocs(BlocRegistry registry) {
  ///   registry.register(myBloc);
  ///   registry.register(myOtherCubit);
  /// }
  /// ```
  void registerBlocs(BlocRegistry registry);

  /// Libera recursos e limpa estado do micro app.
  ///
  /// Deve:
  /// - Fechar todos os BLoCs/Cubits
  /// - Cancelar subscriptions
  /// - Limpar caches
  /// - Liberar recursos
  ///
  /// Após chamar dispose, o micro app deve poder ser reinicializado.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// @override
  /// Future<void> dispose() async {
  ///   await _myBloc?.close();
  ///   _myBloc = null;
  /// }
  /// ```
  Future<void> dispose();

  /// Verifica se o micro app está em estado saudável.
  ///
  /// Retorna `true` se:
  /// - Está inicializado
  /// - Todos os BLoCs estão funcionais
  /// - Dependências estão disponíveis
  ///
  /// Retorna `false` caso contrário.
  ///
  /// Usado pelo middleware de rota para decidir se precisa reinicializar.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// @override
  /// Future<bool> isHealthy() async {
  ///   if (!isInitialized) return false;
  ///   if (_myBloc == null) return false;
  ///
  ///   try {
  ///     // Verifica se BLoC está funcional
  ///     final state = _myBloc!.state;
  ///     return state != null;
  ///   } catch (e) {
  ///     return false;
  ///   }
  /// }
  /// ```
  Future<bool> isHealthy() async => isInitialized;
}
```

### 📋 Checklist de Implementação

- [ ] Documentar interface MicroApp
- [ ] Documentar classe BaseMicroApp (quando criada)
- [ ] Documentar MicroAppDependencies
- [ ] Documentar BlocRegistry
- [ ] Documentar todos os services em core_interfaces:
  - [ ] NavigationService
  - [ ] AuthService
  - [ ] StorageService
  - [ ] AnalyticsService
  - [ ] NetworkService
  - [ ] LoggingService
  - [ ] FeatureFlagService
- [ ] Documentar exceções customizadas
- [ ] Documentar classes em shared_utils
- [ ] Documentar classes em design_system
- [ ] Executar `dart doc` para gerar documentação
- [ ] Revisar documentação gerada
- [ ] Code review
- [ ] Merge

### 📊 Critérios de Sucesso

- ✅ 100% das APIs públicas documentadas
- ✅ Documentação segue convenções dartdoc
- ✅ Exemplos de uso incluídos onde apropriado
- ✅ Links entre documentos relacionados
- ✅ `dart doc` gera documentação sem warnings

### ⏱️ Estimativa de Esforço
**12-16 horas** de desenvolvimento

---

## MED-005: Criar Suite de Testes Unitários para BLoCs

### 📍 Descrição
Nenhum BLoC/Cubit tem testes unitários, dificultando refatorações e aumentando risco de bugs.

### 🎯 Objetivo
Criar testes unitários completos para todos os BLoCs/Cubits do projeto.

### 📂 Arquivos Afetados
- Todos os BLoCs em `/packages/micro_apps/*/lib/src/presentation/bloc/`
- Todos os Cubits em `/packages/micro_apps/*/lib/src/presentation/cubits/`

### 🔍 Lista de BLoCs/Cubits para Testar

#### Auth Module
- [ ] AuthBloc

#### Dashboard Module
- [ ] DashboardBloc

#### Payments Module
- [ ] PaymentsCubit

#### Pix Module
- [ ] PixBloc

#### Cards Module
- [ ] CardsBloc

#### Account Module
- [ ] AccountBloc

### ✅ Solução Proposta

#### Template de Teste para BLoCs

```dart
// test/micro_apps/auth/presentation/bloc/auth_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Gerar mocks
@GenerateMocks([
  LoginUseCase,
  LogoutUseCase,
  RegisterUseCase,
  ResetPasswordUseCase,
  AnalyticsService,
])
import 'auth_bloc_test.mocks.dart';

void main() {
  late AuthBloc authBloc;
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockRegisterUseCase mockRegisterUseCase;
  late MockResetPasswordUseCase mockResetPasswordUseCase;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockRegisterUseCase = MockRegisterUseCase();
    mockResetPasswordUseCase = MockResetPasswordUseCase();
    mockAnalyticsService = MockAnalyticsService();

    authBloc = AuthBloc(
      loginUseCase: mockLoginUseCase,
      logoutUseCase: mockLogoutUseCase,
      registerUseCase: mockRegisterUseCase,
      resetPasswordUseCase: mockResetPasswordUseCase,
      analyticsService: mockAnalyticsService,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    group('LoginWithEmailAndPasswordEvent', () {
      final tUser = User(
        id: '123',
        name: 'Test User',
        email: 'test@example.com',
      );

      test('initial state should be AuthInitialState', () {
        expect(authBloc.state, equals(const AuthInitialState()));
      });

      blocTest<AuthBloc, AuthState>(
        'should emit [AuthLoadingState, AuthenticatedState] when login succeeds',
        build: () {
          when(mockLoginUseCase.executeWithEmailAndPassword(any, any))
              .thenAnswer((_) async => tUser);
          when(mockAnalyticsService.trackEvent(any, any))
              .thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(
          const LoginWithEmailAndPasswordEvent(
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
        expect: () => [
          const AuthLoadingState(),
          AuthenticatedState(user: tUser),
        ],
        verify: (_) {
          verify(mockLoginUseCase.executeWithEmailAndPassword(
            'test@example.com',
            'password123',
          )).called(1);
          verify(mockAnalyticsService.trackEvent(
            'login_success',
            any,
          )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'should emit [AuthLoadingState, AuthErrorState] when login fails',
        build: () {
          when(mockLoginUseCase.executeWithEmailAndPassword(any, any))
              .thenThrow(Exception('Invalid credentials'));
          when(mockAnalyticsService.trackError(any, any))
              .thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(
          const LoginWithEmailAndPasswordEvent(
            email: 'test@example.com',
            password: 'wrong_password',
          ),
        ),
        expect: () => [
          const AuthLoadingState(),
          const AuthErrorState(
            message: 'Exception: Invalid credentials',
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'login_error',
            any,
          )).called(1);
        },
      );
    });

    group('LogoutEvent', () {
      blocTest<AuthBloc, AuthState>(
        'should emit [AuthLoadingState, UnauthenticatedState] when logout succeeds',
        build: () {
          when(mockLogoutUseCase.execute())
              .thenAnswer((_) async => {});
          when(mockAnalyticsService.trackEvent(any, any))
              .thenAnswer((_) async => {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const LogoutEvent()),
        expect: () => [
          const AuthLoadingState(),
          const UnauthenticatedState(),
        ],
      );
    });

    // Adicionar testes para outros eventos:
    // - RegisterEvent
    // - ResetPasswordEvent
    // - LoginWithGoogleEvent
    // - LoginWithAppleEvent
  });
}
```

### 📋 Checklist de Implementação

- [ ] Configurar dependências de teste (bloc_test, mockito)
- [ ] Criar testes para AuthBloc (todos os eventos)
- [ ] Criar testes para DashboardBloc
- [ ] Criar testes para PaymentsCubit
- [ ] Criar testes para PixBloc
- [ ] Criar testes para CardsBloc
- [ ] Criar testes para AccountBloc
- [ ] Adicionar testes para casos de erro
- [ ] Adicionar testes para edge cases
- [ ] Configurar coverage report
- [ ] Atingir ≥ 80% de cobertura em BLoCs
- [ ] Documentar padrão de testes
- [ ] Code review
- [ ] Merge

### 📊 Critérios de Sucesso

- ✅ 100% dos BLoCs/Cubits têm testes
- ✅ Cobertura ≥ 80% em camada de apresentação
- ✅ Todos os eventos testados
- ✅ Casos de sucesso e erro cobertos
- ✅ CI/CD executando testes automaticamente

### ⏱️ Estimativa de Esforço
**20-24 horas** de desenvolvimento

---

## 📊 Resumo de Prioridades

| ID | Issue | Esforço | Dependências | Status |
|----|-------|---------|--------------|--------|
| MED-001 | Thread-Safety BlocRegistry | 10-12h | CRIT-001 | ⏳ |
| MED-002 | Validação de Parâmetros | 14-16h | Nenhuma | ⏳ |
| MED-003 | Padronizar BlocProvider | 4-6h | CRIT-001 | ⏳ |
| MED-004 | Documentar APIs | 12-16h | CRIT-001 | ⏳ |
| MED-005 | Testes de BLoCs | 20-24h | Nenhuma | ⏳ |

**Total Estimado:** 60-74 horas (~2 semanas com 1 dev full-time)

---

**Última Atualização:** 2025-11-07
**Próxima Revisão:** Após conclusão da Fase 1
