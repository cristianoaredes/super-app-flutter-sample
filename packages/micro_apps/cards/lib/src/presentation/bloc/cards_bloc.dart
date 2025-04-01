import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_cards_usecase.dart';
import 'cards_event.dart';
import 'cards_state.dart';

class CardsBloc extends Bloc<CardsEvent, CardsState> {
  final GetCardsUseCase _getCardsUseCase;
  final AnalyticsService _analyticsService;
  bool _isInitialized = false;

  CardsBloc({
    required GetCardsUseCase getCardsUseCase,
    required AnalyticsService analyticsService,
  })  : _getCardsUseCase = getCardsUseCase,
        _analyticsService = analyticsService,
        super(const CardsInitialState()) {
    on<LoadCardsEvent>(_onLoadCards);
    on<RefreshCardsEvent>(_onRefreshCards);
  }

  bool get isInitialized => _isInitialized;

  @override
  Future<void> close() async {
    _isInitialized = false;
    await super.close();
  }

  Future<void> _onLoadCards(
      LoadCardsEvent event, Emitter<CardsState> emit) async {
    if (isClosed) return;

    try {
      final currentState = state;

      // Se já temos dados e já fomos inicializados, não precisamos recarregar
      if (_isInitialized && currentState is CardsLoadedState) {
        return;
      }

      // Se temos dados existentes, emite estado de loading com dados
      if (currentState is CardsLoadedState ||
          (currentState is CardsErrorState && currentState.cards != null)) {
        final existingCards = currentState is CardsLoadedState
            ? currentState.cards
            : (currentState as CardsErrorState).cards;
        emit(CardsLoadingWithDataState(cards: existingCards!));
      } else {
        emit(const CardsLoadingState());
      }

      final result = await _getCardsUseCase.execute();

      if (isClosed) return;

      _analyticsService.trackEvent('cards_load_success', {
        'cards_count': result.length,
      });

      _isInitialized = true;
      emit(CardsLoadedState(cards: result));
    } catch (e) {
      if (isClosed) return;

      _analyticsService.trackError('cards_load_failed', e.toString());

      final currentState = state;
      if (currentState is CardsLoadedState ||
          currentState is CardsLoadingWithDataState) {
        emit(CardsErrorState(
          message: 'Erro ao carregar cartões',
          cards: currentState is CardsLoadedState
              ? currentState.cards
              : (currentState as CardsLoadingWithDataState).cards,
        ));
      } else {
        emit(const CardsErrorState(message: 'Erro ao carregar cartões'));
      }
    }
  }

  Future<void> _onRefreshCards(
      RefreshCardsEvent event, Emitter<CardsState> emit) async {
    if (isClosed) return;

    try {
      final currentState = state;

      // Se não estamos inicializados, carrega normalmente
      if (!_isInitialized) {
        await _onLoadCards(const LoadCardsEvent(), emit);
        return;
      }

      // Mantém os dados atuais durante o refresh
      if (currentState is CardsLoadedState) {
        emit(CardsLoadingWithDataState(cards: currentState.cards));
      }

      final result = await _getCardsUseCase.execute();

      if (isClosed) return;

      _analyticsService.trackEvent('cards_refresh_success', {
        'cards_count': result.length,
      });

      emit(CardsLoadedState(cards: result));
    } catch (e) {
      if (isClosed) return;

      _analyticsService.trackError('cards_refresh_failed', e.toString());

      final currentState = state;
      if (currentState is CardsLoadedState ||
          currentState is CardsLoadingWithDataState) {
        emit(CardsErrorState(
          message: 'Erro ao atualizar cartões',
          cards: currentState is CardsLoadedState
              ? currentState.cards
              : (currentState as CardsLoadingWithDataState).cards,
        ));
      } else {
        emit(const CardsErrorState(message: 'Erro ao atualizar cartões'));
      }
    }
  }
}
