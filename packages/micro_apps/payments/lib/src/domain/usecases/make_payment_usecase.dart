import 'package:core_interfaces/core_interfaces.dart';

import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

class MakePaymentUseCase {
  final PaymentRepository _repository;

  MakePaymentUseCase(this._repository);

  Future<Payment> execute(Payment payment) {
    if (payment.amount <= 0) {
      throw ValidationException(
        message: 'Valor de pagamento inválido',
        fieldErrors: const {'amount': 'deve ser maior que zero'},
      );
    }
    if (payment.recipient.trim().isEmpty) {
      throw ValidationException(
        message: 'Destinatário inválido',
        fieldErrors: const {'recipient': 'obrigatório'},
      );
    }
    return _repository.makePayment(payment);
  }
}
