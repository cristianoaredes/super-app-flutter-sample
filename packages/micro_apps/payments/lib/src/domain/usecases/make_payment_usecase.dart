import '../entities/payment.dart';
import '../repositories/payment_repository.dart';


class MakePaymentUseCase {
  final PaymentRepository _repository;
  
  MakePaymentUseCase(this._repository);
  
  
  Future<Payment> execute(Payment payment) => _repository.makePayment(payment);
}
