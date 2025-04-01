import 'package:equatable/equatable.dart';

import '../../domain/entities/card.dart';
import '../../domain/entities/card_statement.dart';


abstract class CardsState extends Equatable {
  const CardsState();

  @override
  List<Object?> get props => [];
}


class CardsInitialState extends CardsState {
  const CardsInitialState();
}


class CardsLoadingState extends CardsState {
  const CardsLoadingState();
}


class CardsLoadingWithDataState extends CardsState {
  final List<Card>? cards;

  const CardsLoadingWithDataState({this.cards});

  @override
  List<Object?> get props => [cards];
}


class CardsLoadedState extends CardsState {
  final List<Card> cards;

  const CardsLoadedState({required this.cards});

  @override
  List<Object?> get props => [cards];
}


class CardsErrorState extends CardsState {
  final String message;
  final List<Card>? cards;

  const CardsErrorState({
    required this.message,
    this.cards,
  });

  @override
  List<Object?> get props => [message, cards];
}


class CardLoadingState extends CardsState {
  const CardLoadingState();
}


class CardLoadedState extends CardsState {
  final Card card;

  const CardLoadedState({required this.card});

  @override
  List<Object?> get props => [card];
}


class CardErrorState extends CardsState {
  final String message;

  const CardErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}


class CardBlockingState extends CardsState {
  const CardBlockingState();
}


class CardBlockedState extends CardsState {
  final Card card;

  const CardBlockedState({required this.card});

  @override
  List<Object?> get props => [card];
}


class CardUnblockingState extends CardsState {
  const CardUnblockingState();
}


class CardUnblockedState extends CardsState {
  final Card card;

  const CardUnblockedState({required this.card});

  @override
  List<Object?> get props => [card];
}


class CardStatementLoadingState extends CardsState {
  const CardStatementLoadingState();
}


class CardStatementLoadedState extends CardsState {
  final CardStatement statement;

  const CardStatementLoadedState({required this.statement});

  @override
  List<Object?> get props => [statement];
}


class CardStatementErrorState extends CardsState {
  final String message;

  const CardStatementErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}
