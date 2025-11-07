import 'package:account/src/domain/entities/account.dart';
import 'package:account/src/domain/entities/account_balance.dart';
import 'package:account/src/domain/entities/account_statement.dart';
import 'package:account/src/domain/entities/transaction.dart';
import 'package:account/src/domain/usecases/get_account_balance_usecase.dart';
import 'package:account/src/domain/usecases/get_account_statement_usecase.dart';
import 'package:account/src/domain/usecases/get_account_usecase.dart';
import 'package:account/src/domain/usecases/transfer_money_usecase.dart';
import 'package:account/src/presentation/bloc/account_bloc.dart';
import 'package:account/src/presentation/bloc/account_event.dart';
import 'package:account/src/presentation/bloc/account_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'account_bloc_test.mocks.dart';

@GenerateMocks([
  GetAccountUseCase,
  GetAccountBalanceUseCase,
  GetAccountStatementUseCase,
  TransferMoneyUseCase,
  AnalyticsService,
])
void main() {
  late AccountBloc accountBloc;
  late MockGetAccountUseCase mockGetAccountUseCase;
  late MockGetAccountBalanceUseCase mockGetAccountBalanceUseCase;
  late MockGetAccountStatementUseCase mockGetAccountStatementUseCase;
  late MockTransferMoneyUseCase mockTransferMoneyUseCase;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
  final testAccount = Account(
    id: '1',
    number: '12345-6',
    agency: '0001',
    holderName: 'John Doe',
    holderDocument: '12345678900',
    type: AccountType.checking,
    status: AccountStatus.active,
    openingDate: DateTime(2020, 1, 1),
  );

  final testBalance = AccountBalance(
    accountId: '1',
    available: 5000.0,
    total: 5000.0,
    blocked: 0.0,
    overdraftLimit: 1000.0,
    overdraftUsed: 0.0,
    updatedAt: DateTime(2024, 1, 1),
  );

  final testTransaction = Transaction(
    id: 'tx1',
    accountId: '1',
    description: 'Test transaction',
    amount: 100.0,
    date: DateTime(2024, 1, 1),
    type: TransactionType.debit,
    status: TransactionStatus.completed,
    category: 'Transfer',
  );

  final testStatement = AccountStatement(
    accountId: '1',
    startDate: DateTime(2024, 1, 1),
    endDate: DateTime(2024, 1, 31),
    initialBalance: 5000.0,
    finalBalance: 4900.0,
    transactions: [testTransaction],
  );

  setUp(() {
    mockGetAccountUseCase = MockGetAccountUseCase();
    mockGetAccountBalanceUseCase = MockGetAccountBalanceUseCase();
    mockGetAccountStatementUseCase = MockGetAccountStatementUseCase();
    mockTransferMoneyUseCase = MockTransferMoneyUseCase();
    mockAnalyticsService = MockAnalyticsService();

    accountBloc = AccountBloc(
      getAccountUseCase: mockGetAccountUseCase,
      getAccountBalanceUseCase: mockGetAccountBalanceUseCase,
      getAccountStatementUseCase: mockGetAccountStatementUseCase,
      transferMoneyUseCase: mockTransferMoneyUseCase,
      analyticsService: mockAnalyticsService,
    );

    // Default stubs for analytics
    when(mockAnalyticsService.trackEvent(any, any))
        .thenAnswer((_) async => {});
    when(mockAnalyticsService.trackError(any, any))
        .thenAnswer((_) async => {});
  });

  tearDown(() {
    accountBloc.close();
  });

  group('AccountBloc - Initial State', () {
    test('initial state is AccountInitialState', () {
      expect(accountBloc.state, equals(const AccountInitialState()));
    });
  });

  group('AccountBloc - LoadAccountEvent', () {
    blocTest<AccountBloc, AccountState>(
      'emits [AccountLoadingState, AccountLoadedState] when load succeeds',
      build: () {
        when(mockGetAccountUseCase.execute())
            .thenAnswer((_) async => testAccount);
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountEvent()),
      expect: () => [
        const AccountLoadingState(),
        AccountLoadedState(account: testAccount),
      ],
      verify: (_) {
        verify(mockGetAccountUseCase.execute()).called(1);
        verify(mockAnalyticsService.trackEvent('account_load', any)).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountLoadingState, AccountErrorState] when load fails',
      build: () {
        when(mockGetAccountUseCase.execute())
            .thenThrow(Exception('Failed to load account'));
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountEvent()),
      expect: () => [
        const AccountLoadingState(),
        isA<AccountErrorState>()
            .having((s) => s.message, 'message', contains('Failed to load account')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('account_load_error', any))
            .called(1);
      },
    );

    test('tracks analytics on successful load', () async {
      when(mockGetAccountUseCase.execute())
          .thenAnswer((_) async => testAccount);

      accountBloc.add(const LoadAccountEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('account_load', {})).called(1);
    });
  });

  group('AccountBloc - LoadAccountBalanceEvent', () {
    blocTest<AccountBloc, AccountState>(
      'emits [AccountBalanceLoadingState, AccountBalanceLoadedState] when load succeeds',
      build: () {
        when(mockGetAccountBalanceUseCase.execute())
            .thenAnswer((_) async => testBalance);
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountBalanceEvent()),
      expect: () => [
        const AccountBalanceLoadingState(),
        AccountBalanceLoadedState(balance: testBalance),
      ],
      verify: (_) {
        verify(mockGetAccountBalanceUseCase.execute()).called(1);
        verify(mockAnalyticsService.trackEvent('account_balance_load', any))
            .called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountBalanceLoadingState, AccountBalanceErrorState] when load fails',
      build: () {
        when(mockGetAccountBalanceUseCase.execute())
            .thenThrow(Exception('Failed to load balance'));
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountBalanceEvent()),
      expect: () => [
        const AccountBalanceLoadingState(),
        isA<AccountBalanceErrorState>()
            .having((s) => s.message, 'message', contains('Failed to load balance')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('account_balance_load_error', any))
            .called(1);
      },
    );

    test('tracks analytics on successful balance load', () async {
      when(mockGetAccountBalanceUseCase.execute())
          .thenAnswer((_) async => testBalance);

      accountBloc.add(const LoadAccountBalanceEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('account_balance_load', {}))
          .called(1);
    });
  });

  group('AccountBloc - LoadAccountStatementEvent', () {
    blocTest<AccountBloc, AccountState>(
      'emits [AccountStatementLoadingState, AccountStatementLoadedState] when load succeeds',
      build: () {
        when(mockGetAccountStatementUseCase.execute(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        )).thenAnswer((_) async => testStatement);
        return accountBloc;
      },
      act: (bloc) => bloc.add(LoadAccountStatementEvent(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
      )),
      expect: () => [
        const AccountStatementLoadingState(),
        AccountStatementLoadedState(statement: testStatement),
      ],
      verify: (_) {
        verify(mockGetAccountStatementUseCase.execute(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 31),
        )).called(1);
        verify(mockAnalyticsService.trackEvent('account_statement_load', any))
            .called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountStatementLoadingState, AccountStatementLoadedState] when load succeeds without date parameters',
      build: () {
        when(mockGetAccountStatementUseCase.execute(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        )).thenAnswer((_) async => testStatement);
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountStatementEvent()),
      expect: () => [
        const AccountStatementLoadingState(),
        AccountStatementLoadedState(statement: testStatement),
      ],
      verify: (_) {
        verify(mockGetAccountStatementUseCase.execute(
          startDate: null,
          endDate: null,
        )).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountStatementLoadingState, AccountStatementErrorState] when load fails',
      build: () {
        when(mockGetAccountStatementUseCase.execute(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        )).thenThrow(Exception('Failed to load statement'));
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountStatementEvent()),
      expect: () => [
        const AccountStatementLoadingState(),
        isA<AccountStatementErrorState>()
            .having((s) => s.message, 'message', contains('Failed to load statement')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('account_statement_load_error', any))
            .called(1);
      },
    );

    test('tracks analytics on successful statement load', () async {
      when(mockGetAccountStatementUseCase.execute(
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
      )).thenAnswer((_) async => testStatement);

      accountBloc.add(const LoadAccountStatementEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('account_statement_load', {}))
          .called(1);
    });
  });

  group('AccountBloc - TransferMoneyEvent', () {
    blocTest<AccountBloc, AccountState>(
      'emits [TransferMoneyLoadingState, TransferMoneySuccessState] when transfer succeeds',
      build: () {
        when(mockTransferMoneyUseCase.execute(
          destinationAccount: anyNamed('destinationAccount'),
          destinationAgency: anyNamed('destinationAgency'),
          destinationBank: anyNamed('destinationBank'),
          destinationName: anyNamed('destinationName'),
          destinationDocument: anyNamed('destinationDocument'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
        )).thenAnswer((_) async => testTransaction);
        return accountBloc;
      },
      act: (bloc) => bloc.add(const TransferMoneyEvent(
        destinationAccount: '12345-6',
        destinationAgency: '0001',
        destinationBank: '001',
        destinationName: 'Jane Doe',
        destinationDocument: '98765432100',
        amount: 100.0,
        description: 'Test transfer',
      )),
      expect: () => [
        const TransferMoneyLoadingState(),
        TransferMoneySuccessState(transaction: testTransaction),
      ],
      verify: (_) {
        verify(mockTransferMoneyUseCase.execute(
          destinationAccount: '12345-6',
          destinationAgency: '0001',
          destinationBank: '001',
          destinationName: 'Jane Doe',
          destinationDocument: '98765432100',
          amount: 100.0,
          description: 'Test transfer',
        )).called(1);
        verify(mockAnalyticsService.trackEvent('transfer_money', any)).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'emits [TransferMoneyLoadingState, TransferMoneySuccessState] when transfer succeeds without description',
      build: () {
        when(mockTransferMoneyUseCase.execute(
          destinationAccount: anyNamed('destinationAccount'),
          destinationAgency: anyNamed('destinationAgency'),
          destinationBank: anyNamed('destinationBank'),
          destinationName: anyNamed('destinationName'),
          destinationDocument: anyNamed('destinationDocument'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
        )).thenAnswer((_) async => testTransaction);
        return accountBloc;
      },
      act: (bloc) => bloc.add(const TransferMoneyEvent(
        destinationAccount: '12345-6',
        destinationAgency: '0001',
        destinationBank: '001',
        destinationName: 'Jane Doe',
        destinationDocument: '98765432100',
        amount: 100.0,
      )),
      expect: () => [
        const TransferMoneyLoadingState(),
        TransferMoneySuccessState(transaction: testTransaction),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'emits [TransferMoneyLoadingState, TransferMoneyErrorState] when transfer fails',
      build: () {
        when(mockTransferMoneyUseCase.execute(
          destinationAccount: anyNamed('destinationAccount'),
          destinationAgency: anyNamed('destinationAgency'),
          destinationBank: anyNamed('destinationBank'),
          destinationName: anyNamed('destinationName'),
          destinationDocument: anyNamed('destinationDocument'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
        )).thenThrow(Exception('Insufficient funds'));
        return accountBloc;
      },
      act: (bloc) => bloc.add(const TransferMoneyEvent(
        destinationAccount: '12345-6',
        destinationAgency: '0001',
        destinationBank: '001',
        destinationName: 'Jane Doe',
        destinationDocument: '98765432100',
        amount: 10000.0,
      )),
      expect: () => [
        const TransferMoneyLoadingState(),
        isA<TransferMoneyErrorState>()
            .having((s) => s.message, 'message', contains('Insufficient funds')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('transfer_money_error', any))
            .called(1);
      },
    );

    test('tracks analytics with correct metadata on successful transfer', () async {
      when(mockTransferMoneyUseCase.execute(
        destinationAccount: anyNamed('destinationAccount'),
        destinationAgency: anyNamed('destinationAgency'),
        destinationBank: anyNamed('destinationBank'),
        destinationName: anyNamed('destinationName'),
        destinationDocument: anyNamed('destinationDocument'),
        amount: anyNamed('amount'),
        description: anyNamed('description'),
      )).thenAnswer((_) async => testTransaction);

      accountBloc.add(const TransferMoneyEvent(
        destinationAccount: '12345-6',
        destinationAgency: '0001',
        destinationBank: '001',
        destinationName: 'Jane Doe',
        destinationDocument: '98765432100',
        amount: 100.0,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('transfer_money', {
        'amount': 100.0,
        'destination_bank': '001',
      })).called(1);
    });
  });

  group('AccountBloc - Analytics Tracking', () {
    test('tracks all successful operations', () async {
      when(mockGetAccountUseCase.execute())
          .thenAnswer((_) async => testAccount);
      when(mockGetAccountBalanceUseCase.execute())
          .thenAnswer((_) async => testBalance);
      when(mockGetAccountStatementUseCase.execute(
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
      )).thenAnswer((_) async => testStatement);

      accountBloc.add(const LoadAccountEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      accountBloc.add(const LoadAccountBalanceEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      accountBloc.add(const LoadAccountStatementEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackEvent('account_load', any)).called(1);
      verify(mockAnalyticsService.trackEvent('account_balance_load', any))
          .called(1);
      verify(mockAnalyticsService.trackEvent('account_statement_load', any))
          .called(1);
    });

    test('tracks all errors with correct event names', () async {
      when(mockGetAccountUseCase.execute())
          .thenThrow(Exception('Error 1'));
      when(mockGetAccountBalanceUseCase.execute())
          .thenThrow(Exception('Error 2'));
      when(mockGetAccountStatementUseCase.execute(
        startDate: anyNamed('startDate'),
        endDate: anyNamed('endDate'),
      )).thenThrow(Exception('Error 3'));
      when(mockTransferMoneyUseCase.execute(
        destinationAccount: anyNamed('destinationAccount'),
        destinationAgency: anyNamed('destinationAgency'),
        destinationBank: anyNamed('destinationBank'),
        destinationName: anyNamed('destinationName'),
        destinationDocument: anyNamed('destinationDocument'),
        amount: anyNamed('amount'),
        description: anyNamed('description'),
      )).thenThrow(Exception('Error 4'));

      accountBloc.add(const LoadAccountEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      accountBloc.add(const LoadAccountBalanceEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      accountBloc.add(const LoadAccountStatementEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      accountBloc.add(const TransferMoneyEvent(
        destinationAccount: '12345-6',
        destinationAgency: '0001',
        destinationBank: '001',
        destinationName: 'Jane Doe',
        destinationDocument: '98765432100',
        amount: 100.0,
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      verify(mockAnalyticsService.trackError('account_load_error', any))
          .called(1);
      verify(mockAnalyticsService.trackError('account_balance_load_error', any))
          .called(1);
      verify(mockAnalyticsService.trackError('account_statement_load_error', any))
          .called(1);
      verify(mockAnalyticsService.trackError('transfer_money_error', any))
          .called(1);
    });
  });

  group('AccountBloc - Error Messages', () {
    blocTest<AccountBloc, AccountState>(
      'includes error message in error states',
      build: () {
        when(mockGetAccountUseCase.execute())
            .thenThrow(Exception('Specific error message'));
        return accountBloc;
      },
      act: (bloc) => bloc.add(const LoadAccountEvent()),
      expect: () => [
        const AccountLoadingState(),
        isA<AccountErrorState>().having(
          (s) => s.message,
          'message',
          contains('Specific error message'),
        ),
      ],
    );

    test('preserves error details for debugging', () async {
      final error = Exception('Network timeout');
      when(mockGetAccountBalanceUseCase.execute()).thenThrow(error);

      accountBloc.add(const LoadAccountBalanceEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      final state = accountBloc.state;
      expect(state, isA<AccountBalanceErrorState>());
      expect((state as AccountBalanceErrorState).message, contains('Network timeout'));
    });
  });
}
