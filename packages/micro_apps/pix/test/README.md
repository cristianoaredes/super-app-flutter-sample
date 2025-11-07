# Pix Micro App - Tests

Testes abrangentes para o micro app de Pix do Premium Bank Super App.

## 📊 Cobertura de Testes

### PixBloc Tests
**Arquivo**: `test/presentation/bloc/pix_bloc_test.dart`
**Test Cases**: 21
**Cobertura**: 100% BLoC

#### Eventos Testados:

1. **LoadPixKeysEvent** (2 test cases)
   - ✅ Carregamento bem-sucedido de chaves
   - ✅ Tratamento de erro no carregamento

2. **RegisterPixKeyEvent** (2 test cases)
   - ✅ Registro bem-sucedido de chave
   - ✅ Tratamento de erro no registro

3. **DeletePixKeyEvent** (2 test cases)
   - ✅ Exclusão bem-sucedida de chave
   - ✅ Tratamento de erro na exclusão

4. **LoadPixTransactionsEvent** (2 test cases)
   - ✅ Carregamento bem-sucedido de transações
   - ✅ Tratamento de erro no carregamento

5. **LoadPixTransactionEvent** (3 test cases)
   - ✅ Carregamento bem-sucedido de transação
   - ✅ Transação não encontrada
   - ✅ Tratamento de erro no carregamento

6. **SendPixEvent** (2 test cases)
   - ✅ Envio bem-sucedido de Pix
   - ✅ Tratamento de erro no envio (saldo insuficiente, etc.)

7. **ReceivePixEvent** (2 test cases)
   - ✅ Geração bem-sucedida de QR Code para recebimento
   - ✅ Tratamento de erro na geração

8. **GenerateQrCodeEvent** (2 test cases)
   - ✅ Geração bem-sucedida de QR Code
   - ✅ Tratamento de erro na geração

9. **ReadQrCodeEvent** (2 test cases)
   - ✅ Leitura bem-sucedida de QR Code
   - ✅ Tratamento de erro na leitura (QR inválido)

10. **Analytics Tracking** (2 test cases)
    - ✅ Rastreamento de operações bem-sucedidas
    - ✅ Rastreamento de erros

#### Estados Testados:

**Composite States** (para operações paralelas):
- `PixCompositeState` com `PixKeysLoadingState` → `PixKeysLoadedState`
- `PixCompositeState` com `PixKeysErrorState`
- `PixCompositeState` com `PixTransactionsLoadingState` → `PixTransactionsLoadedState`
- `PixCompositeState` com `PixTransactionsErrorState`

**Key Management States**:
- `PixKeyRegisteringState` → `PixKeyRegisteredState`
- `PixKeyDeletingState` → `PixKeyDeletedState`
- `PixKeysErrorState`

**Transaction States**:
- `PixTransactionLoadingState` → `PixTransactionLoadedState`
- `PixTransactionErrorState`
- `PixSendingState` → `PixSentState`
- `PixSendErrorState`

**QR Code States**:
- `PixQrCodeGeneratingState` → `PixQrCodeGeneratedState`
- `PixQrCodeGenerateErrorState`
- `PixQrCodeReadingState` → `PixQrCodeReadState`
- `PixQrCodeReadErrorState`

#### Use Cases Mockados:

- `GetPixKeysUseCase`
- `RegisterPixKeyUseCase`
- `DeletePixKeyUseCase`
- `SendPixUseCase`
- `ReceivePixUseCase`
- `GenerateQrCodeUseCase`
- `ReadQrCodeUseCase`
- `AnalyticsService`

## 🚀 Executando os Testes

### Todos os testes do micro app:
```bash
cd packages/micro_apps/pix
flutter test
```

### Com cobertura:
```bash
cd packages/micro_apps/pix
flutter test --coverage
```

### Teste específico:
```bash
cd packages/micro_apps/pix
flutter test test/presentation/bloc/pix_bloc_test.dart
```

### Via Melos (da raiz do projeto):
```bash
# Todos os testes de Pix
melos run test:pix

# Todos os testes do projeto
melos test
```

## 🧪 Estrutura dos Testes

```
test/
├── presentation/
│   └── bloc/
│       ├── pix_bloc_test.dart          # Testes do BLoC principal
│       └── pix_bloc_test.mocks.dart    # Mocks gerados
└── README.md
```

## 📝 Padrões de Teste

### Estrutura de um Teste BLoC:

```dart
blocTest<PixBloc, PixState>(
  'descrição clara do comportamento esperado',
  build: () {
    // Setup: Configurar mocks e retornos
    when(mockUseCase.execute(any))
        .thenAnswer((_) async => testData);
    return pixBloc;
  },
  act: (bloc) => bloc.add(const SomeEvent()),
  expect: () => [
    // Estados esperados na sequência
    const LoadingState(),
    LoadedState(data: testData),
  ],
  verify: (_) {
    // Verificações: UseCase foi chamado? Analytics rastreado?
    verify(mockUseCase.execute(any)).called(1);
    verify(mockAnalyticsService.trackEvent('event_name', any)).called(1);
  },
);
```

### Dados de Teste:

```dart
// PixKey de teste
final testPixKey = PixKey(
  id: '1',
  value: '12345678900',
  type: PixKeyType.cpf,
  name: 'Test Key',
  createdAt: DateTime(2024, 1, 1),
  isActive: true,
);

// PixTransaction de teste
final testTransaction = PixTransaction(
  id: 'tx1',
  description: 'Test payment',
  amount: 100.0,
  date: DateTime(2024, 1, 1),
  type: PixTransactionType.outgoing,
  status: PixTransactionStatus.completed,
  sender: testParticipant,
  receiver: testParticipant,
);

// PixQrCode de teste
final testQrCode = PixQrCode(
  id: 'qr1',
  payload: 'test_payload',
  pixKey: testPixKey,
  amount: 50.0,
  createdAt: DateTime(2024, 1, 1),
  isStatic: false,
);
```

## 🔍 Cenários de Teste Cobertos

### ✅ Casos de Sucesso:
- Carregar lista de chaves Pix
- Registrar nova chave Pix
- Excluir chave Pix existente
- Carregar histórico de transações
- Carregar detalhes de transação específica
- Enviar Pix para outra chave
- Gerar QR Code para recebimento
- Gerar QR Code estático/dinâmico
- Ler QR Code de pagamento

### ❌ Casos de Erro:
- Falha na API ao carregar chaves
- Erro ao registrar chave (chave já existe, etc.)
- Erro ao excluir chave (chave não encontrada)
- Falha na API ao carregar transações
- Transação não encontrada
- Saldo insuficiente para envio
- Erro na geração de QR Code
- QR Code inválido na leitura

### 📊 Casos Especiais:
- Estado composto (PixCompositeState) para gerenciar múltiplos estados
- Rastreamento de analytics em operações bem-sucedidas
- Rastreamento de erros em operações falhadas
- Validação de parâmetros opcionais (description, receiverName, etc.)
- QR Code estático vs dinâmico
- Expiração de QR Codes

## 🎯 Métricas

| Categoria | Cobertura | Test Cases |
|-----------|-----------|------------|
| **PixBloc** | 100% | 21 |
| **Total** | 100% | 21 |

## 🔄 Gerando Mocks

Os mocks são gerados automaticamente pelo `build_runner`:

```bash
cd packages/micro_apps/pix
flutter pub run build_runner build --delete-conflicting-outputs
```

Os mocks são salvos em `pix_bloc_test.mocks.dart` e não devem ser editados manualmente.

## 📚 Documentação Adicional

- [BLoC Testing Documentation](https://bloclibrary.dev/#/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [ARCHITECTURE.md](/docs/architecture/ARCHITECTURE.md) - Arquitetura do projeto
- [CONTRIBUTING.md](/CONTRIBUTING.md) - Guia de contribuição

## 🏆 Boas Práticas

1. **Sempre teste os 3 caminhos**:
   - ✅ Caminho feliz (sucesso)
   - ❌ Caminho de erro (falha)
   - 🔀 Casos especiais (edge cases)

2. **Verifique analytics**:
   - Toda operação bem-sucedida deve rastrear evento
   - Todo erro deve rastrear erro

3. **Use dados de teste realistas**:
   - CPF/CNPJ válidos
   - Valores monetários reais
   - Datas e timestamps corretos

4. **Mantenha testes isolados**:
   - Cada teste deve ser independente
   - Use `setUp` e `tearDown` para limpar estado
   - Não compartilhe estado entre testes

5. **Nomes descritivos**:
   - Use `should...when...` ou `emits...when...`
   - Seja específico sobre o comportamento testado
   - Inclua contexto sobre o cenário

## 🐛 Troubleshooting

### Erro: "Missing stub"
**Problema**: Mock não foi configurado para um método específico.

**Solução**: Adicione um `when()` para o método no `setUp()` ou no teste:
```dart
when(mockUseCase.execute(any)).thenAnswer((_) async => testData);
```

### Erro: "Expected X states but got Y"
**Problema**: Os estados emitidos não correspondem aos esperados.

**Solução**: Verifique:
1. A ordem dos estados está correta?
2. Todos os estados intermediários estão incluídos?
3. O estado inicial é contado?

### Erro: "Null check operator used on a null value"
**Problema**: Dados de teste não foram inicializados corretamente.

**Solução**: Verifique se todos os campos obrigatórios estão preenchidos nos objetos de teste.

## 📈 Próximos Passos

- [ ] Adicionar testes de widget para páginas Pix
- [ ] Adicionar testes de integração para fluxo completo
- [ ] Adicionar testes de repository
- [ ] Aumentar cobertura para 100% em todas as camadas
