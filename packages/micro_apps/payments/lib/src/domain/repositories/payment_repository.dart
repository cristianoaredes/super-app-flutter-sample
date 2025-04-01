import '../entities/payment.dart';


abstract class PaymentRepository {
  
  Future<List<Payment>> getPayments();

  
  Future<Payment?> getPaymentById(String id);

  
  Future<Payment> makePayment(Payment payment);

  
  Future<bool> cancelPayment(String id);
}
