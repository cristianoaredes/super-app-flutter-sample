# Account Micro App - Tests

Testes abrangentes para o micro app de Conta do Premium Bank Super App.

## 📊 Cobertura de Testes

### AccountBloc Tests
**Arquivo**: `test/presentation/bloc/account_bloc_test.dart`
**Test Cases**: 18
**Cobertura**: 100% BLoC

#### Eventos Testados:

1. **LoadAccountEvent** (3 test cases)
   - ✅ Carregamento bem-sucedido da conta
   - ✅ Erro ao carregar conta
   - ✅ Rastreamento de analytics

2. **LoadAccountBalanceEvent** (3 test cases)
   - ✅ Carregamento bem-sucedido do saldo
   - ✅ Erro ao carregar saldo
   - ✅ Rastreamento de analytics

3. **LoadAccountStatementEvent** (4 test cases)
   - ✅ Carregamento bem-sucedido com filtros de data
   - ✅ Carregamento bem-sucedido sem filtros de data
   - ✅ Erro ao carregar extrato
   - ✅ Rastreamento de analytics

4. **TransferMoneyEvent** (4 test cases)
   - ✅ Transferência bem-sucedida com descrição
   - ✅ Transferência bem-sucedida sem descrição
   - ✅ Erro na transferência (saldo insuficiente, etc.)
   - ✅ Rastreamento de analytics com metadados

#### Grupos de Teste Adicionais:

5. **Analytics Tracking** (2 test cases)
   - ✅ Rastreamento de todas operações bem-sucedidas
   - ✅ Rastreamento de todos os erros

6. **Error Messages** (2 test cases)
   - ✅ Inclusão de mensagens de erro nos estados
   - ✅ Preservação de detalhes de erro

#### Estados Testados:

**Account States**:
- `AccountInitialState` - Estado inicial
- `AccountLoadingState` - Carregando conta
- `AccountLoadedState` - Conta carregada
- `AccountErrorState` - Erro ao carregar conta

**Balance States**:
- `AccountBalanceLoadingState` - Carregando saldo
- `AccountBalanceLoadedState` - Saldo carregado
- `AccountBalanceErrorState` - Erro ao carregar saldo

**Statement States**:
- `AccountStatementLoadingState` - Carregando extrato
- `AccountStatementLoadedState` - Extrato carregado
- `AccountStatementErrorState` - Erro ao carregar extrato

**Transfer States**:
- `TransferMoneyLoadingState` - Processando transferência
- `TransferMoneySuccessState` - Transferência bem-sucedida
- `TransferMoneyErrorState` - Erro na transferência

#### Use Cases Mockados:

- `GetAccountUseCase`
- `GetAccountBalanceUseCase`
- `GetAccountStatementUseCase`
- `TransferMoneyUseCase`
- `AnalyticsService`

## 🚀 Executando os Testes

### Todos os testes do micro app:
```bash
cd packages/micro_apps/account
flutter test
```

### Com cobertura:
```bash
cd packages/micro_apps/account
flutter test --coverage
```

### Teste específico:
```bash
cd packages/micro_apps/account
flutter test test/presentation/bloc/account_bloc_test.dart
```

### Via Melos (da raiz do projeto):
```bash
# Todos os testes de Account
melos run test:account

# Todos os testes do projeto
melos test
```

## 🧪 Estrutura dos Testes

```
test/
├── presentation/
│   └── bloc/
│       ├── account_bloc_test.dart        # Testes do BLoC principal
│       └── account_bloc_test.mocks.dart  # Mocks gerados
└── README.md
```

## 📝 Padrões de Teste

### Estrutura de um Teste BLoC:

```dart
blocTest<AccountBloc, AccountState>(
  'emits [AccountLoadingState, AccountLoadedState] when load succeeds',
  build: () {
    when(mockGetAccountUseCase.execute())
        .thenAnswer((_) async => testAccount);
    return accountBloc;
  },
  act: (bloc) => bloc.add(const LoadAccountEvent()),
  expect: () => [
    const AccountLoadingState(),
    AccountLoadedState(account: testAccount),
  ],
  verify: (_) {
    verify(mockGetAccountUseCase.execute()).called(1);
    verify(mockAnalyticsService.trackEvent('account_load', any)).called(1);
  },
);
```

### Dados de Teste:

```dart
// Account
final testAccount = Account(
  id: '1',
  number: '12345-6',
  agency: '0001',
  holderName: 'John Doe',
  holderDocument: '12345678900',
  type: AccountType.checking,
  status: AccountStatus.active,
  openingDate: DateTime(2020, 1, 1),
);

// Balance
final testBalance = AccountBalance(
  accountId: '1',
  available: 5000.0,
  total: 5000.0,
  blocked: 0.0,
  overdraftLimit: 1000.0,
  overdraftUsed: 0.0,
  updatedAt: DateTime(2024, 1, 1),
);

// Transaction
final testTransaction = Transaction(
  id: 'tx1',
  accountId: '1',
  description: 'Test transaction',
  amount: 100.0,
  date: DateTime(2024, 1, 1),
  type: TransactionType.debit,
  status: TransactionStatus.completed,
  category: 'Transfer',
);

// Statement
final testStatement = AccountStatement(
  accountId: '1',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 31),
  initialBalance: 5000.0,
  finalBalance: 4900.0,
  transactions: [testTransaction],
);
```

## 🔍 Cenários de Teste Cobertos

### ✅ Casos de Sucesso:
- Carregar informações da conta
- Carregar saldo da conta
- Carregar extrato com filtros de data
- Carregar extrato sem filtros (período completo)
- Realizar transferência com descrição
- Realizar transferência sem descrição

### ❌ Casos de Erro:
- Falha ao carregar conta
- Falha ao carregar saldo
- Falha ao carregar extrato
- Falha na transferência (saldo insuficiente, dados inválidos, etc.)

### 📊 Casos Especiais:
- **Parâmetros opcionais**: Testa com e sem `startDate`/`endDate`, `description`
- **Analytics tracking**: Verifica metadados específicos (amount, destination_bank)
- **Error preservation**: Mantém mensagens de erro detalhadas para debugging
- **Multiple operations**: Testa sequência de operações independentes

## 🎯 Métricas

| Categoria | Cobertura | Test Cases |
|-----------|-----------|------------|
| **Initial State** | 100% | 1 |
| **LoadAccountEvent** | 100% | 3 |
| **LoadAccountBalanceEvent** | 100% | 3 |
| **LoadAccountStatementEvent** | 100% | 4 |
| **TransferMoneyEvent** | 100% | 4 |
| **Analytics** | 100% | 2 |
| **Error Messages** | 100% | 2 |
| **Total** | 100% | 18 |

## 🔄 Gerando Mocks

Os mocks são gerados automaticamente pelo `build_runner`:

```bash
cd packages/micro_apps/account
flutter pub run build_runner build --delete-conflicting-outputs
```

Os mocks são salvos em `account_bloc_test.mocks.dart` e não devem ser editados manualmente.

## 🏗️ Arquitetura de Teste

### Fluxos de Operação

**LoadAccount**:
```
LoadAccountEvent
└─ AccountLoadingState
   └─ Success: AccountLoadedState
   └─ Error: AccountErrorState
```

**LoadAccountBalance**:
```
LoadAccountBalanceEvent
└─ AccountBalanceLoadingState
   └─ Success: AccountBalanceLoadedState
   └─ Error: AccountBalanceErrorState
```

**LoadAccountStatement**:
```
LoadAccountStatementEvent
├─ startDate: optional
├─ endDate: optional
└─ AccountStatementLoadingState
   └─ Success: AccountStatementLoadedState
   └─ Error: AccountStatementErrorState
```

**TransferMoney**:
```
TransferMoneyEvent
├─ Required: account, agency, bank, name, document, amount
├─ Optional: description
└─ TransferMoneyLoadingState
   └─ Success: TransferMoneySuccessState (with Transaction)
   └─ Error: TransferMoneyErrorState
```

## 📚 Documentação Adicional

- [BLoC Testing Documentation](https://bloclibrary.dev/#/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [ARCHITECTURE.md](/docs/architecture/ARCHITECTURE.md) - Arquitetura do projeto
- [CONTRIBUTING.md](/CONTRIBUTING.md) - Guia de contribuição

## 🏆 Boas Práticas

1. **Teste parâmetros opcionais**:
   - Com valores fornecidos
   - Sem valores (null/omitidos)

2. **Verifique analytics com metadados**:
   ```dart
   verify(mockAnalyticsService.trackEvent('transfer_money', {
     'amount': 100.0,
     'destination_bank': '001',
   })).called(1);
   ```

3. **Preserve contexto de erro**:
   - Use mensagens descritivas
   - Inclua detalhes originais da exceção

4. **Teste operações independentes**:
   - Cada evento deve funcionar isoladamente
   - Não assuma estado de eventos anteriores

5. **Valide estados intermediários**:
   - Loading states são importantes para UX
   - Sempre verifique a transição completa

## 🐛 Troubleshooting

### Erro: "Missing required parameter"
**Problema**: Evento requer parâmetros obrigatórios.

**Solução**: Verifique a definição do evento em `account_event.dart`:
```dart
const TransferMoneyEvent({
  required this.destinationAccount,
  required this.destinationAgency,
  // ... outros campos required
  this.description, // opcional
});
```

### Erro: "State not emitted in expected order"
**Problema**: Estados não aparecem na sequência esperada.

**Solução**: Cada evento do AccountBloc segue o padrão:
1. Loading state
2. Success/Error state

### Comportamento: Analytics não rastreado
**Problema**: Método `trackEvent` não foi chamado.

**Expectativa**: Verifique se o stub está configurado no `setUp`:
```dart
when(mockAnalyticsService.trackEvent(any, any))
    .thenAnswer((_) async => {});
```

## 🎨 Padrões de Design

### Separação de Concerns
```dart
// BLoC responsável apenas por lógica de negócio
// Use Cases encapsulam operações do domínio
// Analytics tracking separado da lógica principal
```

### Error Handling Consistente
```dart
try {
  // Operação
  _analyticsService.trackEvent('operation_success', {...});
  emit(SuccessState(...));
} catch (e) {
  _analyticsService.trackError('operation_error', e.toString());
  emit(ErrorState(message: e.toString()));
}
```

### Analytics Metadata
```dart
// Inclui informações relevantes para análise
_analyticsService.trackEvent('transfer_money', {
  'amount': event.amount,
  'destination_bank': event.destinationBank,
});
```

## 📈 Próximos Passos

- [ ] Adicionar testes de widget para páginas
- [ ] Adicionar testes de integração para fluxo completo de transferência
- [ ] Adicionar testes de repository
- [ ] Testar casos edge (valores muito grandes, caracteres especiais, etc.)
- [ ] Aumentar cobertura para 100% em todas as camadas
