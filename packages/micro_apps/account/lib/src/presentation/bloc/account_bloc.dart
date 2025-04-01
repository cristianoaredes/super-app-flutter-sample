import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_account_usecase.dart';
import '../../domain/usecases/get_account_balance_usecase.dart';
import '../../domain/usecases/get_account_statement_usecase.dart';
import '../../domain/usecases/transfer_money_usecase.dart';
import 'account_event.dart';
import 'account_state.dart';


class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final GetAccountUseCase _getAccountUseCase;
  final GetAccountBalanceUseCase _getAccountBalanceUseCase;
  final GetAccountStatementUseCase _getAccountStatementUseCase;
  final TransferMoneyUseCase _transferMoneyUseCase;
  final AnalyticsService _analyticsService;
  
  AccountBloc({
    required GetAccountUseCase getAccountUseCase,
    required GetAccountBalanceUseCase getAccountBalanceUseCase,
    required GetAccountStatementUseCase getAccountStatementUseCase,
    required TransferMoneyUseCase transferMoneyUseCase,
    required AnalyticsService analyticsService,
  })  : _getAccountUseCase = getAccountUseCase,
        _getAccountBalanceUseCase = getAccountBalanceUseCase,
        _getAccountStatementUseCase = getAccountStatementUseCase,
        _transferMoneyUseCase = transferMoneyUseCase,
        _analyticsService = analyticsService,
        super(const AccountInitialState()) {
    on<LoadAccountEvent>(_onLoadAccount);
    on<LoadAccountBalanceEvent>(_onLoadAccountBalance);
    on<LoadAccountStatementEvent>(_onLoadAccountStatement);
    on<TransferMoneyEvent>(_onTransferMoney);
  }
  
  Future<void> _onLoadAccount(
    LoadAccountEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountLoadingState());
    
    try {
      _analyticsService.trackEvent(
        'account_load',
        {},
      );
      
      final account = await _getAccountUseCase.execute();
      
      emit(AccountLoadedState(account: account));
    } catch (e) {
      _analyticsService.trackError(
        'account_load_error',
        e.toString(),
      );
      
      emit(AccountErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onLoadAccountBalance(
    LoadAccountBalanceEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountBalanceLoadingState());
    
    try {
      _analyticsService.trackEvent(
        'account_balance_load',
        {},
      );
      
      final balance = await _getAccountBalanceUseCase.execute();
      
      emit(AccountBalanceLoadedState(balance: balance));
    } catch (e) {
      _analyticsService.trackError(
        'account_balance_load_error',
        e.toString(),
      );
      
      emit(AccountBalanceErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onLoadAccountStatement(
    LoadAccountStatementEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountStatementLoadingState());
    
    try {
      _analyticsService.trackEvent(
        'account_statement_load',
        {},
      );
      
      final statement = await _getAccountStatementUseCase.execute(
        startDate: event.startDate,
        endDate: event.endDate,
      );
      
      emit(AccountStatementLoadedState(statement: statement));
    } catch (e) {
      _analyticsService.trackError(
        'account_statement_load_error',
        e.toString(),
      );
      
      emit(AccountStatementErrorState(message: e.toString()));
    }
  }
  
  Future<void> _onTransferMoney(
    TransferMoneyEvent event,
    Emitter<AccountState> emit,
  ) async {
    emit(const TransferMoneyLoadingState());
    
    try {
      _analyticsService.trackEvent(
        'transfer_money',
        {
          'amount': event.amount,
          'destination_bank': event.destinationBank,
        },
      );
      
      final transaction = await _transferMoneyUseCase.execute(
        destinationAccount: event.destinationAccount,
        destinationAgency: event.destinationAgency,
        destinationBank: event.destinationBank,
        destinationName: event.destinationName,
        destinationDocument: event.destinationDocument,
        amount: event.amount,
        description: event.description,
      );
      
      emit(TransferMoneySuccessState(transaction: transaction));
    } catch (e) {
      _analyticsService.trackError(
        'transfer_money_error',
        e.toString(),
      );
      
      emit(TransferMoneyErrorState(message: e.toString()));
    }
  }
}
