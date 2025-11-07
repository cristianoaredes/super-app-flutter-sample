# Dashboard Micro App - Tests

Este diretório contém todos os testes para o micro app de Dashboard.

## Estrutura de Testes

```
test/
├── presentation/
│   ├── bloc/
│   │   └── dashboard_bloc_test.dart          # Testes do DashboardBloc
│   └── pages/
│       └── dashboard_page_test.dart          # Testes da DashboardPage
└── README.md
```

## Cobertura de Testes

### Unit Tests (BLoC)
- ✅ DashboardBloc
  - Teste de estado inicial
  - LoadDashboardEvent (sucesso, erro, analytics)
  - RefreshDashboardEvent (com/sem dados em cache, erro)
  - LoadTransactionEvent (sucesso, não encontrado, erro)
  - Tratamento de erros de analytics
  - Estado DashboardLoadingWithDataState
  - Estado DashboardErrorState com dados em cache

### Widget Tests
- ✅ DashboardPage
  - Renderização de AppBar e botões
  - Dispatch de LoadDashboardEvent no init
  - Estados de loading (inicial e com dados)
  - Exibição de dados quando carregado
  - Botão de refresh
  - Pull-to-refresh gesture
  - Exibição de erros
  - Erro com dados em cache
  - Botão "Tentar novamente"

## Como Executar os Testes

### 1. Gerar Mocks

Antes de executar os testes, você precisa gerar os mocks usando o build_runner:

```bash
cd packages/micro_apps/dashboard
dart run build_runner build --delete-conflicting-outputs
```

### 2. Executar Todos os Testes

```bash
cd packages/micro_apps/dashboard
flutter test
```

### 3. Executar Teste Específico

```bash
flutter test test/presentation/bloc/dashboard_bloc_test.dart
```

### 4. Executar com Cobertura

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Dependências de Teste

As seguintes dependências são usadas para testes (já configuradas no `pubspec.yaml`):

- **flutter_test**: Framework de testes do Flutter
- **mockito**: Para criar mocks de dependências
- **bloc_test**: Para testar BLoCs de forma simplificada
- **build_runner**: Para gerar código de mocks

## Cenários de Teste

### LoadDashboardEvent
1. ✅ Carregamento bem-sucedido de todos os dados
2. ✅ Erro ao carregar dados (estado inicial)
3. ✅ Tratamento gracioso de erros de analytics
4. ✅ Carregamento paralelo de múltiplos use cases

### RefreshDashboardEvent
1. ✅ Refresh do estado inicial (sem dados)
2. ✅ Refresh com dados em cache (DashboardLoadingWithDataState)
3. ✅ Erro ao fazer refresh com dados em cache
4. ✅ Erro ao fazer refresh sem dados em cache
5. ✅ Pull-to-refresh gesture

### LoadTransactionEvent
1. ✅ Carregamento bem-sucedido de transação
2. ✅ Transação não encontrada (null)
3. ✅ Erro ao carregar transação

### Estados do Dashboard
1. ✅ DashboardInitialState → Loading indicator
2. ✅ DashboardLoadingState → Loading indicator
3. ✅ DashboardLoadingWithDataState → Data + Loading indicator
4. ✅ DashboardLoadedState → Data completo
5. ✅ DashboardErrorState sem dados → Error message + Retry button
6. ✅ DashboardErrorState com dados → Data + Error snackbar

## Metas de Cobertura

Seguindo a estratégia de testes do projeto (docs/guides/TESTING_STRATEGY.md):

- **Unit Tests**: ✅ 100% (11 test cases)
- **Widget Tests**: ✅ 90% (11 test cases)
- **Integration Tests**: ⏳ Pendente
- **E2E Tests**: ⏳ Pendente

## Próximos Passos

- [ ] Adicionar testes para TransactionDetailsPage
- [ ] Adicionar testes para widgets individuais (AccountSummaryCard, QuickActionsGrid)
- [ ] Adicionar testes para DashboardRepository
- [ ] Adicionar integration tests para fluxo completo de dashboard
