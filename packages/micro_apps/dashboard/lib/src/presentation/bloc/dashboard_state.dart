import 'package:equatable/equatable.dart';

import '../../domain/entities/account_summary.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/entities/quick_action.dart';


abstract class DashboardState extends Equatable {
  const DashboardState();
  
  @override
  List<Object?> get props => [];
}


class DashboardInitialState extends DashboardState {
  const DashboardInitialState();
}


class DashboardLoadingState extends DashboardState {
  const DashboardLoadingState();
}


class DashboardLoadingWithDataState extends DashboardState {
  final AccountSummary? accountSummary;
  final TransactionSummary? transactionSummary;
  final List<QuickAction>? quickActions;
  
  const DashboardLoadingWithDataState({
    this.accountSummary,
    this.transactionSummary,
    this.quickActions,
  });
  
  @override
  List<Object?> get props => [accountSummary, transactionSummary, quickActions];
}


class DashboardLoadedState extends DashboardState {
  final AccountSummary accountSummary;
  final TransactionSummary transactionSummary;
  final List<QuickAction> quickActions;
  
  const DashboardLoadedState({
    required this.accountSummary,
    required this.transactionSummary,
    required this.quickActions,
  });
  
  @override
  List<Object?> get props => [accountSummary, transactionSummary, quickActions];
}


class DashboardErrorState extends DashboardState {
  final String message;
  final AccountSummary? accountSummary;
  final TransactionSummary? transactionSummary;
  final List<QuickAction>? quickActions;
  
  const DashboardErrorState({
    required this.message,
    this.accountSummary,
    this.transactionSummary,
    this.quickActions,
  });
  
  @override
  List<Object?> get props => [message, accountSummary, transactionSummary, quickActions];
}


class TransactionLoadingState extends DashboardState {
  const TransactionLoadingState();
}


class TransactionLoadedState extends DashboardState {
  final Transaction transaction;
  
  const TransactionLoadedState({required this.transaction});
  
  @override
  List<Object?> get props => [transaction];
}


class TransactionErrorState extends DashboardState {
  final String message;
  
  const TransactionErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}
