import 'package:equatable/equatable.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/account_balance.dart';
import '../../domain/entities/account_statement.dart';
import '../../domain/entities/transaction.dart';


abstract class AccountState extends Equatable {
  const AccountState();
  
  @override
  List<Object?> get props => [];
}


class AccountInitialState extends AccountState {
  const AccountInitialState();
}




class AccountLoadingState extends AccountState {
  const AccountLoadingState();
}


class AccountLoadedState extends AccountState {
  final Account account;
  
  const AccountLoadedState({required this.account});
  
  @override
  List<Object?> get props => [account];
}


class AccountErrorState extends AccountState {
  final String message;
  
  const AccountErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}




class AccountBalanceLoadingState extends AccountState {
  const AccountBalanceLoadingState();
}


class AccountBalanceLoadedState extends AccountState {
  final AccountBalance balance;
  
  const AccountBalanceLoadedState({required this.balance});
  
  @override
  List<Object?> get props => [balance];
}


class AccountBalanceErrorState extends AccountState {
  final String message;
  
  const AccountBalanceErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}




class AccountStatementLoadingState extends AccountState {
  const AccountStatementLoadingState();
}


class AccountStatementLoadedState extends AccountState {
  final AccountStatement statement;
  
  const AccountStatementLoadedState({required this.statement});
  
  @override
  List<Object?> get props => [statement];
}


class AccountStatementErrorState extends AccountState {
  final String message;
  
  const AccountStatementErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}




class TransferMoneyLoadingState extends AccountState {
  const TransferMoneyLoadingState();
}


class TransferMoneySuccessState extends AccountState {
  final Transaction transaction;
  
  const TransferMoneySuccessState({required this.transaction});
  
  @override
  List<Object?> get props => [transaction];
}


class TransferMoneyErrorState extends AccountState {
  final String message;
  
  const TransferMoneyErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}
