import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payments/src/domain/entities/payment.dart';
import 'package:payments/src/domain/repositories/payment_repository.dart';
import 'package:payments/src/domain/usecases/make_payment_usecase.dart';

class _RecordingPaymentRepository implements PaymentRepository {
  int makeCalls = 0;

  @override
  Future<bool> cancelPayment(String id) => throw UnimplementedError();

  @override
  Future<Payment?> getPaymentById(String id) => throw UnimplementedError();

  @override
  Future<List<Payment>> getPayments() => throw UnimplementedError();

  @override
  Future<Payment> makePayment(Payment payment) async {
    makeCalls += 1;
    return payment;
  }
}

void main() {
  late _RecordingPaymentRepository repository;
  late MakePaymentUseCase useCase;

  setUp(() {
    repository = _RecordingPaymentRepository();
    useCase = MakePaymentUseCase(repository);
  });

  Payment payment({double amount = 10, String recipient = 'Conta'}) {
    return Payment(
      id: 'p1',
      amount: amount,
      recipient: recipient,
      description: 'conta',
      date: DateTime(2024, 1, 1),
      status: PaymentStatus.pending,
    );
  }

  test('rejects non-positive amount without calling repository', () async {
    expect(
      () => useCase.execute(payment(amount: 0)),
      throwsA(isA<ValidationException>()),
    );
    expect(repository.makeCalls, 0);
  });

  test('rejects empty recipient without calling repository', () async {
    expect(
      () => useCase.execute(payment(recipient: ' ')),
      throwsA(isA<ValidationException>()),
    );
    expect(repository.makeCalls, 0);
  });

  test('forwards a valid payment to the repository', () async {
    final result = await useCase.execute(payment(amount: 42));
    expect(result.amount, 42);
    expect(repository.makeCalls, 1);
  });
}
