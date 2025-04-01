import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_cards_usecase.dart';
import '../../domain/usecases/get_card_statement_usecase.dart';
import '../../domain/usecases/block_card_usecase.dart';
import '../../domain/usecases/unblock_card_usecase.dart';
import '../../domain/entities/get_card_statement_params.dart';
import 'card_details_event.dart';
import 'card_details_state.dart';

class CardDetailsBloc extends Bloc<CardDetailsEvent, CardDetailsState> {
  final GetCardsUseCase _getCardsUseCase;
  final GetCardStatementUseCase _getCardStatementUseCase;
  final BlockCardUseCase _blockCardUseCase;
  final UnblockCardUseCase _unblockCardUseCase;
  final AnalyticsService _analyticsService;

  CardDetailsBloc({
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
        super(CardDetailsInitialState()) {
    on<LoadCardDetailsEvent>(_onLoadCardDetails);
    on<LoadCardStatementEvent>(_onLoadCardStatement);
    on<BlockCardEvent>(_onBlockCard);
    on<UnblockCardEvent>(_onUnblockCard);
  }

  Future<void> _onLoadCardDetails(
    LoadCardDetailsEvent event,
    Emitter<CardDetailsState> emit,
  ) async {
    try {
      emit(CardDetailsLoadingState());

      final result = await _getCardsUseCase.execute();
      final card = result.firstWhere((card) => card.id == event.cardId);

      emit(CardDetailsLoadedState(card: card));

      _analyticsService.trackEvent(
        'card_details_loaded',
        {'card_id': event.cardId},
      );
    } catch (error) {
      emit(CardDetailsErrorState(message: error.toString()));
      _analyticsService.trackError(
        'card_details_error',
        error.toString(),
      );
    }
  }

  Future<void> _onLoadCardStatement(
    LoadCardStatementEvent event,
    Emitter<CardDetailsState> emit,
  ) async {
    try {
      emit(CardStatementLoadingState());

      final statement = await _getCardStatementUseCase.execute(
        GetCardStatementParams(
          cardId: event.cardId,
          startDate: event.startDate ??
              DateTime.now().subtract(const Duration(days: 30)),
          endDate: event.endDate ?? DateTime.now(),
        ),
      );

      emit(CardStatementLoadedState(statement: statement));

      _analyticsService.trackEvent(
        'card_statement_loaded',
        {'card_id': event.cardId},
      );
    } catch (error) {
      emit(CardStatementErrorState(message: error.toString()));
      _analyticsService.trackError(
        'card_statement_error',
        error.toString(),
      );
    }
  }

  Future<void> _onBlockCard(
    BlockCardEvent event,
    Emitter<CardDetailsState> emit,
  ) async {
    try {
      emit(CardBlockingState());

      final card = await _blockCardUseCase.execute(event.cardId);

      emit(CardBlockedState(card: card));

      _analyticsService.trackEvent(
        'card_blocked',
        {'card_id': event.cardId},
      );
    } catch (error) {
      emit(CardDetailsErrorState(message: error.toString()));
      _analyticsService.trackError(
        'card_block_error',
        error.toString(),
      );
    }
  }

  Future<void> _onUnblockCard(
    UnblockCardEvent event,
    Emitter<CardDetailsState> emit,
  ) async {
    try {
      emit(CardUnblockingState());

      final card = await _unblockCardUseCase.execute(event.cardId);

      emit(CardUnblockedState(card: card));

      _analyticsService.trackEvent(
        'card_unblocked',
        {'card_id': event.cardId},
      );
    } catch (error) {
      emit(CardDetailsErrorState(message: error.toString()));
      _analyticsService.trackError(
        'card_unblock_error',
        error.toString(),
      );
    }
  }
}
