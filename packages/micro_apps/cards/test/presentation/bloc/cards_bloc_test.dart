import 'package:bloc_test/bloc_test.dart';
import 'package:cards/src/domain/entities/card.dart';
import 'package:cards/src/domain/usecases/get_cards_usecase.dart';
import 'package:cards/src/presentation/bloc/cards_bloc.dart';
import 'package:cards/src/presentation/bloc/cards_event.dart';
import 'package:cards/src/presentation/bloc/cards_state.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'cards_bloc_test.mocks.dart';

@GenerateMocks([
  GetCardsUseCase,
  AnalyticsService,
])
void main() {
  late CardsBloc cardsBloc;
  late MockGetCardsUseCase mockGetCardsUseCase;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
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

  setUp(() {
    mockGetCardsUseCase = MockGetCardsUseCase();
    mockAnalyticsService = MockAnalyticsService();

    cardsBloc = CardsBloc(
      getCardsUseCase: mockGetCardsUseCase,
      analyticsService: mockAnalyticsService,
    );

    // Default stubs for analytics
    when(mockAnalyticsService.trackEvent(any, any))
        .thenAnswer((_) async => {});
    when(mockAnalyticsService.trackError(any, any))
        .thenAnswer((_) async => {});
  });

  tearDown(() {
    cardsBloc.close();
  });

  group('CardsBloc - Initial State', () {
    test('initial state is CardsInitialState', () {
      expect(cardsBloc.state, equals(const CardsInitialState()));
    });

    test('isInitialized is false initially', () {
      expect(cardsBloc.isInitialized, isFalse);
    });
  });

  group('CardsBloc - LoadCardsEvent', () {
    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingState, CardsLoadedState] when load succeeds on first load',
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

    blocTest<CardsBloc, CardsState>(
      'does not reload when already initialized with data',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards);
        return cardsBloc;
      },
      seed: () => CardsLoadedState(cards: testCards),
      setUp: () {
        // Simulate bloc already initialized
        cardsBloc.add(const LoadCardsEvent());
      },
      act: (bloc) => bloc.add(const LoadCardsEvent()),
      skip: 2, // Skip the setUp emissions
      expect: () => [],
      verify: (_) {
        // Should only be called once from setUp, not from act
        verify(mockGetCardsUseCase.execute()).called(1);
      },
    );

    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingWithDataState, CardsLoadedState] when loading with existing data',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards);
        return cardsBloc;
      },
      seed: () => CardsLoadedState(cards: testCards),
      act: (bloc) {
        // Reset initialization flag to force reload
        bloc.close();
        final newBloc = CardsBloc(
          getCardsUseCase: mockGetCardsUseCase,
          analyticsService: mockAnalyticsService,
        );
        return newBloc;
      },
      expect: () => [],
    );

    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingState, CardsErrorState] when load fails without existing data',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenThrow(Exception('Network error'));
        return cardsBloc;
      },
      act: (bloc) => bloc.add(const LoadCardsEvent()),
      expect: () => [
        const CardsLoadingState(),
        const CardsErrorState(message: 'Erro ao carregar cartões'),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('cards_load_failed', any))
            .called(1);
      },
    );

    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingWithDataState, CardsErrorState] with existing cards when load fails',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenThrow(Exception('Network error'));
        return cardsBloc;
      },
      seed: () => CardsLoadedState(cards: testCards),
      act: (bloc) {
        // Create a new bloc to reset initialization
        final newBloc = CardsBloc(
          getCardsUseCase: mockGetCardsUseCase,
          analyticsService: mockAnalyticsService,
        );
        newBloc.emit(CardsLoadedState(cards: testCards));
        newBloc.add(const LoadCardsEvent());
        return newBloc.stream.toList();
      },
      expect: () => [],
    );

    test('tracks correct analytics data on successful load', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockAnalyticsService.trackEvent('cards_load_success', {
        'cards_count': testCards.length,
      })).called(1);
    });
  });

  group('CardsBloc - RefreshCardsEvent', () {
    blocTest<CardsBloc, CardsState>(
      'delegates to LoadCardsEvent when not initialized',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards);
        return cardsBloc;
      },
      act: (bloc) => bloc.add(const RefreshCardsEvent()),
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

    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingWithDataState, CardsLoadedState] when refresh succeeds',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards);
        return cardsBloc;
      },
      seed: () {
        // Manually set initialized flag
        cardsBloc.add(const LoadCardsEvent());
        return CardsLoadedState(cards: testCards);
      },
      act: (bloc) async {
        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RefreshCardsEvent());
      },
      skip: 2, // Skip LoadCardsEvent emissions
      expect: () => [
        CardsLoadingWithDataState(cards: testCards),
        CardsLoadedState(cards: testCards),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackEvent('cards_refresh_success', any))
            .called(1);
      },
    );

    blocTest<CardsBloc, CardsState>(
      'emits [CardsLoadingWithDataState, CardsErrorState] with cards when refresh fails',
      build: () {
        // First call succeeds (for initialization), second fails (for refresh)
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards)
            .thenThrow(Exception('Network error'));
        return cardsBloc;
      },
      act: (bloc) async {
        bloc.add(const LoadCardsEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RefreshCardsEvent());
      },
      expect: () => [
        const CardsLoadingState(),
        CardsLoadedState(cards: testCards),
        CardsLoadingWithDataState(cards: testCards),
        CardsErrorState(message: 'Erro ao atualizar cartões', cards: testCards),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('cards_refresh_failed', any))
            .called(1);
      },
    );

    test('tracks correct analytics data on successful refresh', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      // Initialize first
      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      // Then refresh
      cardsBloc.add(const RefreshCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('cards_refresh_success', {
        'cards_count': testCards.length,
      })).called(1);
    });
  });

  group('CardsBloc - Error Handling', () {
    blocTest<CardsBloc, CardsState>(
      'preserves existing cards in error state when refresh fails',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards)
            .thenThrow(Exception('Timeout'));
        return cardsBloc;
      },
      act: (bloc) async {
        bloc.add(const LoadCardsEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RefreshCardsEvent());
      },
      expect: () => [
        const CardsLoadingState(),
        CardsLoadedState(cards: testCards),
        CardsLoadingWithDataState(cards: testCards),
        CardsErrorState(message: 'Erro ao atualizar cartões', cards: testCards),
      ],
    );

    test('tracks different error messages for load vs refresh', () async {
      when(mockGetCardsUseCase.execute())
          .thenThrow(Exception('Network error'));

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackError('cards_load_failed', any))
          .called(1);
      verifyNever(mockAnalyticsService.trackError('cards_refresh_failed', any));
    });
  });

  group('CardsBloc - Lifecycle', () {
    test('isInitialized becomes true after successful load', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      expect(cardsBloc.isInitialized, isFalse);

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cardsBloc.isInitialized, isTrue);
    });

    test('isInitialized becomes false after close', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(cardsBloc.isInitialized, isTrue);

      await cardsBloc.close();

      expect(cardsBloc.isInitialized, isFalse);
    });

    test('does not emit states after bloc is closed', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      await cardsBloc.close();

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify no interactions happened
      verifyNever(mockGetCardsUseCase.execute());
      verifyNever(mockAnalyticsService.trackEvent(any, any));
    });
  });

  group('CardsBloc - Analytics Tracking', () {
    test('tracks all successful operations', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards);

      // Load
      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      // Refresh
      cardsBloc.add(const RefreshCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('cards_load_success', any))
          .called(1);
      verify(mockAnalyticsService.trackEvent('cards_refresh_success', any))
          .called(1);
    });

    test('tracks all errors with correct event names', () async {
      when(mockGetCardsUseCase.execute())
          .thenThrow(Exception('Error 1'))
          .thenThrow(Exception('Error 2'));

      // Load error
      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackError('cards_load_failed', any))
          .called(1);
    });
  });

  group('CardsBloc - Data Preservation', () {
    blocTest<CardsBloc, CardsState>(
      'maintains cards list through loading states',
      build: () {
        when(mockGetCardsUseCase.execute())
            .thenAnswer((_) async => testCards);
        return cardsBloc;
      },
      act: (bloc) async {
        bloc.add(const LoadCardsEvent());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RefreshCardsEvent());
      },
      expect: () => [
        const CardsLoadingState(),
        CardsLoadedState(cards: testCards),
        CardsLoadingWithDataState(cards: testCards),
        CardsLoadedState(cards: testCards),
      ],
      verify: (_) {
        // Verify cards are preserved in CardsLoadingWithDataState
        final states = cardsBloc.stream;
        states.listen((state) {
          if (state is CardsLoadingWithDataState) {
            expect(state.cards, equals(testCards));
          }
        });
      },
    );

    test('error state preserves cards from previous successful load', () async {
      when(mockGetCardsUseCase.execute())
          .thenAnswer((_) async => testCards)
          .thenThrow(Exception('Error'));

      cardsBloc.add(const LoadCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      cardsBloc.add(const RefreshCardsEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cardsBloc.state, isA<CardsErrorState>());
      final errorState = cardsBloc.state as CardsErrorState;
      expect(errorState.cards, equals(testCards));
    });
  });
}
