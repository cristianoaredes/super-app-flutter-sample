import 'package:equatable/equatable.dart';

abstract class CardDetailsEvent extends Equatable {
  const CardDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadCardDetailsEvent extends CardDetailsEvent {
  final String cardId;

  const LoadCardDetailsEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}

class LoadCardStatementEvent extends CardDetailsEvent {
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

class BlockCardEvent extends CardDetailsEvent {
  final String cardId;

  const BlockCardEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}

class UnblockCardEvent extends CardDetailsEvent {
  final String cardId;

  const UnblockCardEvent({required this.cardId});

  @override
  List<Object?> get props => [cardId];
}
