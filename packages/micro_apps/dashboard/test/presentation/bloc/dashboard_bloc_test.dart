import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:dashboard/src/domain/entities/account_summary.dart';
import 'package:dashboard/src/domain/entities/quick_action.dart';
import 'package:dashboard/src/domain/entities/transaction_summary.dart';
import 'package:dashboard/src/domain/usecases/get_account_summary_usecase.dart';
import 'package:dashboard/src/domain/usecases/get_quick_actions_usecase.dart';
import 'package:dashboard/src/domain/usecases/get_transaction_summary_usecase.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_bloc.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_event.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'dashboard_bloc_test.mocks.dart';

/// Gera os mocks necessários para os testes
/// Execute: dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  GetAccountSummaryUseCase,
  GetTransactionSummaryUseCase,
  GetQuickActionsUseCase,
  AnalyticsService,
])
void main() {
  late DashboardBloc dashboardBloc;
  late MockGetAccountSummaryUseCase mockGetAccountSummaryUseCase;
  late MockGetTransactionSummaryUseCase mockGetTransactionSummaryUseCase;
  late MockGetQuickActionsUseCase mockGetQuickActionsUseCase;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
  final testAccountSummary = AccountSummary(
    accountId: 'acc-123',
    accountNumber: '12345-6',
    agency: '0001',
    balance: 5000.0,
    income: 10000.0,
    expenses: 5000.0,
    savings: 2000.0,
    investments: 3000.0,
    lastUpdate: DateTime(2024, 1, 1),
  );

  final testTransaction = Transaction(
    id: 'txn-123',
    title: 'Test Transaction',
    description: 'Test description',
    amount: 100.0,
    date: DateTime(2024, 1, 1),
    category: 'Food',
    type: TransactionType.expense,
  );

  final testTransactionSummary = TransactionSummary(
    recentTransactions: [testTransaction],
    categoryDistribution: {'Food': 100.0},
    monthlyExpenses: [],
  );

  final testQuickActions = [
    const QuickAction(
      id: 'pix',
      title: 'Pix',
      description: 'Transferir com Pix',
      icon: Icons.pix,
      route: '/pix',
    ),
    const QuickAction(
      id: 'payment',
      title: 'Pagamento',
      description: 'Pagar conta',
      icon: Icons.payment,
      route: '/payments',
    ),
  ];

  setUp(() {
    mockGetAccountSummaryUseCase = MockGetAccountSummaryUseCase();
    mockGetTransactionSummaryUseCase = MockGetTransactionSummaryUseCase();
    mockGetQuickActionsUseCase = MockGetQuickActionsUseCase();
    mockAnalyticsService = MockAnalyticsService();

    dashboardBloc = DashboardBloc(
      getAccountSummaryUseCase: mockGetAccountSummaryUseCase,
      getTransactionSummaryUseCase: mockGetTransactionSummaryUseCase,
      getQuickActionsUseCase: mockGetQuickActionsUseCase,
      analyticsService: mockAnalyticsService,
    );
  });

  tearDown(() {
    dashboardBloc.close();
  });

  group('DashboardBloc', () {
    test('initial state should be DashboardInitialState', () {
      expect(dashboardBloc.state, equals(const DashboardInitialState()));
    });

    group('LoadDashboardEvent', () {
      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingState, DashboardLoadedState] when all data loads successfully',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenAnswer((_) async => testAccountSummary);
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        act: (bloc) => bloc.add(const LoadDashboardEvent()),
        expect: () => [
          const DashboardLoadingState(),
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ],
        verify: (_) {
          verify(mockGetAccountSummaryUseCase.execute()).called(1);
          verify(mockGetTransactionSummaryUseCase.execute()).called(1);
          verify(mockGetQuickActionsUseCase.execute()).called(1);
          verify(mockAnalyticsService.trackEvent('dashboard_load', {}))
              .called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingState, DashboardErrorState] when loading fails',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenThrow(Exception('Failed to load account'));
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        act: (bloc) => bloc.add(const LoadDashboardEvent()),
        expect: () => [
          const DashboardLoadingState(),
          const DashboardErrorState(
            message: 'Exception: Failed to load account',
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'dashboard_load_error',
            'Exception: Failed to load account',
          )).called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'handles analytics errors gracefully and continues loading',
        build: () {
          when(mockAnalyticsService.trackEvent(any, any))
              .thenThrow(Exception('Analytics error'));
          when(mockGetAccountSummaryUseCase.execute())
              .thenAnswer((_) async => testAccountSummary);
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        act: (bloc) => bloc.add(const LoadDashboardEvent()),
        expect: () => [
          const DashboardLoadingState(),
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ],
        verify: (_) {
          // Should still call use cases even if analytics fails
          verify(mockGetAccountSummaryUseCase.execute()).called(1);
          verify(mockGetTransactionSummaryUseCase.execute()).called(1);
          verify(mockGetQuickActionsUseCase.execute()).called(1);
        },
      );
    });

    group('RefreshDashboardEvent', () {
      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingState, DashboardLoadedState] when refreshing from initial state',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenAnswer((_) async => testAccountSummary);
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        act: (bloc) => bloc.add(const RefreshDashboardEvent()),
        expect: () => [
          const DashboardLoadingState(),
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackEvent('dashboard_refresh', {}))
              .called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingWithDataState, DashboardLoadedState] when refreshing from loaded state',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenAnswer((_) async => testAccountSummary);
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        seed: () => DashboardLoadedState(
          accountSummary: testAccountSummary,
          transactionSummary: testTransactionSummary,
          quickActions: testQuickActions,
        ),
        act: (bloc) => bloc.add(const RefreshDashboardEvent()),
        expect: () => [
          DashboardLoadingWithDataState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingWithDataState, DashboardErrorState] with cached data when refresh fails',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenThrow(Exception('Network error'));
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        seed: () => DashboardLoadedState(
          accountSummary: testAccountSummary,
          transactionSummary: testTransactionSummary,
          quickActions: testQuickActions,
        ),
        act: (bloc) => bloc.add(const RefreshDashboardEvent()),
        expect: () => [
          DashboardLoadingWithDataState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
          DashboardErrorState(
            message: 'Exception: Network error',
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'dashboard_refresh_error',
            'Exception: Network error',
          )).called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [DashboardLoadingState, DashboardErrorState] without cached data when refresh fails from initial state',
        build: () {
          when(mockGetAccountSummaryUseCase.execute())
              .thenThrow(Exception('Network error'));
          when(mockGetTransactionSummaryUseCase.execute())
              .thenAnswer((_) async => testTransactionSummary);
          when(mockGetQuickActionsUseCase.execute())
              .thenAnswer((_) async => testQuickActions);
          return dashboardBloc;
        },
        act: (bloc) => bloc.add(const RefreshDashboardEvent()),
        expect: () => [
          const DashboardLoadingState(),
          const DashboardErrorState(
            message: 'Exception: Network error',
          ),
        ],
      );
    });

    group('LoadTransactionEvent', () {
      const testTransactionId = 'txn-123';

      blocTest<DashboardBloc, DashboardState>(
        'emits [TransactionLoadingState, TransactionLoadedState] when transaction loads successfully',
        build: () {
          when(mockGetTransactionSummaryUseCase.getTransactionById(any))
              .thenAnswer((_) async => testTransaction);
          return dashboardBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadTransactionEvent(transactionId: testTransactionId)),
        expect: () => [
          const TransactionLoadingState(),
          TransactionLoadedState(transaction: testTransaction),
        ],
        verify: (_) {
          verify(mockGetTransactionSummaryUseCase.getTransactionById(
            testTransactionId,
          )).called(1);
          verify(mockAnalyticsService.trackEvent(
            'transaction_load',
            {'transaction_id': testTransactionId},
          )).called(1);
        },
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [TransactionLoadingState, TransactionErrorState] when transaction is not found',
        build: () {
          when(mockGetTransactionSummaryUseCase.getTransactionById(any))
              .thenAnswer((_) async => null);
          return dashboardBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadTransactionEvent(transactionId: testTransactionId)),
        expect: () => [
          const TransactionLoadingState(),
          const TransactionErrorState(message: 'Transação não encontrada'),
        ],
      );

      blocTest<DashboardBloc, DashboardState>(
        'emits [TransactionLoadingState, TransactionErrorState] when loading fails',
        build: () {
          when(mockGetTransactionSummaryUseCase.getTransactionById(any))
              .thenThrow(Exception('Database error'));
          return dashboardBloc;
        },
        act: (bloc) =>
            bloc.add(const LoadTransactionEvent(transactionId: testTransactionId)),
        expect: () => [
          const TransactionLoadingState(),
          const TransactionErrorState(message: 'Exception: Database error'),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'transaction_load_error',
            'Exception: Database error',
          )).called(1);
        },
      );
    });
  });
}
