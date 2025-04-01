import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_cards_usecase.dart';
import '../../domain/usecases/get_card_statement_usecase.dart';
import '../../domain/usecases/block_card_usecase.dart';
import '../../domain/usecases/unblock_card_usecase.dart';
import 'cards_event.dart';
import 'cards_state.dart';


class CardsBloc extends Bloc<CardsEvent, CardsState> {
  final GetCardsUseCase _getCardsUseCase;
  final GetCardStatementUseCase _getCardStatementUseCase;
  final BlockCardUseCase _blockCardUseCase;
  final UnblockCardUseCase _unblockCardUseCase;
  final AnalyticsService _analyticsService;

  CardsBloc({
    required GetCardsUseCase getCardsUseCase,
    required GetCardStatementUseCase getCardStatementUseCase,
    required BlockCardUseCase blockCardUseCase,
    required UnblockCardUseCase unblockCardUseCase,
    required AnalyticsService analyticsService,
  })  : _getCardsUseCase = getCardsUseCase,
        _getCardStatementUseCase = getCardStatementUseCase,
        _blockCardUseCase = blockCardUseCase,
        _unblockCardUseCase = unblockCardUseCase,
        _analyticsService = analyticsService,
        super(const CardsInitialState()) {
    on<LoadCardsEvent>(_onLoadCards);
    on<RefreshCardsEvent>(_onRefreshCards);
    on<LoadCardEvent>(_onLoadCard);
    on<LoadCardStatementEvent>(_onLoadCardStatement);
    on<BlockCardEvent>(_onBlockCard);
    on<UnblockCardEvent>(_onUnblockCard);
  }

  Future<void> _onLoadCards(
    LoadCardsEvent event,
    Emitter<CardsState> emit,
  ) async {
    emit(const CardsLoadingState());

    try {
      _analyticsService.trackEvent(
        'cards_load',
        {},
      );

      final cards = await _getCardsUseCase.execute();

      emit(CardsLoadedState(cards: cards));
    } catch (e) {
      _analyticsService.trackError(
        'cards_load_error',
        e.toString(),
      );

      emit(CardsErrorState(message: e.toString()));
    }
  }

  Future<void> _onRefreshCards(
    RefreshCardsEvent event,
    Emitter<CardsState> emit,
  ) async {
    
    if (state is CardsLoadedState) {
      final currentState = state as CardsLoadedState;
      emit(CardsLoadingWithDataState(cards: currentState.cards));
    } else {
      emit(const CardsLoadingState());
    }

    try {
      _analyticsService.trackEvent(
        'cards_refresh',
        {},
      );

      final cards = await _getCardsUseCase.execute();

      emit(CardsLoadedState(cards: cards));
    } catch (e) {
      _analyticsService.trackError(
        'cards_refresh_error',
        e.toString(),
      );

      
      if (state is CardsLoadingWithDataState) {
        final currentState = state as CardsLoadingWithDataState;
        emit(CardsErrorState(
          message: e.toString(),
          cards: currentState.cards,
        ));
      } else {
        emit(CardsErrorState(message: e.toString()));
      }
    }
  }

  Future<void> _onLoadCard(
    LoadCardEvent event,
    Emitter<CardsState> emit,
  ) async {
    emit(const CardLoadingState());

    try {
      _analyticsService.trackEvent(
        'card_load',
        {
          'card_id': event.cardId,
        },
      );

      final card = await _getCardsUseCase.getCardById(event.cardId);

      if (card != null) {
        emit(CardLoadedState(card: card));
      } else {
        emit(const CardErrorState(message: 'Cartão não encontrado'));
      }
    } catch (e) {
      _analyticsService.trackError(
        'card_load_error',
        e.toString(),
      );

      emit(CardErrorState(message: e.toString()));
    }
  }

  Future<void> _onLoadCardStatement(
    LoadCardStatementEvent event,
    Emitter<CardsState> emit,
  ) async {
    emit(const CardStatementLoadingState());

    try {
      _analyticsService.trackEvent(
        'card_statement_load',
        {
          'card_id': event.cardId,
        },
      );

      final statement = await _getCardStatementUseCase.execute(
        event.cardId,
        startDate: event.startDate,
        endDate: event.endDate,
      );

      emit(CardStatementLoadedState(statement: statement));
    } catch (e) {
      _analyticsService.trackError(
        'card_statement_load_error',
        e.toString(),
      );

      emit(CardStatementErrorState(message: e.toString()));
    }
  }

  Future<void> _onBlockCard(
    BlockCardEvent event,
    Emitter<CardsState> emit,
  ) async {
    emit(const CardBlockingState());

    try {
      _analyticsService.trackEvent(
        'card_block',
        {
          'card_id': event.cardId,
        },
      );

      final card = await _blockCardUseCase.execute(event.cardId);

      emit(CardBlockedState(card: card));
    } catch (e) {
      _analyticsService.trackError(
        'card_block_error',
        e.toString(),
      );

      emit(CardErrorState(message: e.toString()));
    }
  }

  Future<void> _onUnblockCard(
    UnblockCardEvent event,
    Emitter<CardsState> emit,
  ) async {
    emit(const CardUnblockingState());

    try {
      _analyticsService.trackEvent(
        'card_unblock',
        {
          'card_id': event.cardId,
        },
      );

      final card = await _unblockCardUseCase.execute(event.cardId);

      emit(CardUnblockedState(card: card));
    } catch (e) {
      _analyticsService.trackError(
        'card_unblock_error',
        e.toString(),
      );

      emit(CardErrorState(message: e.toString()));
    }
  }
}
