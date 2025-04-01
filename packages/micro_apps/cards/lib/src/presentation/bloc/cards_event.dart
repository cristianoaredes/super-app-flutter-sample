import 'package:equatable/equatable.dart';


abstract class CardsEvent extends Equatable {
  const CardsEvent();

  @override
  List<Object?> get props => [];
}


class LoadCardsEvent extends CardsEvent {
  const LoadCardsEvent();
}


class RefreshCardsEvent extends CardsEvent {
  const RefreshCardsEvent();
}


class LoadCardEvent extends CardsEvent {
  final String cardId;

  const LoadCardEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}


class LoadCardStatementEvent extends CardsEvent {
  final String cardId;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadCardStatementEvent({
    required this.cardId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [cardId, startDate, endDate];
}


class BlockCardEvent extends CardsEvent {
  final String cardId;

  const BlockCardEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}


class UnblockCardEvent extends CardsEvent {
  final String cardId;

  const UnblockCardEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}
