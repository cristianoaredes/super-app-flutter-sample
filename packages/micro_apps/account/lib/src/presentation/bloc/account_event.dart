import 'package:equatable/equatable.dart';


abstract class AccountEvent extends Equatable {
  const AccountEvent();
  
  @override
  List<Object?> get props => [];
}


class LoadAccountEvent extends AccountEvent {
  const LoadAccountEvent();
}


class LoadAccountBalanceEvent extends AccountEvent {
  const LoadAccountBalanceEvent();
}


class LoadAccountStatementEvent extends AccountEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  
  const LoadAccountStatementEvent({
    this.startDate,
    this.endDate,
  });
  
  @override
  List<Object?> get props => [startDate, endDate];
}


class TransferMoneyEvent extends AccountEvent {
  final String destinationAccount;
  final String destinationAgency;
  final String destinationBank;
  final String destinationName;
  final String destinationDocument;
  final double amount;
  final String? description;
  
  const TransferMoneyEvent({
    required this.destinationAccount,
    required this.destinationAgency,
    required this.destinationBank,
    required this.destinationName,
    required this.destinationDocument,
    required this.amount,
    this.description,
  });
  
  @override
  List<Object?> get props => [
    destinationAccount,
    destinationAgency,
    destinationBank,
    destinationName,
    destinationDocument,
    amount,
    description,
  ];
}
