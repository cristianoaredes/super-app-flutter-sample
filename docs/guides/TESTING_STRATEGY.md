# 🧪 Estratégia de Testes - Premium Bank

**Versão:** 1.0
**Data:** 2025-11-07
**Status:** Draft

---

## 🎯 Objetivo

Estabelecer uma estratégia de testes abrangente, pragmática e eficaz para garantir qualidade e confiabilidade do Premium Bank Flutter Super App.

**Metas:**
- Cobertura geral ≥ 70%
- Prevenir regressões
- Facilitar refatorações
- Documentar comportamento esperado
- CI/CD confiável

---

## 📋 Índice

1. [Pirâmide de Testes](#pirâmide-de-testes)
2. [Tipos de Testes](#tipos-de-testes)
3. [Cobertura por Camada](#cobertura-por-camada)
4. [Ferramentas e Setup](#ferramentas-e-setup)
5. [Padrões e Convenções](#padrões-e-convenções)
6. [Mocking Strategy](#mocking-strategy)
7. [CI/CD Integration](#cicd-integration)
8. [Exemplos Práticos](#exemplos-práticos)

---

## 🔺 Pirâmide de Testes

```
           ┌─────────────┐
           │   E2E (5%)  │
           │   Manual    │
           └──────┬──────┘
              ┌───┴─────────┐
              │ Integration │
              │    (15%)    │
              └──────┬──────┘
                 ┌───┴────────┐
                 │   Widget   │
                 │    (30%)   │
                 └─────┬──────┘
                    ┌──┴──────┐
                    │  Unit   │
                    │  (50%)  │
                    └─────────┘
```

### Distribuição Recomendada

| Tipo | Percentual | Foco | Velocidade |
|------|-----------|------|------------|
| **Unit Tests** | 50% | Lógica de negócio, utils, transformações | Muito rápido (ms) |
| **Widget Tests** | 30% | UI components, interações básicas | Rápido (s) |
| **Integration Tests** | 15% | Fluxos completos, navegação | Moderado (s-min) |
| **E2E Tests** | 5% | Cenários críticos end-to-end | Lento (min) |

---

## 🧪 Tipos de Testes

### 1. Unit Tests

**O que testar:**
- BLoCs/Cubits (eventos, estados, transições)
- Use Cases (lógica de negócio)
- Repositories (transformação de dados)
- Models (serialização/deserialização)
- Utils e helpers
- Validators

**Estrutura:**

```dart
// test/micro_apps/auth/domain/usecases/login_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthRepository, AnalyticsService])
import 'login_usecase_test.mocks.dart';

void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockRepository;
  late MockAnalyticsService mockAnalytics;

  setUp(() {
    mockRepository = MockAuthRepository();
    mockAnalytics = MockAnalyticsService();
    useCase = LoginUseCase(
      repository: mockRepository,
      analyticsService: mockAnalytics,
    );
  });

  group('LoginUseCase', () {
    const tEmail = 'test@example.com';
    const tPassword = 'password123';
    final tUser = User(id: '1', email: tEmail, name: 'Test');

    test('should return User when credentials are valid', () async {
      // Arrange
      when(mockRepository.login(any, any))
          .thenAnswer((_) async => tUser);

      // Act
      final result = await useCase.execute(tEmail, tPassword);

      // Assert
      expect(result, equals(tUser));
      verify(mockRepository.login(tEmail, tPassword)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should throw InvalidCredentialsException when credentials are invalid', () async {
      // Arrange
      when(mockRepository.login(any, any))
          .thenThrow(InvalidCredentialsException());

      // Act & Assert
      expect(
        () => useCase.execute(tEmail, 'wrong_password'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('should throw ValidationException when email is invalid', () async {
      // Act & Assert
      expect(
        () => useCase.execute('invalid-email', tPassword),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
```

### 2. Widget Tests

**O que testar:**
- Renderização de widgets
- Interações do usuário (tap, scroll, input)
- Estados de loading, error, success
- Navegação básica
- Validação de formulários

**Estrutura:**

```dart
// test/micro_apps/auth/presentation/pages/login_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([AuthBloc])
import 'login_page_test.mocks.dart';

void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    when(mockAuthBloc.state).thenReturn(const AuthInitialState());
    when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const AuthInitialState()));
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const LoginPage(),
      ),
    );
  }

  group('LoginPage Widget Tests', () {
    testWidgets('should display email and password fields', (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
    });

    testWidgets('should display login button', (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
    });

    testWidgets('should show loading indicator when state is AuthLoading', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const AuthLoadingState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const AuthLoadingState()));

      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message when state is AuthError', (tester) async {
      // Arrange
      const errorMessage = 'Email ou senha inválidos';
      when(mockAuthBloc.state).thenReturn(const AuthErrorState(message: errorMessage));
      when(mockAuthBloc.stream).thenAnswer(
        (_) => Stream.value(const AuthErrorState(message: errorMessage)),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Rebuild after stream emission

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('should call login event when login button is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();

      // Assert
      verify(mockAuthBloc.add(const LoginWithEmailAndPasswordEvent(
        email: 'test@example.com',
        password: 'password123',
      ))).called(1);
    });

    testWidgets('should not submit form with empty fields', (tester) async {
      // Arrange
      await tester.pumpWidget(createWidgetUnderTest());

      // Act
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();

      // Assert
      expect(find.text('Email é obrigatório'), findsOneWidget);
      expect(find.text('Senha é obrigatória'), findsOneWidget);
      verifyNever(mockAuthBloc.add(any));
    });
  });
}
```

### 3. Integration Tests

**O que testar:**
- Fluxos completos (login → dashboard → logout)
- Navegação entre micro apps
- Inicialização de micro apps sob demanda
- Persistência de estado
- Comunicação entre módulos

**Estrutura:**

```dart
// integration_test/auth_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:super_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    testWidgets('should complete full login flow', (tester) async {
      // Arrange
      await app.main();
      await tester.pumpAndSettle();

      // Act 1: Navegar para login
      expect(find.text('Premium Bank'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3)); // Esperar splash

      // Assert 1: Deve estar na tela de login
      expect(find.text('Login'), findsOneWidget);

      // Act 2: Preencher formulário
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      // Assert 2: Deve navegar para dashboard
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Bem-vindo'), findsOneWidget);
    });

    testWidgets('should navigate between micro apps', (tester) async {
      // Setup: Login
      await app.main();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.enterText(
        find.byKey(const Key('email_field')),
        'user@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      // Act 1: Navegar para Pix
      await tester.tap(find.text('Pix'));
      await tester.pumpAndSettle();

      // Assert 1: Micro app Pix carregado
      expect(find.text('Pix'), findsOneWidget);

      // Act 2: Navegar para Pagamentos
      await tester.tap(find.text('Pagamentos'));
      await tester.pumpAndSettle();

      // Assert 2: Micro app Pagamentos carregado
      expect(find.text('Pagamentos'), findsOneWidget);

      // Act 3: Voltar para Dashboard
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();

      // Assert 3: De volta ao Dashboard
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
```

### 4. BLoC Tests

**Usando `bloc_test` package:**

```dart
// test/micro_apps/auth/presentation/bloc/auth_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([LoginUseCase, LogoutUseCase, AnalyticsService])
import 'auth_bloc_test.mocks.dart';

void main() {
  late AuthBloc authBloc;
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockAnalyticsService mockAnalyticsService;

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
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
    final tUser = User(id: '1', email: 'test@example.com', name: 'Test');

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
          password: 'password',
        ),
      ),
      expect: () => [
        const AuthLoadingState(),
        AuthenticatedState(user: tUser),
      ],
      verify: (_) {
        verify(mockLoginUseCase.executeWithEmailAndPassword(
          'test@example.com',
          'password',
        )).called(1);
        verify(mockAnalyticsService.trackEvent('login_success', any)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should emit [AuthLoadingState, AuthErrorState] when login fails',
      build: () {
        when(mockLoginUseCase.executeWithEmailAndPassword(any, any))
            .thenThrow(InvalidCredentialsException());
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
        isA<AuthErrorState>()
            .having((s) => s.message, 'message', contains('inválidos')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('login_error', any)).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'should emit [AuthLoadingState, UnauthenticatedState] when logout succeeds',
      build: () {
        when(mockLogoutUseCase.execute()).thenAnswer((_) async => {});
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
}
```

---

## 📊 Cobertura por Camada

### Metas de Cobertura

| Camada | Meta | Prioridade | Foco |
|--------|------|-----------|------|
| **Domain** | 90% | Crítica | 100% dos use cases |
| **Data** | 80% | Alta | Repositories, models |
| **Presentation** | 70% | Alta | BLoCs, páginas críticas |
| **UI Widgets** | 60% | Média | Componentes reutilizáveis |
| **Overall** | 70% | Alta | Projeto completo |

### O que NÃO precisa de 100% cobertura

- Generated code (`*.g.dart`, `*.freezed.dart`)
- Main entry points (`main.dart`)
- Configurações simples
- Widgets triviais (apenas composição)
- Code de terceiros

---

## 🛠️ Ferramentas e Setup

### Dependências

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter

  # Unit Testing
  test: ^1.24.0
  mockito: ^5.4.2
  build_runner: ^2.4.6

  # BLoC Testing
  bloc_test: ^9.1.4

  # Integration Testing
  integration_test:
    sdk: flutter

  # Coverage
  coverage: ^1.6.3
```

### Scripts Melos

```yaml
# melos.yaml
scripts:
  test:
    run: flutter test --coverage
    description: Run all tests with coverage

  test:unit:
    run: flutter test test/
    description: Run only unit tests

  test:integration:
    run: flutter test integration_test/
    description: Run integration tests

  test:watch:
    run: flutter test --watch
    description: Run tests in watch mode

  coverage:report:
    run: |
      flutter test --coverage
      genhtml coverage/lcov.info -o coverage/html
      open coverage/html/index.html
    description: Generate HTML coverage report

  coverage:check:
    run: |
      flutter test --coverage
      lcov --summary coverage/lcov.info
    description: Check coverage summary
```

### Gerando Mocks

```bash
# Gerar mocks para um arquivo específico
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (regenera automaticamente)
flutter pub run build_runner watch --delete-conflicting-outputs
```

---

## 📐 Padrões e Convenções

### Estrutura de Teste (AAA Pattern)

```dart
test('should do something when condition happens', () {
  // Arrange (Setup)
  final dependency = MockDependency();
  final sut = SystemUnderTest(dependency: dependency);
  when(dependency.method()).thenReturn(expectedValue);

  // Act (Execute)
  final result = sut.execute();

  // Assert (Verify)
  expect(result, equals(expectedValue));
  verify(dependency.method()).called(1);
});
```

### Nomenclatura

**Test Files:**
- `[nome_do_arquivo]_test.dart`
- Espelhar estrutura de `lib/` em `test/`

**Test Groups:**
```dart
group('ClassName', () {
  group('methodName', () {
    test('should return X when Y', () {});
    test('should throw Z when W', () {});
  });
});
```

**Test Names:**
- Use `should [expected behavior] when [condition]`
- Seja específico e descritivo
- Evite nomes genéricos como "test1", "works correctly"

**Exemplos:**
```dart
✅ 'should return user when credentials are valid'
✅ 'should throw InvalidCredentialsException when password is wrong'
✅ 'should emit [Loading, Loaded] when data fetch succeeds'

❌ 'login test'
❌ 'works'
❌ 'test1'
```

### Organização de Arquivos

```
test/
├── micro_apps/
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   │       └── login_usecase_test.dart
│   │   ├── data/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── auth_bloc_test.dart
│   │       └── pages/
│   │           └── login_page_test.dart
│   └── ...
├── shared/
│   ├── utils/
│   └── validators/
└── helpers/
    ├── test_helpers.dart
    └── mock_data.dart
```

---

## 🎭 Mocking Strategy

### Quando Usar Mocks

✅ **USE mocks para:**
- Dependências externas (API, database)
- Services que você não controla
- Componentes complexos ou lentos
- Isolar unidade sendo testada

❌ **NÃO use mocks para:**
- Entidades simples (models, DTOs)
- Código que você está testando
- Value objects

### Gerando Mocks com Mockito

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Gerar mocks para estas classes
@GenerateMocks([
  AuthRepository,
  NetworkService,
  StorageService,
  AnalyticsService,
])
import 'my_test.mocks.dart'; // Arquivo gerado

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  test('example', () {
    // Configurar comportamento
    when(mockAuthRepository.login(any, any))
        .thenAnswer((_) async => User(/*...*/));

    // Usar mock
    final result = await mockAuthRepository.login('email', 'pass');

    // Verificar chamadas
    verify(mockAuthRepository.login('email', 'pass')).called(1);
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
```

### Stubs vs Mocks

**Stub:** Retorna dados pré-definidos
```dart
when(mockRepository.getUser()).thenReturn(testUser);
```

**Mock:** Verifica comportamento
```dart
verify(mockRepository.saveUser(any)).called(1);
```

### Test Doubles Patterns

```dart
// 1. Dummy: Apenas preenche parâmetro
final dummy = MockService();

// 2. Stub: Retorna dados fixos
when(stub.getData()).thenReturn(testData);

// 3. Spy: Registra chamadas
verify(spy.method()).called(1);

// 4. Mock: Verifica comportamento
verifyInOrder([
  mock.firstMethod(),
  mock.secondMethod(),
]);

// 5. Fake: Implementação simplificada
class FakeRepository implements Repository {
  final List<User> _users = [];

  @override
  Future<void> saveUser(User user) async {
    _users.add(user);
  }
}
```

---

## 🔄 CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.2'
          channel: 'stable'

      - name: Install Melos
        run: dart pub global activate melos

      - name: Bootstrap packages
        run: melos bootstrap

      - name: Generate code
        run: melos run build_runner

      - name: Run tests
        run: melos run test

      - name: Check coverage
        run: |
          flutter test --coverage
          lcov --summary coverage/lcov.info

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage/lcov.info
          fail_ci_if_error: true

      - name: Verify minimum coverage
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info | grep lines | awk '{print $2}' | sed 's/%//')
          if (( $(echo "$COVERAGE < 70" | bc -l) )); then
            echo "Coverage is below 70%: $COVERAGE%"
            exit 1
          fi
```

### Configuração de Coverage

```yaml
# coverage.yaml (na raiz do projeto)
coverage:
  precision: 2
  round: down
  range: "50...100"

  status:
    project:
      default:
        target: 70%
        threshold: 2%
    patch:
      default:
        target: 80%

ignore:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/main.dart"
  - "**/injection_container.dart"
  - "test/**"
```

---

## 📝 Exemplos Práticos

### Exemplo Completo: Repository Test

```dart
// test/data/repositories/transactions_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TransactionsRemoteDataSource, StorageService])
import 'transactions_repository_impl_test.mocks.dart';

void main() {
  late TransactionsRepositoryImpl repository;
  late MockTransactionsRemoteDataSource mockRemoteDataSource;
  late MockStorageService mockStorageService;

  setUp(() {
    mockRemoteDataSource = MockTransactionsRemoteDataSource();
    mockStorageService = MockStorageService();
    repository = TransactionsRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      storageService: mockStorageService,
    );
  });

  group('getTransactions', () {
    final tTransactionModels = [
      TransactionModel(id: '1', amount: 100, description: 'Test 1'),
      TransactionModel(id: '2', amount: 200, description: 'Test 2'),
    ];

    final tTransactions = [
      Transaction(id: '1', amount: 100, description: 'Test 1'),
      Transaction(id: '2', amount: 200, description: 'Test 2'),
    ];

    test('should return transactions when remote data source succeeds', () async {
      // Arrange
      when(mockRemoteDataSource.getTransactions())
          .thenAnswer((_) async => tTransactionModels);

      // Act
      final result = await repository.getTransactions();

      // Assert
      expect(result, equals(tTransactions));
      verify(mockRemoteDataSource.getTransactions()).called(1);
    });

    test('should cache transactions locally after successful fetch', () async {
      // Arrange
      when(mockRemoteDataSource.getTransactions())
          .thenAnswer((_) async => tTransactionModels);
      when(mockStorageService.setValue(any, any))
          .thenAnswer((_) async => true);

      // Act
      await repository.getTransactions();

      // Assert
      verify(mockStorageService.setValue('cached_transactions', any)).called(1);
    });

    test('should return cached data when remote fetch fails', () async {
      // Arrange
      when(mockRemoteDataSource.getTransactions())
          .thenThrow(NetworkException(message: 'No internet'));
      when(mockStorageService.getValue<List>('cached_transactions'))
          .thenAnswer((_) async => tTransactionModels.map((t) => t.toJson()).toList());

      // Act
      final result = await repository.getTransactions();

      // Assert
      expect(result, equals(tTransactions));
      verify(mockStorageService.getValue<List>('cached_transactions')).called(1);
    });

    test('should throw NetworkException when both remote and cache fail', () async {
      // Arrange
      when(mockRemoteDataSource.getTransactions())
          .thenThrow(NetworkException(message: 'No internet'));
      when(mockStorageService.getValue<List>('cached_transactions'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => repository.getTransactions(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
```

---

## ✅ Checklist de Code Review

Ao revisar testes:

### Qualidade
- [ ] Testes são independentes (não dependem de ordem)
- [ ] Testes são determinísticos (sempre mesmo resultado)
- [ ] Testes são rápidos (< 1s cada unit test)
- [ ] Testes têm nomes descritivos
- [ ] Usa padrão AAA (Arrange, Act, Assert)

### Cobertura
- [ ] Testa casos de sucesso
- [ ] Testa casos de erro
- [ ] Testa edge cases
- [ ] Testa validações
- [ ] Cobertura ≥ meta da camada

### Mocks
- [ ] Mocks são necessários
- [ ] Mocks são configurados corretamente
- [ ] Verifica interações importantes
- [ ] Não há over-mocking

### Manutenibilidade
- [ ] Código de teste é limpo
- [ ] Sem duplicação
- [ ] Helpers extraídos quando apropriado
- [ ] Documentação para testes complexos

---

## 📚 Recursos Adicionais

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [BLoC Testing Library](https://pub.dev/packages/bloc_test)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Testing Best Practices](https://martinfowler.com/articles/practical-test-pyramid.html)

---

**Última Atualização:** 2025-11-07
**Mantenedor:** Tech Lead / QA Lead
**Revisão:** Trimestral
