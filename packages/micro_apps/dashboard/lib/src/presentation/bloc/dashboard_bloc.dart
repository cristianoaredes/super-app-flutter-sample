import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/account_summary.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/entities/quick_action.dart';
import '../../domain/usecases/get_account_summary_usecase.dart';
import '../../domain/usecases/get_transaction_summary_usecase.dart';
import '../../domain/usecases/get_quick_actions_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';


class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetAccountSummaryUseCase _getAccountSummaryUseCase;
  final GetTransactionSummaryUseCase _getTransactionSummaryUseCase;
  final GetQuickActionsUseCase _getQuickActionsUseCase;
  final AnalyticsService _analyticsService;

  DashboardBloc({
    required GetAccountSummaryUseCase getAccountSummaryUseCase,
    required GetTransactionSummaryUseCase getTransactionSummaryUseCase,
    required GetQuickActionsUseCase getQuickActionsUseCase,
    required AnalyticsService analyticsService,
  })  : _getAccountSummaryUseCase = getAccountSummaryUseCase,
        _getTransactionSummaryUseCase = getTransactionSummaryUseCase,
        _getQuickActionsUseCase = getQuickActionsUseCase,
        _analyticsService = analyticsService,
        super(const DashboardInitialState()) {
    on<LoadDashboardEvent>(_onLoadDashboard);
    on<RefreshDashboardEvent>(_onRefreshDashboard);
    on<LoadTransactionEvent>(_onLoadTransaction);
  }

  Future<void> _onLoadDashboard(
    LoadDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoadingState());

    try {
      try {
        _analyticsService.trackEvent(
          'dashboard_load',
          {},
        );
      } catch (e) {
        
      }

      
      final accountSummaryFuture = _getAccountSummaryUseCase.execute();
      final transactionSummaryFuture = _getTransactionSummaryUseCase.execute();
      final quickActionsFuture = _getQuickActionsUseCase.execute();

      
      final results = await Future.wait([
        accountSummaryFuture,
        transactionSummaryFuture,
        quickActionsFuture,
      ]);

      final accountSummary = results[0] as AccountSummary;
      final transactionSummary = results[1] as TransactionSummary;
      final quickActions = results[2] as List<QuickAction>;

      emit(DashboardLoadedState(
        accountSummary: accountSummary,
        transactionSummary: transactionSummary,
        quickActions: quickActions,
      ));
    } catch (e) {
      try {
        _analyticsService.trackError(
          'dashboard_load_error',
          e.toString(),
        );
      } catch (analyticsError) {
        
      }

      emit(DashboardErrorState(
        message: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboardEvent event,
    Emitter<DashboardState> emit,
  ) async {
    
    if (state is DashboardLoadedState) {
      final currentState = state as DashboardLoadedState;
      emit(DashboardLoadingWithDataState(
        accountSummary: currentState.accountSummary,
        transactionSummary: currentState.transactionSummary,
        quickActions: currentState.quickActions,
      ));
    } else {
      emit(const DashboardLoadingState());
    }

    try {
      try {
        _analyticsService.trackEvent(
          'dashboard_refresh',
          {},
        );
      } catch (e) {
        
      }

      
      final accountSummaryFuture = _getAccountSummaryUseCase.execute();
      final transactionSummaryFuture = _getTransactionSummaryUseCase.execute();
      final quickActionsFuture = _getQuickActionsUseCase.execute();

      
      final results = await Future.wait([
        accountSummaryFuture,
        transactionSummaryFuture,
        quickActionsFuture,
      ]);

      final accountSummary = results[0] as AccountSummary;
      final transactionSummary = results[1] as TransactionSummary;
      final quickActions = results[2] as List<QuickAction>;

      emit(DashboardLoadedState(
        accountSummary: accountSummary,
        transactionSummary: transactionSummary,
        quickActions: quickActions,
      ));
    } catch (e) {
      try {
        _analyticsService.trackError(
          'dashboard_refresh_error',
          e.toString(),
        );
      } catch (analyticsError) {
        
      }

      
      if (state is DashboardLoadingWithDataState) {
        final currentState = state as DashboardLoadingWithDataState;
        emit(DashboardErrorState(
          message: e.toString(),
          accountSummary: currentState.accountSummary,
          transactionSummary: currentState.transactionSummary,
          quickActions: currentState.quickActions,
        ));
      } else {
        emit(DashboardErrorState(
          message: e.toString(),
        ));
      }
    }
  }

  Future<void> _onLoadTransaction(
    LoadTransactionEvent event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const TransactionLoadingState());

    try {
      try {
        _analyticsService.trackEvent(
          'transaction_load',
          {
            'transaction_id': event.transactionId,
          },
        );
      } catch (e) {
        
      }

      final transaction =
          await _getTransactionSummaryUseCase.getTransactionById(
        event.transactionId,
      );

      if (transaction != null) {
        emit(TransactionLoadedState(
          transaction: transaction,
        ));
      } else {
        emit(const TransactionErrorState(
          message: 'Transação não encontrada',
        ));
      }
    } catch (e) {
      try {
        _analyticsService.trackError(
          'transaction_load_error',
          e.toString(),
        );
      } catch (analyticsError) {
        
      }

      emit(TransactionErrorState(
        message: e.toString(),
      ));
    }
  }
}
