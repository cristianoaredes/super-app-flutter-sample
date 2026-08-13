import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:payments/src/bootstrap/hydrated_storage_bootstrap.dart';
import 'package:payments/src/domain/entities/payment.dart';
import 'package:payments/src/domain/repositories/payment_repository.dart';
import 'package:payments/src/presentation/cubits/payments_cubit.dart';
import 'package:core_interfaces/core_interfaces.dart';

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

class _EmptyRepo implements PaymentRepository {
  @override
  Future<bool> cancelPayment(String id) async => false;

  @override
  Future<Payment?> getPaymentById(String id) async => null;

  @override
  Future<List<Payment>> getPayments() async => [];

  @override
  Future<Payment> makePayment(Payment payment) async => payment;
}

class _NoopAnalytics implements AnalyticsService {
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
      {StackTrace? stackTrace}) async {}

  @override
  Future<void> trackEvent(
      String eventName, Map<String, dynamic> parameters) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    HydratedBloc.storage = null;
  });

  test('PaymentsCubit without storage throws StorageNotFound', () {
    HydratedBloc.storage = null;
    expect(
      () => PaymentsCubit(
        repository: _EmptyRepo(),
        analyticsService: _NoopAnalytics(),
      ),
      throwsA(isA<StorageNotFound>()),
    );
  });

  test('ensureHydratedStorage lets PaymentsCubit construct', () async {
    HydratedBloc.storage = null;
    await ensureHydratedStorage();

    final cubit = PaymentsCubit(
      repository: _EmptyRepo(),
      analyticsService: _NoopAnalytics(),
    );
    expect(cubit.state.payments, isEmpty);
    await cubit.close();
  });

  test('ensureHydratedStorage is idempotent', () async {
    HydratedBloc.storage = null;
    await ensureHydratedStorage();
    final first = HydratedBloc.storage;
    await ensureHydratedStorage();
    expect(identical(first, HydratedBloc.storage), isTrue);
  });

  test('already-installed storage is left untouched', () async {
    final memory = _MemoryStorage();
    HydratedBloc.storage = memory;
    await ensureHydratedStorage();
    expect(identical(HydratedBloc.storage, memory), isTrue);
  });
}
