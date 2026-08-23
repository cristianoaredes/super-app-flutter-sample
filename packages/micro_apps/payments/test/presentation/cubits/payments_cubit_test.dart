import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:payments/src/domain/entities/payment.dart';
import 'package:payments/src/domain/repositories/payment_repository.dart';
import 'package:payments/src/presentation/cubits/payments_cubit.dart';

class _MemoryStorage implements Storage {
  final Map<String, dynamic> _data = {};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

class _FakeRepo implements PaymentRepository {
  _FakeRepo({
    this.payments = const [],
    this.getPaymentsError,
    this.makePaymentError,
    this.cancelResult = true,
  });

  List<Payment> payments;
  Object? getPaymentsError;
  Object? makePaymentError;
  bool cancelResult;
  int getPaymentsCalls = 0;
  int makePaymentCalls = 0;
  int cancelCalls = 0;

  @override
  Future<bool> cancelPayment(String id) async {
    cancelCalls++;
    if (cancelResult) {
      payments = payments.where((p) => p.id != id).toList();
    }
    return cancelResult;
  }

  @override
  Future<Payment?> getPaymentById(String id) async {
    try {
      return payments.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Payment>> getPayments() async {
    getPaymentsCalls++;
    if (getPaymentsError != null) throw getPaymentsError!;
    return List<Payment>.from(payments);
  }

  @override
  Future<Payment> makePayment(Payment payment) async {
    makePaymentCalls++;
    if (makePaymentError != null) throw makePaymentError!;
    payments = [...payments, payment];
    return payment;
  }
}

class _FakeAnalytics implements AnalyticsService {
  final events = <String>[];
  final errors = <String>[];

  @override
  Future<void> endSession() async {}

  @override
  Future<void> setUserId(String userId) async {}

  @override
  Future<void> setUserProperties(Map<String, dynamic> properties) async {}

  @override
  Future<void> startSession() async {}

  @override
  Future<void> trackError(String errorName, String errorMessage,
      {StackTrace? stackTrace}) async {
    errors.add(errorName);
  }

  @override
  Future<void> trackEvent(
      String eventName, Map<String, dynamic> parameters) async {
    events.add(eventName);
  }
}

void main() {
  late _FakeRepo repo;
  late _FakeAnalytics analytics;

  final testPayment = Payment(
    id: 'pay-123',
    amount: 100.0,
    recipient: 'Test Recipient',
    description: 'Test payment',
    date: DateTime(2024, 1, 1),
    status: PaymentStatus.completed,
  );

  setUp(() {
    HydratedBloc.storage = _MemoryStorage();
    repo = _FakeRepo(payments: [testPayment]);
    analytics = _FakeAnalytics();
  });

  tearDown(() {
    HydratedBloc.storage = null;
  });

  PaymentsCubit buildCubit() => PaymentsCubit(
        repository: repo,
        analyticsService: analytics,
      );

  test('initial state is empty and not loading', () {
    final cubit = buildCubit();
    expect(cubit.state.payments, isEmpty);
    expect(cubit.state.isLoading, isFalse);
    cubit.close();
  });

  test('fetchPayments loads payments', () async {
    final cubit = buildCubit();
    await cubit.fetchPayments();
    expect(cubit.state.payments, hasLength(1));
    expect(cubit.state.isLoading, isFalse);
    expect(repo.getPaymentsCalls, 1);
    expect(analytics.events, contains('payments_loaded'));
    await cubit.close();
  });

  test('fetchPayments records error when repository throws', () async {
    repo.getPaymentsError = Exception('Network error');
    final cubit = buildCubit();
    await cubit.fetchPayments();
    expect(cubit.state.errorMessage, contains('Network error'));
    expect(analytics.errors, contains('payments_load_failed'));
    await cubit.close();
  });

  test('makePayment then refreshes the list', () async {
    final cubit = buildCubit();
    await cubit.makePayment(
      Payment(
        id: 'pay-new',
        amount: 150.0,
        recipient: 'New Recipient',
        description: 'New payment',
        date: DateTime(2024, 1, 3),
        status: PaymentStatus.pending,
      ),
    );
    expect(repo.makePaymentCalls, 1);
    expect(cubit.state.payments, hasLength(2));
    expect(analytics.events, contains('payment_made'));
    await cubit.close();
  });

  test('cancelPayment removes the item when repository succeeds', () async {
    final cubit = buildCubit();
    await cubit.cancelPayment('pay-123');
    expect(repo.cancelCalls, 1);
    expect(cubit.state.payments, isEmpty);
    expect(analytics.events, contains('payment_cancelled'));
    await cubit.close();
  });
}
