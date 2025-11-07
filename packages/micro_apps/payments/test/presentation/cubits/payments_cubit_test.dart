import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:payments/src/domain/entities/payment.dart';
import 'package:payments/src/domain/repositories/payment_repository.dart';
import 'package:payments/src/presentation/cubits/payments_cubit.dart';
import 'package:payments/src/presentation/cubits/payments_state.dart';

import 'payments_cubit_test.mocks.dart';

/// Gera os mocks necessários para os testes
/// Execute: dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  PaymentRepository,
  AnalyticsService,
])
void main() {
  late PaymentsCubit paymentsCubit;
  late MockPaymentRepository mockRepository;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
  final testPayment = Payment(
    id: 'pay-123',
    amount: 100.0,
    recipient: 'Test Recipient',
    description: 'Test payment',
    date: DateTime(2024, 1, 1),
    status: PaymentStatus.completed,
  );

  final testPayment2 = Payment(
    id: 'pay-456',
    amount: 200.0,
    recipient: 'Another Recipient',
    description: 'Another payment',
    date: DateTime(2024, 1, 2),
    status: PaymentStatus.pending,
  );

  final testPayments = [testPayment, testPayment2];

  setUp(() {
    mockRepository = MockPaymentRepository();
    mockAnalyticsService = MockAnalyticsService();

    paymentsCubit = PaymentsCubit(
      repository: mockRepository,
      analyticsService: mockAnalyticsService,
    );
  });

  tearDown(() {
    paymentsCubit.close();
  });

  group('PaymentsCubit', () {
    test('initial state should have empty payments list', () {
      expect(paymentsCubit.state.payments, isEmpty);
      expect(paymentsCubit.state.isLoading, isFalse);
      expect(paymentsCubit.state.errorMessage, isNull);
    });

    group('fetchPayments', () {
      blocTest<PaymentsCubit, PaymentsState>(
        'emits loading state then loaded state with payments when successful',
        build: () {
          when(mockRepository.getPayments())
              .thenAnswer((_) async => testPayments);
          return paymentsCubit;
        },
        act: (cubit) => cubit.fetchPayments(),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          PaymentsState(
            payments: testPayments,
            isLoading: false,
          ),
        ],
        verify: (_) {
          verify(mockRepository.getPayments()).called(1);
          verify(mockAnalyticsService.trackEvent(
            'payments_loaded',
            {'count': testPayments.length},
          )).called(1);
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits loading state then error state when fetching fails',
        build: () {
          when(mockRepository.getPayments())
              .thenThrow(Exception('Network error'));
          return paymentsCubit;
        },
        act: (cubit) => cubit.fetchPayments(),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            isLoading: false,
            errorMessage: 'Exception: Network error',
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'payments_load_failed',
            'Exception: Network error',
          )).called(1);
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits empty payments list when repository returns empty',
        build: () {
          when(mockRepository.getPayments()).thenAnswer((_) async => []);
          return paymentsCubit;
        },
        act: (cubit) => cubit.fetchPayments(),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            payments: [],
            isLoading: false,
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackEvent(
            'payments_loaded',
            {'count': 0},
          )).called(1);
        },
      );
    });

    group('makePayment', () {
      final newPayment = Payment(
        id: 'pay-new',
        amount: 150.0,
        recipient: 'New Recipient',
        description: 'New payment',
        date: DateTime(2024, 1, 3),
        status: PaymentStatus.pending,
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits loading state, makes payment, then fetches updated payments',
        build: () {
          when(mockRepository.makePayment(any)).thenAnswer((_) async => {});
          when(mockRepository.getPayments())
              .thenAnswer((_) async => [...testPayments, newPayment]);
          return paymentsCubit;
        },
        act: (cubit) => cubit.makePayment(newPayment),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(isLoading: true, errorMessage: null),
          PaymentsState(
            payments: [...testPayments, newPayment],
            isLoading: false,
          ),
        ],
        verify: (_) {
          verify(mockRepository.makePayment(newPayment)).called(1);
          verify(mockRepository.getPayments()).called(1);
          verify(mockAnalyticsService.trackEvent(
            'payment_made',
            {
              'amount': newPayment.amount,
              'recipient': newPayment.recipient,
            },
          )).called(1);
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits loading state then error state when making payment fails',
        build: () {
          when(mockRepository.makePayment(any))
              .thenThrow(Exception('Payment failed'));
          return paymentsCubit;
        },
        act: (cubit) => cubit.makePayment(newPayment),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            isLoading: false,
            errorMessage: 'Exception: Payment failed',
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'payment_failed',
            'Exception: Payment failed',
          )).called(1);
          verifyNever(mockRepository.getPayments());
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'handles repository exception during makePayment',
        build: () {
          when(mockRepository.makePayment(any))
              .thenThrow(Exception('Insufficient funds'));
          return paymentsCubit;
        },
        act: (cubit) => cubit.makePayment(newPayment),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            isLoading: false,
            errorMessage: 'Exception: Insufficient funds',
          ),
        ],
        verify: (_) {
          verify(mockRepository.makePayment(newPayment)).called(1);
          verify(mockAnalyticsService.trackError(
            'payment_failed',
            'Exception: Insufficient funds',
          )).called(1);
        },
      );
    });

    group('cancelPayment', () {
      const paymentId = 'pay-123';

      blocTest<PaymentsCubit, PaymentsState>(
        'emits loading state, cancels payment, then fetches updated payments',
        build: () {
          when(mockRepository.cancelPayment(any))
              .thenAnswer((_) async => true);
          when(mockRepository.getPayments())
              .thenAnswer((_) async => [testPayment2]); // Only second payment remains
          return paymentsCubit;
        },
        act: (cubit) => cubit.cancelPayment(paymentId),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(isLoading: true, errorMessage: null),
          PaymentsState(
            payments: [testPayment2],
            isLoading: false,
          ),
        ],
        verify: (_) {
          verify(mockRepository.cancelPayment(paymentId)).called(1);
          verify(mockRepository.getPayments()).called(1);
          verify(mockAnalyticsService.trackEvent(
            'payment_cancelled',
            {'payment_id': paymentId},
          )).called(1);
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits error state when cancel payment returns false',
        build: () {
          when(mockRepository.cancelPayment(any))
              .thenAnswer((_) async => false);
          return paymentsCubit;
        },
        act: (cubit) => cubit.cancelPayment(paymentId),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            isLoading: false,
            errorMessage: 'Falha ao cancelar o pagamento',
          ),
        ],
        verify: (_) {
          verify(mockRepository.cancelPayment(paymentId)).called(1);
          verifyNever(mockRepository.getPayments());
          verifyNever(mockAnalyticsService.trackEvent(
            'payment_cancelled',
            any,
          ));
        },
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'emits error state when cancel payment throws exception',
        build: () {
          when(mockRepository.cancelPayment(any))
              .thenThrow(Exception('Cancellation failed'));
          return paymentsCubit;
        },
        act: (cubit) => cubit.cancelPayment(paymentId),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          const PaymentsState(
            isLoading: false,
            errorMessage: 'Exception: Cancellation failed',
          ),
        ],
        verify: (_) {
          verify(mockAnalyticsService.trackError(
            'payment_cancel_failed',
            'Exception: Cancellation failed',
          )).called(1);
          verifyNever(mockRepository.getPayments());
        },
      );
    });

    group('state management', () {
      blocTest<PaymentsCubit, PaymentsState>(
        'clears error message when new operation starts',
        build: () {
          when(mockRepository.getPayments())
              .thenAnswer((_) async => testPayments);
          return paymentsCubit;
        },
        seed: () => const PaymentsState(
          isLoading: false,
          errorMessage: 'Previous error',
        ),
        act: (cubit) => cubit.fetchPayments(),
        expect: () => [
          const PaymentsState(isLoading: true, errorMessage: null),
          PaymentsState(
            payments: testPayments,
            isLoading: false,
          ),
        ],
      );

      blocTest<PaymentsCubit, PaymentsState>(
        'preserves payments when operation fails',
        build: () {
          when(mockRepository.makePayment(any))
              .thenThrow(Exception('Error'));
          return paymentsCubit;
        },
        seed: () => PaymentsState(
          payments: testPayments,
          isLoading: false,
        ),
        act: (cubit) => cubit.makePayment(testPayment),
        expect: () => [
          PaymentsState(
            payments: testPayments,
            isLoading: true,
            errorMessage: null,
          ),
          PaymentsState(
            payments: testPayments,
            isLoading: false,
            errorMessage: 'Exception: Error',
          ),
        ],
      );
    });
  });
}
