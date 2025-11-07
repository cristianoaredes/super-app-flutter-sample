# Payments Micro App - Tests

Este diretório contém todos os testes para o micro app de Pagamentos.

## Estrutura de Testes

```
test/
├── presentation/
│   └── cubits/
│       └── payments_cubit_test.dart         # Testes do PaymentsCubit
└── README.md
```

## Cobertura de Testes

### Unit Tests (Cubit)
- ✅ PaymentsCubit
  - Estado inicial
  - fetchPayments (sucesso, erro, lista vazia)
  - makePayment (sucesso, erro, validações)
  - cancelPayment (sucesso, falha, erro)
  - Gerenciamento de estado (loading, error, success)
  - Preservação de dados em caso de erro
  - Analytics tracking para todas as operações

## Como Executar os Testes

### 1. Gerar Mocks

Antes de executar os testes, você precisa gerar os mocks usando o build_runner:

```bash
cd packages/micro_apps/payments
dart run build_runner build --delete-conflicting-outputs
```

### 2. Executar Todos os Testes

```bash
cd packages/micro_apps/payments
flutter test
```

### 3. Executar com Cobertura

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Dependências de Teste

- **flutter_test**: Framework de testes do Flutter
- **mockito**: Para criar mocks de dependências
- **bloc_test**: Para testar Cubits de forma simplificada
- **build_runner**: Para gerar código de mocks

## Cenários de Teste

### fetchPayments
1. ✅ Carregamento bem-sucedido de pagamentos
2. ✅ Lista vazia de pagamentos
3. ✅ Erro ao carregar pagamentos
4. ✅ Analytics tracking

### makePayment
1. ✅ Criação bem-sucedida de pagamento
2. ✅ Erro ao criar pagamento (fundos insuficientes)
3. ✅ Atualização automática da lista após sucesso
4. ✅ Preservação de estado em caso de erro
5. ✅ Analytics tracking

### cancelPayment
1. ✅ Cancelamento bem-sucedido
2. ✅ Falha no cancelamento (retorna false)
3. ✅ Erro no cancelamento (exception)
4. ✅ Atualização da lista após cancelamento
5. ✅ Analytics tracking

## Metas de Cobertura

Seguindo a estratégia de testes do projeto (docs/guides/TESTING_STRATEGY.md):

- **Unit Tests**: ✅ 100% (15 test cases)
- **Widget Tests**: ⏳ Pendente
- **Integration Tests**: ⏳ Pendente

## Próximos Passos

- [ ] Adicionar testes para PaymentsPage
- [ ] Adicionar testes para PaymentDetailPage
- [ ] Adicionar testes para PaymentRepository
- [ ] Adicionar integration tests para fluxo completo de pagamento
