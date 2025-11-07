# Arquitetura do Premium Bank Super App

## Visão Geral

O Premium Bank Super App é um aplicativo Flutter baseado em **arquitetura de micro apps modular**. Cada funcionalidade do aplicativo é isolada em um módulo independente (micro app) que pode ser desenvolvido, testado e mantido separadamente.

## Índice

1. [Conceitos Fundamentais](#conceitos-fundamentais)
2. [Arquitetura de Micro Apps](#arquitetura-de-micro-apps)
3. [Estrutura de Diretórios](#estrutura-de-diretórios)
4. [Camadas da Aplicação](#camadas-da-aplicação)
5. [Fluxo de Dados](#fluxo-de-dados)
6. [Padrões de Design](#padrões-de-design)
7. [Gestão de Estado](#gestão-de-estado)
8. [Navegação](#navegação)
9. [Injeção de Dependências](#injeção-de-dependências)
10. [Comunicação entre Micro Apps](#comunicação-entre-micro-apps)

---

## Conceitos Fundamentais

### Micro Apps

Um **Micro App** é um módulo independente que encapsula:
- Uma funcionalidade completa do negócio
- Suas próprias rotas de navegação
- Seus próprios componentes de UI
- Seu próprio gerenciamento de estado
- Suas próprias dependências

**Vantagens**:
- ✅ **Modularidade**: Cada feature é isolada
- ✅ **Escalabilidade**: Times podem trabalhar em paralelo
- ✅ **Testabilidade**: Testes isolados por módulo
- ✅ **Manutenibilidade**: Mudanças não afetam outros módulos
- ✅ **Reutilização**: Micro apps podem ser compartilhados

### Clean Architecture

Cada micro app segue os princípios de **Clean Architecture**:

```
┌─────────────────────────────────────────────┐
│           Presentation Layer                │
│  (UI, Widgets, BLoC/Cubit, Pages)          │
├─────────────────────────────────────────────┤
│           Domain Layer                      │
│  (Entities, UseCases, Repositories)        │
├─────────────────────────────────────────────┤
│           Data Layer                        │
│  (Repository Impl, DataSources, Models)   │
└─────────────────────────────────────────────┘
```

**Regras de Dependência**:
- Presentation → Domain → Data
- Nunca o contrário
- Domain layer não conhece detalhes de implementação

---

## Arquitetura de Micro Apps

### Hierarquia do Sistema

```
super_app (app principal)
    ├── packages/
    │   ├── core/
    │   │   ├── core_interfaces/      # Interfaces compartilhadas
    │   │   ├── core_network/         # Cliente HTTP
    │   │   ├── core_storage/         # Persistência
    │   │   └── core_analytics/       # Analytics
    │   │
    │   ├── shared/
    │   │   ├── design_system/        # Componentes UI
    │   │   └── shared_utils/         # Utilitários
    │   │
    │   └── micro_apps/
    │       ├── auth/                 # Autenticação
    │       ├── dashboard/            # Dashboard
    │       ├── payments/             # Pagamentos
    │       ├── pix/                  # PIX
    │       ├── cards/                # Cartões
    │       ├── account/              # Conta
    │       └── splash/               # Splash
```

### Ciclo de Vida de um Micro App

```dart
/// 1. Registro no GetIt (main.dart)
getIt.registerLazySingleton<MicroApp>(
  () => AuthMicroApp(),
  instanceName: 'auth',
);

/// 2. Inicialização (lazy - quando necessário)
final microApp = getIt<MicroApp>(instanceName: 'auth');
await microApp.initialize(dependencies);

/// 3. Uso
final routes = microApp.routes; // Rotas do micro app
final widget = microApp.build(context); // Widget raiz

/// 4. Dispose (quando não mais necessário)
await microApp.dispose();
```

### BaseMicroApp Pattern

Todos os micro apps herdam de `BaseMicroApp`:

```dart
abstract class BaseMicroApp implements MicroApp {
  final GetIt getIt;
  bool _initialized = false;
  MicroAppDependencies? _dependencies;

  /// Inicialização padronizada
  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) return;
    _dependencies = dependencies;
    await onInitialize(dependencies);
    _initialized = true;
  }

  /// Hook para implementação customizada
  @protected
  Future<void> onInitialize(MicroAppDependencies dependencies);

  /// Hook para limpeza de recursos
  @protected
  Future<void> onDispose();

  /// Health check do micro app
  @protected
  Future<bool> checkHealth() async => true;
}
```

**Benefícios**:
- Elimina código duplicado (~200 linhas removidas)
- Padroniza lifecycle management
- Facilita manutenção
- Permite validações centralizadas

---

## Estrutura de Diretórios

### Estrutura de um Micro App

```
micro_apps/auth/
├── lib/
│   ├── auth.dart                          # Barrel file (exports públicos)
│   └── src/
│       ├── auth_micro_app.dart           # Implementação do micro app
│       │
│       ├── domain/                        # Regras de negócio
│       │   ├── entities/                  # Entidades do domínio
│       │   │   └── user.dart
│       │   ├── repositories/              # Contratos de repositórios
│       │   │   └── auth_repository.dart
│       │   └── usecases/                  # Casos de uso
│       │       ├── login_usecase.dart
│       │       └── logout_usecase.dart
│       │
│       ├── data/                          # Implementação de dados
│       │   ├── models/                    # Modelos de dados
│       │   │   └── user_model.dart
│       │   ├── datasources/               # Fontes de dados
│       │   │   ├── auth_remote_datasource.dart
│       │   │   └── auth_local_datasource.dart
│       │   └── repositories/              # Implementação de repositórios
│       │       └── auth_repository_impl.dart
│       │
│       ├── presentation/                  # Camada de apresentação
│       │   ├── bloc/                      # Gerenciamento de estado
│       │   │   ├── auth_bloc.dart
│       │   │   ├── auth_event.dart
│       │   │   └── auth_state.dart
│       │   ├── pages/                     # Páginas/Telas
│       │   │   ├── login_page.dart
│       │   │   └── register_page.dart
│       │   └── widgets/                   # Widgets reutilizáveis
│       │       └── auth_button.dart
│       │
│       ├── di/                            # Injeção de dependências
│       │   └── auth_injector.dart
│       │
│       └── router/                        # Configuração de rotas
│           └── auth_routes.dart
│
├── test/                                  # Testes
│   ├── data/
│   │   └── repositories/
│   ├── presentation/
│   │   ├── bloc/
│   │   └── pages/
│   └── README.md
│
└── pubspec.yaml                           # Dependências do micro app
```

### Estrutura de Pacotes Core

```
core/core_interfaces/
├── lib/
│   └── src/
│       ├── micro_app.dart                 # Interface MicroApp
│       ├── base_micro_app.dart           # Classe base abstrata
│       ├── services/                      # Interfaces de serviços
│       │   ├── navigation_service.dart
│       │   ├── analytics_service.dart
│       │   ├── logging_service.dart
│       │   ├── storage_service.dart
│       │   ├── network_service.dart
│       │   └── auth_service.dart
│       └── exceptions/                    # Hierarquia de exceções
│           └── app_exceptions.dart
```

---

## Camadas da Aplicação

### 1. Presentation Layer (Apresentação)

**Responsabilidades**:
- Renderizar UI
- Capturar eventos do usuário
- Gerenciar estado da UI
- Reagir a mudanças de estado

**Componentes**:

#### BLoC/Cubit
Gerencia o estado da UI usando o padrão BLoC:

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final AnalyticsService _analyticsService;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required AnalyticsService analyticsService,
  })  : _loginUseCase = loginUseCase,
        _analyticsService = analyticsService,
        super(const AuthInitialState()) {
    on<LoginWithEmailAndPasswordEvent>(_onLogin);
  }

  Future<void> _onLogin(
    LoginWithEmailAndPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoadingState());

    try {
      final user = await _loginUseCase.execute(
        event.email,
        event.password,
      );

      _analyticsService.trackEvent('login_success', {
        'user_id': user.id,
      });

      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }
}
```

#### Pages
Telas completas da aplicação:

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      },
      builder: (context, state) {
        if (state is AuthLoadingState) {
          return const LoadingIndicator();
        }

        return LoginForm();
      },
    );
  }
}
```

#### Widgets
Componentes reutilizáveis:

```dart
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const CircularProgressIndicator()
          : Text(label),
    );
  }
}
```

### 2. Domain Layer (Domínio)

**Responsabilidades**:
- Definir regras de negócio
- Definir entidades
- Definir contratos (interfaces)
- Orquestrar fluxos de negócio

**Componentes**:

#### Entities
Objetos de negócio puros:

```dart
class User extends Equatable {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, email, createdAt];
}
```

#### Repositories (Interfaces)
Contratos para acesso a dados:

```dart
abstract class AuthRepository {
  Future<User> loginWithEmailAndPassword(String email, String password);
  Future<User> loginWithGoogle();
  Future<void> logout();
  Future<User> register(String name, String email, String password);
  Future<User?> getCurrentUser();
  Future<bool> isAuthenticated();
}
```

#### UseCases
Casos de uso específicos:

```dart
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<User> execute(String email, String password) async {
    // Validações de negócio
    if (email.isEmpty || password.isEmpty) {
      throw ValidationException(
        message: 'Email e senha são obrigatórios',
      );
    }

    // Delegação para o repositório
    return _repository.loginWithEmailAndPassword(email, password);
  }
}
```

### 3. Data Layer (Dados)

**Responsabilidades**:
- Implementar repositórios
- Buscar dados de APIs
- Persistir dados localmente
- Transformar modelos

**Componentes**:

#### Repository Implementation
Implementação concreta:

```dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final NetworkService _networkService;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;

  @override
  Future<User> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    // Verifica conexão
    if (!await _networkService.hasInternetConnection) {
      throw NoInternetException();
    }

    // Busca dados remotos
    final userModel = await _remoteDataSource.loginWithEmailAndPassword(
      email,
      password,
    );

    // Persiste localmente
    await _localDataSource.saveUser(userModel);

    // Retorna entidade
    return userModel;
  }
}
```

#### DataSources
Fontes de dados:

```dart
abstract class AuthRemoteDataSource {
  Future<UserModel> loginWithEmailAndPassword(String email, String password);
  Future<UserModel> loginWithGoogle();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final NetworkService _networkService;

  AuthRemoteDataSourceImpl(this._networkService);

  @override
  Future<UserModel> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final response = await _networkService.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return UserModel.fromJson(response.data);
  }
}
```

#### Models
Representação de dados:

```dart
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

---

## Fluxo de Dados

### Fluxo de Login (Exemplo Completo)

```
┌──────────────┐
│  LoginPage   │  1. Usuário clica em "Entrar"
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   AuthBloc   │  2. Dispatch LoginEvent
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ LoginUseCase │  3. Valida dados
└──────┬───────┘
       │
       ▼
┌────────────────────┐
│ AuthRepository     │  4. Busca dados
└──────┬─────────────┘
       │
       ├─────────────────┐
       ▼                 ▼
┌─────────────┐   ┌────────────────┐
│   Remote    │   │     Local      │  5. Fontes de dados
│ DataSource  │   │  DataSource    │
└─────┬───────┘   └────────┬───────┘
      │                    │
      │ 6. UserModel       │ 7. Cache
      └──────────┬─────────┘
                 │
                 ▼
       ┌──────────────┐
       │   AuthBloc   │  8. Emit AuthenticatedState
       └──────┬───────┘
              │
              ▼
       ┌──────────────┐
       │  LoginPage   │  9. Navega para Dashboard
       └──────────────┘
```

### Fluxo de Erro

```
[User Action] → [BLoC Event] → [UseCase]
                                    ↓ Exception
                                    ↓
                              [Custom Exception]
                                    ↓
                              [BLoC catches]
                                    ↓
                            [Emit ErrorState]
                                    ↓
                              [UI shows error]
```

---

## Padrões de Design

### 1. Repository Pattern
Abstrai a origem dos dados:

```dart
// Interface no Domain Layer
abstract class PaymentRepository {
  Future<List<Payment>> getPayments();
  Future<void> makePayment(Payment payment);
}

// Implementação no Data Layer
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remote;
  final PaymentLocalDataSource _local;

  @override
  Future<List<Payment>> getPayments() async {
    try {
      final payments = await _remote.getPayments();
      await _local.cachePayments(payments);
      return payments;
    } catch (e) {
      return _local.getCachedPayments();
    }
  }
}
```

### 2. Dependency Injection
Usando GetIt:

```dart
class AuthInjector {
  static void register(GetIt getIt) {
    // DataSources
    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt<NetworkService>()),
    );

    getIt.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(getIt<StorageService>()),
    );

    // Repository
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: getIt<AuthRemoteDataSource>(),
        localDataSource: getIt<AuthLocalDataSource>(),
        networkService: getIt<NetworkService>(),
      ),
    );

    // UseCases
    getIt.registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(getIt<AuthRepository>()),
    );

    // BLoC
    getIt.registerFactory<AuthBloc>(
      () => AuthBloc(
        loginUseCase: getIt<LoginUseCase>(),
        analyticsService: getIt<AnalyticsService>(),
      ),
    );
  }
}
```

### 3. Factory Pattern
Para criação de objetos complexos:

```dart
class MicroAppFactory {
  static MicroApp create(String id, {GetIt? getIt}) {
    switch (id) {
      case 'auth':
        return AuthMicroApp(getIt: getIt);
      case 'dashboard':
        return DashboardMicroApp(getIt: getIt);
      case 'payments':
        return PaymentsMicroApp(getIt: getIt);
      default:
        throw UnsupportedMicroAppException(id);
    }
  }
}
```

### 4. Observer Pattern
Via BLoC/Cubit:

```dart
// Subscription
final subscription = authBloc.stream.listen((state) {
  if (state is AuthenticatedState) {
    print('User logged in: ${state.user.name}');
  }
});

// Cleanup
subscription.cancel();
```

---

## Gestão de Estado

### BLoC Pattern

**Quando usar BLoC**:
- Lógica complexa de negócio
- Múltiplos eventos
- Transformações de stream necessárias

```dart
// Events
abstract class PaymentEvent {}
class LoadPayments extends PaymentEvent {}
class MakePayment extends PaymentEvent {
  final Payment payment;
  MakePayment(this.payment);
}

// States
abstract class PaymentState {}
class PaymentInitial extends PaymentState {}
class PaymentLoading extends PaymentState {}
class PaymentLoaded extends PaymentState {
  final List<Payment> payments;
  PaymentLoaded(this.payments);
}
class PaymentError extends PaymentState {
  final String message;
  PaymentError(this.message);
}

// BLoC
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc() : super(PaymentInitial()) {
    on<LoadPayments>(_onLoadPayments);
    on<MakePayment>(_onMakePayment);
  }

  Future<void> _onLoadPayments(
    LoadPayments event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final payments = await repository.getPayments();
      emit(PaymentLoaded(payments));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }
}
```

### Cubit Pattern

**Quando usar Cubit**:
- Lógica simples
- Estado direto sem eventos

```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

### HydratedBloc

Para persistência automática de estado:

```dart
class PaymentsCubit extends HydratedCubit<PaymentsState> {
  PaymentsCubit() : super(const PaymentsState());

  @override
  PaymentsState? fromJson(Map<String, dynamic> json) =>
      PaymentsState.fromJson(json);

  @override
  Map<String, dynamic>? toJson(PaymentsState state) =>
      state.toJson();
}
```

---

## Navegação

### GoRouter

Navegação declarativa e type-safe:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/payments/:id',
      builder: (context, state) {
        final id = state.params['id']!;
        return PaymentDetailPage(id: id);
      },
    ),
  ],
  redirect: (context, state) {
    final isLoggedIn = getIt<AuthService>().isAuthenticated;
    final isLoginRoute = state.location == '/login';

    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    if (isLoggedIn && isLoginRoute) {
      return '/dashboard';
    }

    return null;
  },
);
```

### Deep Links

Suporte a deep links por micro app:

```dart
class AuthMicroApp extends BaseMicroApp {
  @override
  Map<String, GoRouteBuilder> get routes => {
    '/login': (context, state) => const LoginPage(),
    '/register': (context, state) => const RegisterPage(),
    '/reset-password': (context, state) => const ResetPasswordPage(),
  };
}
```

### NavigationService

Serviço centralizado:

```dart
class NavigationService {
  final GoRouter router;

  NavigationService(this.router);

  void navigateTo(String path, {Map<String, String>? params}) {
    if (params != null) {
      final uri = Uri(path: path, queryParameters: params);
      router.push(uri.toString());
    } else {
      router.push(path);
    }
  }

  void goBack() => router.pop();

  void replaceTo(String path) => router.pushReplacement(path);
}
```

---

## Injeção de Dependências

### GetIt Service Locator

```dart
// Setup no main.dart
Future<void> setupDependencies() async {
  final getIt = GetIt.instance;

  // Serviços core (Singleton)
  getIt.registerSingleton<NetworkService>(
    NetworkServiceImpl(),
  );

  getIt.registerSingleton<StorageService>(
    StorageServiceImpl(),
  );

  getIt.registerSingleton<AnalyticsService>(
    AnalyticsServiceImpl(),
  );

  // Micro Apps (Lazy Singleton)
  getIt.registerLazySingleton<MicroApp>(
    () => AuthMicroApp(getIt: getIt),
    instanceName: 'auth',
  );

  getIt.registerLazySingleton<MicroApp>(
    () => DashboardMicroApp(getIt: getIt),
    instanceName: 'dashboard',
  );
}
```

### Resolução de Dependências

```dart
// Obter instância
final authService = getIt<AuthService>();

// Obter instância nomeada
final authMicroApp = getIt<MicroApp>(instanceName: 'auth');

// Factory (nova instância sempre)
final bloc = getIt<AuthBloc>();

// Verificar se registrado
if (getIt.isRegistered<AuthService>()) {
  // ...
}
```

---

## Comunicação entre Micro Apps

### 1. ApplicationHub (Event Bus)

Para comunicação assíncrona:

```dart
class ApplicationHub {
  final _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get events => _controller.stream;

  void dispatch(AppEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}

// Uso
// Enviar evento
applicationHub.dispatch(UserLoggedOutEvent());

// Escutar evento
applicationHub.events.listen((event) {
  if (event is UserLoggedOutEvent) {
    // Limpar dados sensíveis
  }
});
```

### 2. SharedServices

Para dados compartilhados:

```dart
class AuthService {
  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }
}

// Uso em qualquer micro app
final authService = getIt<AuthService>();
final user = authService.currentUser;
```

### 3. NavigationService

Para navegação entre micro apps:

```dart
// Do Auth para Dashboard
navigationService.navigateTo('/dashboard');

// Do Dashboard para Payments
navigationService.navigateTo('/payments/new');
```

---

## Boas Práticas

### ✅ DO

1. **Mantenha micro apps independentes**
   - Cada micro app deve funcionar isoladamente
   - Minimize dependências entre micro apps

2. **Use interfaces para desacoplamento**
   - Domain layer define contratos
   - Data layer implementa

3. **Teste cada camada separadamente**
   - Unit tests para domain/data
   - Widget tests para presentation
   - Integration tests para fluxos completos

4. **Siga naming conventions**
   - `*_page.dart` para páginas
   - `*_widget.dart` para widgets
   - `*_bloc.dart`, `*_event.dart`, `*_state.dart` para BLoC

5. **Documente APIs públicas**
   - Dartdoc para classes/métodos públicos
   - README para cada micro app

### ❌ DON'T

1. **Não acople micro apps diretamente**
   ```dart
   // ❌ Ruim
   class DashboardPage {
     final AuthMicroApp authMicroApp;
   }

   // ✅ Bom
   class DashboardPage {
     final AuthService authService;
   }
   ```

2. **Não pule camadas**
   ```dart
   // ❌ Ruim - BLoC chamando DataSource diretamente
   class AuthBloc {
     final AuthRemoteDataSource dataSource;
   }

   // ✅ Bom - BLoC usa UseCase
   class AuthBloc {
     final LoginUseCase loginUseCase;
   }
   ```

3. **Não misture responsabilidades**
   - Widget não deve ter lógica de negócio
   - BLoC não deve ter lógica de UI
   - Repository não deve ter validações de negócio

---

## Referências

- [Flutter BLoC Documentation](https://bloclibrary.dev)
- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [GetIt Documentation](https://pub.dev/packages/get_it)

---

## Próximos Passos

- Ver [Guia de Onboarding](../guides/ONBOARDING.md)
- Ver [Guia de Testes](../guides/TESTING_STRATEGY.md)
- Ver [Guia de Contribuição](../CONTRIBUTING.md)
