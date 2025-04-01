import 'package:equatable/equatable.dart';

import '../../domain/entities/card.dart';
import '../../domain/entities/card_statement.dart';

abstract class CardDetailsState extends Equatable {
  const CardDetailsState();

  @override
  List<Object?> get props => [];
}

class CardDetailsInitialState extends CardDetailsState {
  const CardDetailsInitialState();
}

class CardDetailsLoadingState extends CardDetailsState {
  const CardDetailsLoadingState();
}

class CardDetailsLoadedState extends CardDetailsState {
  final Card card;

  const CardDetailsLoadedState({required this.card});

  @override
  List<Object?> get props => [card];
}

class CardDetailsErrorState extends CardDetailsState {
  final String message;

  const CardDetailsErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

class CardStatementLoadingState extends CardDetailsState {
  const CardStatementLoadingState();
}

class CardStatementLoadedState extends CardDetailsState {
  final CardStatement statement;

  const CardStatementLoadedState({required this.statement});

  @override
  List<Object?> get props => [statement];
}

class CardStatementErrorState extends CardDetailsState {
  final String message;

  const CardStatementErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

class CardBlockingState extends CardDetailsState {
  const CardBlockingState();
}

class CardBlockedState extends CardDetailsState {
  final Card card;

  const CardBlockedState({required this.card});

  @override
  List<Object?> get props => [card];
}

class CardUnblockingState extends CardDetailsState {
  const CardUnblockingState();
}

class CardUnblockedState extends CardDetailsState {
  final Card card;

  const CardUnblockedState({required this.card});

  @override
  List<Object?> get props => [card];
}
