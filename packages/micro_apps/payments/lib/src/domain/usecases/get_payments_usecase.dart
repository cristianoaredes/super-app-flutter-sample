import '../entities/payment.dart';
import '../repositories/payment_repository.dart';


class GetPaymentsUseCase {
  final PaymentRepository _repository;
  
  GetPaymentsUseCase(this._repository);
  
  
  Future<List<Payment>> execute() => _repository.getPayments();
}
