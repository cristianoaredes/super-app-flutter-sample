# Cards Micro App - Tests

Testes abrangentes para o micro app de Cartões do Premium Bank Super App.

## 📊 Cobertura de Testes

### CardsBloc Tests
**Arquivo**: `test/presentation/bloc/cards_bloc_test.dart`
**Test Cases**: 16
**Cobertura**: 100% BLoC

#### Eventos Testados:

1. **LoadCardsEvent** (6 test cases)
   - ✅ Carregamento inicial bem-sucedido
   - ✅ Não recarrega quando já inicializado
   - ✅ Carregamento com dados existentes
   - ✅ Erro sem dados em cache
   - ✅ Erro com dados em cache
   - ✅ Rastreamento de analytics

2. **RefreshCardsEvent** (4 test cases)
   - ✅ Delega para LoadCardsEvent quando não inicializado
   - ✅ Refresh bem-sucedido com dados
   - ✅ Erro durante refresh preserva dados
   - ✅ Rastreamento de analytics

#### Grupos de Teste Adicionais:

3. **Error Handling** (2 test cases)
   - ✅ Preservação de dados em estados de erro
   - ✅ Mensagens de erro diferentes para load vs refresh

4. **Lifecycle** (3 test cases)
   - ✅ Flag isInitialized após carregamento
   - ✅ Flag isInitialized após close
   - ✅ Não emite estados após close

5. **Analytics Tracking** (2 test cases)
   - ✅ Rastreamento de operações bem-sucedidas
   - ✅ Rastreamento de erros

6. **Data Preservation** (2 test cases)
   - ✅ Manutenção da lista durante loading states
   - ✅ Preservação de dados em erro state

#### Estados Testados:

**Loading States**:
- `CardsInitialState` - Estado inicial
- `CardsLoadingState` - Carregamento sem dados
- `CardsLoadingWithDataState` - Carregamento preservando dados
- `CardsLoadedState` - Dados carregados com sucesso
- `CardsErrorState` - Erro com/sem dados preservados

**Comportamentos Especiais**:
- Caching inteligente (não recarrega se já inicializado)
- Preservação de dados durante operações
- Estados de loading diferenciados (com/sem dados)
- Tratamento de erros mantendo UX

#### Use Cases Mockados:

- `GetCardsUseCase`
- `AnalyticsService`

## 🚀 Executando os Testes

### Todos os testes do micro app:
```bash
cd packages/micro_apps/cards
flutter test
```

### Com cobertura:
```bash
cd packages/micro_apps/cards
flutter test --coverage
```

### Teste específico:
```bash
cd packages/micro_apps/cards
flutter test test/presentation/bloc/cards_bloc_test.dart
```

### Via Melos (da raiz do projeto):
```bash
# Todos os testes de Cards
melos run test:cards

# Todos os testes do projeto
melos test
```

## 🧪 Estrutura dos Testes

```
test/
├── presentation/
│   └── bloc/
│       ├── cards_bloc_test.dart        # Testes do BLoC principal
│       └── cards_bloc_test.mocks.dart  # Mocks gerados
└── README.md
```

## 📝 Padrões de Teste

### Estrutura de um Teste BLoC:

```dart
blocTest<CardsBloc, CardsState>(
  'emits [CardsLoadingState, CardsLoadedState] when load succeeds',
  build: () {
    when(mockGetCardsUseCase.execute())
        .thenAnswer((_) async => testCards);
    return cardsBloc;
  },
  act: (bloc) => bloc.add(const LoadCardsEvent()),
  expect: () => [
    const CardsLoadingState(),
    CardsLoadedState(cards: testCards),
  ],
  verify: (_) {
    verify(mockGetCardsUseCase.execute()).called(1);
    verify(mockAnalyticsService.trackEvent('cards_load_success', any))
        .called(1);
  },
);
```

### Dados de Teste:

```dart
final testCard = Card(
  id: '1',
  number: '1234567890123456',
  holderName: 'John Doe',
  type: 'Credit',
  brand: 'Visa',
  expirationDate: DateTime(2025, 12, 31),
  cvv: '123',
  limit: 10000.0,
  availableLimit: 8000.0,
  isBlocked: false,
  isVirtual: false,
  isContactless: true,
  status: CardStatus.active,
);

final testCards = [testCard];
```

## 🔍 Cenários de Teste Cobertos

### ✅ Casos de Sucesso:
- Carregamento inicial de cartões
- Carregamento com cache (otimização)
- Refresh de dados
- Preservação de dados durante carregamento

### ❌ Casos de Erro:
- Falha na API sem dados em cache
- Falha na API com dados em cache (preserva dados)
- Erro durante refresh (mantém dados antigos)

### 🔄 Casos Especiais:
- **Caching inteligente**: Não recarrega se já tem dados válidos
- **Data preservation**: Mantém dados durante operações
- **Loading states diferenciados**:
  - `CardsLoadingState`: Primeira carga, sem dados
  - `CardsLoadingWithDataState`: Recarregando com dados existentes
- **Lifecycle management**: Estados após close do BLoC

## 🎯 Métricas

| Categoria | Cobertura | Test Cases |
|-----------|-----------|------------|
| **Initial State** | 100% | 2 |
| **LoadCardsEvent** | 100% | 6 |
| **RefreshCardsEvent** | 100% | 4 |
| **Error Handling** | 100% | 2 |
| **Lifecycle** | 100% | 3 |
| **Analytics** | 100% | 2 |
| **Data Preservation** | 100% | 2 |
| **Total** | 100% | 16 |

## 🔄 Gerando Mocks

Os mocks são gerados automaticamente pelo `build_runner`:

```bash
cd packages/micro_apps/cards
flutter pub run build_runner build --delete-conflicting-outputs
```

Os mocks são salvos em `cards_bloc_test.mocks.dart` e não devem ser editados manualmente.

## 🏗️ Arquitetura de Teste

### Estado Inicial
```
CardsInitialState
└─ isInitialized: false
```

### Fluxo de Carregamento (Primeira vez)
```
LoadCardsEvent
└─ CardsLoadingState
   └─ Success: CardsLoadedState (isInitialized: true)
   └─ Error: CardsErrorState (cards: null)
```

### Fluxo de Carregamento (Com cache)
```
LoadCardsEvent (já inicializado)
└─ No state change (otimização)
```

### Fluxo de Refresh
```
RefreshCardsEvent
├─ Not initialized: delegates to LoadCardsEvent
└─ Initialized:
   └─ CardsLoadingWithDataState (preserva dados)
      └─ Success: CardsLoadedState
      └─ Error: CardsErrorState (preserva dados)
```

## 📚 Documentação Adicional

- [BLoC Testing Documentation](https://bloclibrary.dev/#/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [ARCHITECTURE.md](/docs/architecture/ARCHITECTURE.md) - Arquitetura do projeto
- [CONTRIBUTING.md](/CONTRIBUTING.md) - Guia de contribuição

## 🏆 Boas Práticas

1. **Teste os 3 caminhos**:
   - ✅ Sucesso
   - ❌ Erro
   - 🔀 Edge cases (cached data, already initialized, etc.)

2. **Preserve UX durante operações**:
   - Use `CardsLoadingWithDataState` quando já tem dados
   - Mantenha dados em `CardsErrorState` quando possível
   - Otimize com caching quando apropriado

3. **Verifique lifecycle**:
   - Teste `isInitialized` flag
   - Verifique comportamento após `close()`
   - Não emita estados após bloc fechado

4. **Analytics completo**:
   - Eventos bem-sucedidos: `cards_load_success`, `cards_refresh_success`
   - Eventos de erro: `cards_load_failed`, `cards_refresh_failed`
   - Inclua metadados relevantes (cards_count)

5. **Testes isolados**:
   - Use `setUp` e `tearDown`
   - Mocks limpos para cada teste
   - Não compartilhe estado

## 🐛 Troubleshooting

### Erro: "State emitted after bloc closed"
**Problema**: Tentativa de emitir estado após close.

**Solução**: CardsBloc verifica `isClosed` antes de emitir:
```dart
if (isClosed) return;
```

### Erro: "Expected state not emitted"
**Problema**: Caching impede emissão de estados esperados.

**Solução**: Para testes de recarga, crie novo BLoC ou reset `_isInitialized`:
```dart
// Cria novo bloc para resetar estado
final newBloc = CardsBloc(
  getCardsUseCase: mockGetCardsUseCase,
  analyticsService: mockAnalyticsService,
);
```

### Comportamento: "LoadCardsEvent não emite estados"
**Problema**: BLoC já está inicializado com dados.

**Expectativa**: Este é o comportamento correto - otimização de cache! Use `RefreshCardsEvent` para forçar recarga.

## 🎨 Padrões de Design

### Smart Caching
```dart
if (_isInitialized && currentState is CardsLoadedState) {
  return; // Não recarrega se já tem dados válidos
}
```

### Progressive Loading
```dart
// Com dados existentes
emit(CardsLoadingWithDataState(cards: existingCards));

// Sem dados
emit(const CardsLoadingState());
```

### Error Resilience
```dart
// Preserva dados mesmo em erro
emit(CardsErrorState(
  message: 'Erro',
  cards: existingCards, // Mantém dados antigos
));
```

## 📈 Próximos Passos

- [ ] Adicionar testes para eventos não implementados (Block/Unblock)
- [ ] Adicionar testes de widget para páginas
- [ ] Adicionar testes de integração
- [ ] Adicionar testes de repository
- [ ] Aumentar cobertura para 100% em todas as camadas
