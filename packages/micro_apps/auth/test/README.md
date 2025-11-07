# Auth Micro App - Tests

Este diretório contém todos os testes para o micro app de autenticação.

## Estrutura de Testes

```
test/
├── data/
│   └── repositories/
│       └── auth_repository_impl_test.dart    # Testes do repositório
├── presentation/
│   ├── bloc/
│   │   └── auth_bloc_test.dart               # Testes do AuthBloc
│   └── pages/
│       └── login_page_test.dart              # Testes da LoginPage
└── README.md
```

## Cobertura de Testes

### Unit Tests (BLoC)
- ✅ AuthBloc
  - Teste de estado inicial
  - Login com email/senha (sucesso e erro)
  - Login com Google (sucesso e erro)
  - Login com Apple (sucesso e erro)
  - Logout (sucesso e erro)
  - Registro (sucesso e erro)
  - Reset de senha (sucesso e erro)
  - Tracking de analytics

### Unit Tests (Repository)
- ✅ AuthRepositoryImpl
  - getCurrentUser
  - isAuthenticated
  - loginWithEmailAndPassword
  - loginWithGoogle
  - loginWithApple
  - logout
  - register
  - Tratamento de erros de rede

### Widget Tests
- ✅ LoginPage
  - Renderização de formulário
  - Validação de campos
  - Toggle de visibilidade de senha
  - Dispatch de eventos
  - Navegação
  - Estados de loading e erro

## Como Executar os Testes

### 1. Gerar Mocks

Antes de executar os testes, você precisa gerar os mocks usando o build_runner:

```bash
cd packages/micro_apps/auth
dart run build_runner build --delete-conflicting-outputs
```

### 2. Executar Todos os Testes

```bash
cd packages/micro_apps/auth
flutter test
```

### 3. Executar Teste Específico

```bash
flutter test test/presentation/bloc/auth_bloc_test.dart
```

### 4. Executar com Cobertura

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

Abra `coverage/html/index.html` no navegador para ver o relatório de cobertura.

## Dependências de Teste

As seguintes dependências são usadas para testes (já configuradas no `pubspec.yaml`):

- **flutter_test**: Framework de testes do Flutter
- **mockito**: Para criar mocks de dependências
- **bloc_test**: Para testar BLoCs de forma simplificada
- **build_runner**: Para gerar código de mocks

## Boas Práticas

### 1. Nomenclatura
- Arquivos de teste devem ter sufixo `_test.dart`
- Mocks devem ter prefixo `Mock`

### 2. Estrutura do Teste
```dart
void main() {
  // Setup compartilhado
  late MyClass myClass;

  setUp(() {
    myClass = MyClass();
  });

  tearDown(() {
    // Cleanup se necessário
  });

  group('Feature', () {
    test('should do something when condition', () {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

### 3. BLoC Tests
Use `blocTest` para testar BLoCs de forma declarativa:

```dart
blocTest<MyBloc, MyState>(
  'emits [State1, State2] when event is added',
  build: () => myBloc,
  act: (bloc) => bloc.add(MyEvent()),
  expect: () => [State1(), State2()],
  verify: (_) {
    // Verificações adicionais
  },
);
```

### 4. Widget Tests
Use `WidgetTester` para interagir com widgets:

```dart
testWidgets('should render widget', (WidgetTester tester) async {
  await tester.pumpWidget(MyWidget());
  expect(find.text('Hello'), findsOneWidget);
});
```

## Metas de Cobertura

Seguindo a estratégia de testes do projeto (docs/guides/TESTING_STRATEGY.md):

- **Unit Tests**: 50% (✅ Completo para Auth)
- **Widget Tests**: 30% (✅ LoginPage completo)
- **Integration Tests**: 15% (⏳ Pendente)
- **E2E Tests**: 5% (⏳ Pendente)

## Próximos Passos

- [ ] Adicionar testes para RegisterPage
- [ ] Adicionar testes para ResetPasswordPage
- [ ] Adicionar testes para UseCases
- [ ] Adicionar integration tests para fluxo completo de auth
