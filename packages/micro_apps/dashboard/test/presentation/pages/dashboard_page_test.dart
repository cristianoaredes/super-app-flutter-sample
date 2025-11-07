import 'package:bloc_test/bloc_test.dart';
import 'package:dashboard/src/domain/entities/account_summary.dart';
import 'package:dashboard/src/domain/entities/quick_action.dart';
import 'package:dashboard/src/domain/entities/transaction_summary.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_bloc.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_event.dart';
import 'package:dashboard/src/presentation/bloc/dashboard_state.dart';
import 'package:dashboard/src/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockDashboardBloc mockDashboardBloc;

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
    mockDashboardBloc = MockDashboardBloc();

    // Setup default state and stream
    when(mockDashboardBloc.state).thenReturn(const DashboardInitialState());
    when(mockDashboardBloc.stream)
        .thenAnswer((_) => const Stream<DashboardState>.empty());
  });

  Widget createDashboardPage() {
    return MaterialApp(
      home: BlocProvider<DashboardBloc>(
        create: (_) => mockDashboardBloc,
        child: const DashboardPage(),
      ),
    );
  }

  group('DashboardPage Widget Tests', () {
    testWidgets('should render AppBar with title and refresh button',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createDashboardPage());

      // Assert
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('should dispatch LoadDashboardEvent on init',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createDashboardPage());

      // Assert
      verify(mockDashboardBloc.add(const LoadDashboardEvent())).called(1);
    });

    testWidgets('should show loading indicator when state is DashboardLoadingState',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([const DashboardLoadingState()]),
        initialState: const DashboardInitialState(),
      );

      // Act
      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show loading indicator when state is DashboardInitialState',
        (WidgetTester tester) async {
      // Arrange
      when(mockDashboardBloc.state).thenReturn(const DashboardInitialState());

      // Act
      await tester.pumpWidget(createDashboardPage());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display dashboard data when state is DashboardLoadedState',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ]),
        initialState: const DashboardInitialState(),
      );

      // Act
      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Assert - Check that dashboard widgets are rendered
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should dispatch RefreshDashboardEvent when refresh button is tapped',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ]),
        initialState: const DashboardInitialState(),
      );

      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Clear the call count from LoadDashboardEvent
      clearInteractions(mockDashboardBloc);

      // Act - Tap the refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Assert
      verify(mockDashboardBloc.add(const RefreshDashboardEvent())).called(1);
    });

    testWidgets('should show error message when state is DashboardErrorState',
        (WidgetTester tester) async {
      // Arrange
      const errorMessage = 'Failed to load dashboard';
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          const DashboardErrorState(message: errorMessage),
        ]),
        initialState: const DashboardInitialState(),
      );

      // Act
      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Assert - Should show error message
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('should show cached data with error when DashboardErrorState has data',
        (WidgetTester tester) async {
      // Arrange
      const errorMessage = 'Failed to refresh';
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          DashboardErrorState(
            message: errorMessage,
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ]),
        initialState: const DashboardInitialState(),
      );

      // Act
      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Assert - Should show both error snackbar and cached data
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // Error snackbar should appear
      await tester.pump();
      expect(find.text(errorMessage), findsOneWidget);
    });

    testWidgets('should allow pull-to-refresh gesture',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          DashboardLoadedState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ]),
        initialState: const DashboardInitialState(),
      );

      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Clear the call count from LoadDashboardEvent
      clearInteractions(mockDashboardBloc);

      // Act - Perform pull-to-refresh gesture
      await tester.drag(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
      );
      await tester.pump();

      // Assert
      verify(mockDashboardBloc.add(const RefreshDashboardEvent())).called(1);
    });

    testWidgets('should show loading indicator over data when DashboardLoadingWithDataState',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          DashboardLoadingWithDataState(
            accountSummary: testAccountSummary,
            transactionSummary: testTransactionSummary,
            quickActions: testQuickActions,
          ),
        ]),
        initialState: const DashboardInitialState(),
      );

      // Act
      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Assert - Should show both data and loading indicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should retry loading when "Tentar novamente" is tapped after error',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockDashboardBloc,
        Stream.fromIterable([
          const DashboardErrorState(message: 'Network error'),
        ]),
        initialState: const DashboardInitialState(),
      );

      await tester.pumpWidget(createDashboardPage());
      await tester.pump(); // Trigger the stream

      // Clear the call count from LoadDashboardEvent
      clearInteractions(mockDashboardBloc);

      // Act - Tap "Tentar novamente"
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();

      // Assert
      verify(mockDashboardBloc.add(const LoadDashboardEvent())).called(1);
    });
  });
}

/// Mock DashboardBloc for testing
class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}
