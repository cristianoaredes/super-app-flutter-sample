# 📐 Padrões de Micro Apps - Premium Bank

**Versão:** 1.0
**Data:** 2025-11-07
**Status:** Draft

---

## 🎯 Objetivo

Este documento define os padrões, convenções e melhores práticas para desenvolvimento de micro apps no Premium Bank Flutter Super App.

**IMPORTANTE:** Todos os novos micro apps DEVEM seguir estes padrões. Micro apps existentes devem ser gradualmente refatorados para conformidade.

---

## 📋 Índice

1. [Estrutura de Diretórios](#estrutura-de-diretórios)
2. [Classe MicroApp](#classe-microapp)
3. [Ciclo de Vida](#ciclo-de-vida)
4. [Injeção de Dependências](#injeção-de-dependências)
5. [Gerenciamento de Estado](#gerenciamento-de-estado)
6. [Roteamento](#roteamento)
7. [Tratamento de Erros](#tratamento-de-erros)
8. [Testes](#testes)
9. [Checklist de Implementação](#checklist-de-implementação)

---

## 📂 Estrutura de Diretórios

Todo micro app DEVE seguir a estrutura Clean Architecture:

```
packages/micro_apps/[nome_micro_app]/
├── lib/
│   ├── src/
│   │   ├── [nome_micro_app]_micro_app.dart    # Classe principal do micro app
│   │   │
│   │   ├── di/                                 # Dependency Injection
│   │   │   └── [nome]_injector.dart
│   │   │
│   │   ├── router/                             # Rotas
│   │   │   └── [nome]_routes.dart
│   │   │
│   │   ├── domain/                             # Camada de Domínio
│   │   │   ├── entities/                       # Entidades de negócio
│   │   │   ├── repositories/                   # Interfaces de repositórios
│   │   │   └── usecases/                       # Casos de uso
│   │   │
│   │   ├── data/                               # Camada de Dados
│   │   │   ├── models/                         # Modelos de dados (DTOs)
│   │   │   ├── repositories/                   # Implementações de repositórios
│   │   │   └── datasources/                    # Fontes de dados (remote/local)
│   │   │
│   │   └── presentation/                       # Camada de Apresentação
│   │       ├── bloc/ ou cubits/               # Gerenciamento de estado
│   │       ├── pages/                          # Páginas/Telas
│   │       └── widgets/                        # Widgets reutilizáveis
│   │
│   └── [nome_micro_app].dart                  # Barrel file (exports públicos)
│
├── test/                                       # Testes
│   ├── domain/
│   ├── data/
│   └── presentation/
│
├── pubspec.yaml
└── README.md
```

### Convenções de Nomenclatura

- **Pastas:** `snake_case`
- **Arquivos:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variáveis/Métodos:** `camelCase`
- **Constantes:** `SCREAMING_SNAKE_CASE` ou `camelCase` para `const`

---

## 🏗️ Classe MicroApp

### Implementação Padrão

**SEMPRE** estender `BaseMicroApp`, **NUNCA** implementar `MicroApp` diretamente:

```dart
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'di/my_module_injector.dart';
import 'presentation/bloc/my_bloc.dart';
import 'presentation/pages/my_home_page.dart';

/// Micro app para [descrição da funcionalidade]
///
/// Este módulo gerencia [breve descrição do que o módulo faz].
///
/// ## Features
/// - Feature 1
/// - Feature 2
/// - Feature 3
class MyModuleMicroApp extends BaseMicroApp {
  // Estado privado
  MyBloc? _myBloc;

  // Construtor padrão
  MyModuleMicroApp({GetIt? getIt}) : super(getIt: getIt);

  // Identificação do micro app
  @override
  String get id => 'my_module';

  @override
  String get name => 'My Module';

  // Getter para BLoC (com validação)
  MyBloc get myBloc {
    ensureInitialized();
    return _myBloc!;
  }

  // Rotas fornecidas por este micro app
  @override
  Map<String, GoRouteBuilder> get routes => {
    '/my-module': (context, state) {
      ensureInitialized();
      return BlocProvider<MyBloc>.value(
        value: myBloc,
        child: const MyHomePage(),
      );
    },
    '/my-module/:id': (context, state) {
      ensureInitialized();

      try {
        final id = RouteParamsValidator.getRequiredParam(
          state.params,
          'id',
        );

        return BlocProvider<MyBloc>.value(
          value: myBloc,
          child: MyDetailPage(id: id),
        );
      } on RouteParamException catch (e) {
        return InvalidParamErrorPage(message: e.message);
      }
    },
  };

  // Inicialização customizada
  @override
  Future<void> onInitialize(MicroAppDependencies dependencies) async {
    // 1. Registrar dependências específicas
    MyModuleInjector.register(getIt, dependencies);

    // 2. Criar instâncias de BLoCs
    _myBloc = getIt<MyBloc>();

    // 3. Configurações adicionais (se necessário)
    // ...
  }

  // Limpeza de recursos
  @override
  Future<void> onDispose() async {
    if (_myBloc != null) {
      await _myBloc!.close();
      _myBloc = null;
    }

    // Limpar outros recursos se necessário
  }

  // Health check customizado
  @override
  Future<bool> checkHealth() async {
    if (_myBloc == null) return false;

    try {
      // Verifica se o BLoC está em estado válido
      final state = _myBloc!.state;
      return state != null;
    } catch (e) {
      dependencies.loggingService?.error(
        'Health check falhou para $name: $e',
      );
      return false;
    }
  }

  // Widget principal do módulo
  @override
  Widget build(BuildContext context) {
    ensureInitialized();
    return BlocProvider<MyBloc>.value(
      value: myBloc,
      child: const MyHomePage(),
    );
  }

  // Registro de BLoCs no registry global
  @override
  void registerBlocs(BlocRegistry registry) {
    ensureInitialized();
    registry.register(myBloc);
  }
}
```

### Regras Obrigatórias

✅ **FAZER:**
- Estender `BaseMicroApp`
- Documentar classe com dartdoc
- Validar parâmetros de rota
- Usar `.value` para BlocProvider
- Implementar `checkHealth()` customizado
- Fechar todos os BLoCs em `onDispose()`

❌ **NÃO FAZER:**
- Implementar `MicroApp` diretamente
- Usar lógica de inicialização em getters
- Usar force unwrap (`!`) em parâmetros
- Criar novas instâncias de BLoC em cada rota
- Ignorar exceções silenciosamente
- Usar `dynamic` casts

---

## 🔄 Ciclo de Vida

### Fluxo de Vida de um Micro App

```
┌─────────────────────────────────────────┐
│ 1. REGISTRO NO GETIT (Lazy Singleton)  │
│    sl.registerLazySingleton(...)       │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 2. INICIALIZAÇÃO (On-Demand)           │
│    - initialize(dependencies)           │
│    - onInitialize()                     │
│    - Registrar DI                       │
│    - Criar BLoCs                        │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 3. REGISTRO DE BLoCs                    │
│    - registerBlocs(registry)            │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 4. USO NORMAL                           │
│    - Rotas acessíveis                   │
│    - BLoCs ativos                       │
│    - Health checks periódicos           │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│ 5. DISPOSE (Quando Necessário)          │
│    - dispose()                          │
│    - onDispose()                        │
│    - Fechar BLoCs                       │
│    - Limpar recursos                    │
└─────────────────────────────────────────┘
```

### Estados Válidos

```dart
enum MicroAppState {
  notInitialized,  // Ainda não foi inicializado
  initializing,    // Em processo de inicialização
  ready,           // Pronto para uso
  unhealthy,       // Inicializado mas em estado inválido
  disposing,       // Em processo de dispose
  disposed,        // Recursos liberados
}
```

---

## 💉 Injeção de Dependências

### Injector Pattern

Cada micro app DEVE ter sua própria classe Injector:

```dart
// di/my_module_injector.dart
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../data/datasources/my_remote_datasource.dart';
import '../data/repositories/my_repository_impl.dart';
import '../domain/repositories/my_repository.dart';
import '../domain/usecases/get_data_usecase.dart';
import '../presentation/bloc/my_bloc.dart';

class MyModuleInjector {
  /// Registra todas as dependências do módulo
  static void register(GetIt getIt, MicroAppDependencies dependencies) {
    // 1. Data Sources
    getIt.registerLazySingleton<MyRemoteDataSource>(
      () => MyRemoteDataSourceImpl(
        client: dependencies.networkService.createClient(
          baseUrl: dependencies.config.apiBaseUrl,
        ),
      ),
    );

    // 2. Repositories
    getIt.registerLazySingleton<MyRepository>(
      () => MyRepositoryImpl(
        remoteDataSource: getIt<MyRemoteDataSource>(),
        localDataSource: dependencies.storageService,
      ),
    );

    // 3. Use Cases
    getIt.registerLazySingleton<GetDataUseCase>(
      () => GetDataUseCase(
        repository: getIt<MyRepository>(),
      ),
    );

    // 4. BLoC/Cubit (Factory para permitir múltiplas instâncias se necessário)
    getIt.registerFactory<MyBloc>(
      () => MyBloc(
        getDataUseCase: getIt<GetDataUseCase>(),
        analyticsService: dependencies.analyticsService,
      ),
    );
  }

  /// Remove todos os registros (usado em testes)
  static void unregister(GetIt getIt) {
    if (getIt.isRegistered<MyBloc>()) {
      getIt.unregister<MyBloc>();
    }
    if (getIt.isRegistered<GetDataUseCase>()) {
      getIt.unregister<GetDataUseCase>();
    }
    if (getIt.isRegistered<MyRepository>()) {
      getIt.unregister<MyRepository>();
    }
    if (getIt.isRegistered<MyRemoteDataSource>()) {
      getIt.unregister<MyRemoteDataSource>();
    }
  }
}
```

### Regras de Injeção

- **Data Sources:** `registerLazySingleton`
- **Repositories:** `registerLazySingleton`
- **Use Cases:** `registerLazySingleton` ou `registerFactory`
- **BLoCs/Cubits:** `registerFactory` (permite múltiplas instâncias)

---

## 🎨 Gerenciamento de Estado

### Padrão BLoC

**SEMPRE** use BLoC ou Cubit do pacote `flutter_bloc`.

#### Quando Usar BLoC vs Cubit

- **Use BLoC quando:**
  - Precisa rastrear eventos explicitamente
  - Lógica de negócio complexa
  - Múltiplos eventos podem resultar no mesmo estado

- **Use Cubit quando:**
  - Lógica simples
  - Métodos diretos são suficientes
  - Não precisa rastrear eventos

#### Estrutura de BLoC

```dart
// presentation/bloc/my_bloc.dart
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_data_usecase.dart';
import 'my_event.dart';
import 'my_state.dart';

/// BLoC para gerenciar [funcionalidade]
///
/// Eventos:
/// - [LoadDataEvent]: Carrega dados iniciais
/// - [RefreshDataEvent]: Atualiza dados
///
/// Estados:
/// - [MyInitialState]: Estado inicial
/// - [MyLoadingState]: Carregando dados
/// - [MyLoadedState]: Dados carregados com sucesso
/// - [MyErrorState]: Erro ao carregar dados
class MyBloc extends Bloc<MyEvent, MyState> {
  final GetDataUseCase _getDataUseCase;
  final AnalyticsService _analyticsService;

  MyBloc({
    required GetDataUseCase getDataUseCase,
    required AnalyticsService analyticsService,
  })  : _getDataUseCase = getDataUseCase,
        _analyticsService = analyticsService,
        super(const MyInitialState()) {
    on<LoadDataEvent>(_onLoadData);
    on<RefreshDataEvent>(_onRefreshData);
  }

  Future<void> _onLoadData(
    LoadDataEvent event,
    Emitter<MyState> emit,
  ) async {
    emit(const MyLoadingState());

    try {
      final data = await _getDataUseCase.execute();

      _analyticsService.trackEvent('data_loaded', {
        'count': data.length,
      });

      emit(MyLoadedState(data: data));
    } catch (e, stackTrace) {
      _analyticsService.trackError('data_load_failed', e.toString());

      emit(MyErrorState(
        message: 'Falha ao carregar dados: $e',
      ));
    }
  }

  Future<void> _onRefreshData(
    RefreshDataEvent event,
    Emitter<MyState> emit,
  ) async {
    // Implementação...
  }
}
```

### Provider Pattern

**SEMPRE** use `.value` para compartilhar instância singleton:

```dart
// ✅ CORRETO
BlocProvider<MyBloc>.value(
  value: myBloc,
  child: MyPage(),
)

// ❌ ERRADO
BlocProvider<MyBloc>(
  create: (context) => MyBloc(...),
  child: MyPage(),
)
```

---

## 🗺️ Roteamento

### Padrão de Rotas

```dart
@override
Map<String, GoRouteBuilder> get routes => {
  // Rota simples
  '/my-module': (context, state) {
    ensureInitialized();
    return BlocProvider<MyBloc>.value(
      value: myBloc,
      child: const MyHomePage(),
    );
  },

  // Rota com parâmetro obrigatório
  '/my-module/:id': (context, state) {
    ensureInitialized();

    try {
      final id = RouteParamsValidator.getRequiredParam(
        state.params,
        'id',
      );

      return BlocProvider<MyBloc>.value(
        value: myBloc,
        child: MyDetailPage(id: id),
      );
    } on RouteParamException catch (e) {
      return InvalidParamErrorPage(message: e.message);
    }
  },

  // Rota com UUID
  '/my-module/item/:itemId': (context, state) {
    ensureInitialized();

    try {
      final itemId = RouteParamsValidator.getUuidParam(
        state.params,
        'itemId',
      );

      return BlocProvider<MyBloc>.value(
        value: myBloc,
        child: ItemDetailPage(itemId: itemId),
      );
    } on RouteParamException catch (e) {
      return InvalidParamErrorPage(message: e.message);
    }
  },

  // Rota com query parameters
  '/my-module/search': (context, state) {
    ensureInitialized();

    final query = RouteParamsValidator.getOptionalParam(
      state.queryParams,
      'q',
    );

    return BlocProvider<MyBloc>.value(
      value: myBloc,
      child: SearchPage(initialQuery: query),
    );
  },
};
```

### Regras de Roteamento

✅ **FAZER:**
- Validar TODOS os parâmetros
- Usar `RouteParamsValidator`
- Retornar página de erro para parâmetros inválidos
- Compartilhar instância de BLoC via `.value`

❌ **NÃO FAZER:**
- Force unwrap (`!`) parâmetros
- Criar nova instância de BLoC por rota
- Ignorar validação

---

## ⚠️ Tratamento de Erros

Ver [ERROR_HANDLING_GUIDE.md](./ERROR_HANDLING_GUIDE.md) para detalhes completos.

### Resumo de Regras

1. **SEMPRE** use exceções customizadas (herdam de `AppException`)
2. **SEMPRE** logue erros via `LoggingService`
3. **NUNCA** ignore exceções silenciosamente
4. **NUNCA** use `debugPrint` em código de produção

---

## 🧪 Testes

Ver [TESTING_STRATEGY.md](./TESTING_STRATEGY.md) para estratégia completa.

### Cobertura Mínima Exigida

- **Domain Layer:** 90%
- **Data Layer:** 80%
- **Presentation Layer:** 70%
- **Overall:** 75%

### Tipos de Testes

1. **Unit Tests:** BLoCs, Use Cases, Repositories
2. **Widget Tests:** Páginas e widgets
3. **Integration Tests:** Fluxos completos

---

## ✅ Checklist de Implementação

### Ao Criar Novo Micro App

#### Estrutura
- [ ] Estrutura de diretórios seguindo padrão
- [ ] Arquivo barrel (`[nome].dart`) criado
- [ ] README.md com documentação básica

#### Código
- [ ] Classe principal estende `BaseMicroApp`
- [ ] Documentação dartdoc completa
- [ ] Injector implementado
- [ ] BLoCs/Cubits criados
- [ ] Rotas definidas e validadas
- [ ] Health check customizado implementado

#### Qualidade
- [ ] Zero warnings de análise
- [ ] Lint rules passando
- [ ] Testes unitários (≥75% cobertura)
- [ ] Testes de widget
- [ ] Testes de integração para fluxos principais

#### Documentação
- [ ] Dartdoc em APIs públicas
- [ ] Comentários explicativos em lógica complexa
- [ ] README atualizado

#### Integração
- [ ] Registrado em `injection_container.dart`
- [ ] Rotas adicionadas ao router
- [ ] Health check funcionando
- [ ] Navegação testada

---

## 📚 Recursos Adicionais

- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [BLoC Pattern Documentation](https://bloclibrary.dev/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

---

**Última Atualização:** 2025-11-07
**Mantenedor:** Tech Lead / Architect
**Revisão:** Trimestral
