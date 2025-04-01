
class Payment {
  final String id;
  final double amount;
  final String recipient;
  final String description;
  final DateTime date;
  final PaymentStatus status;
  
  Payment({
    required this.id,
    required this.amount,
    required this.recipient,
    required this.description,
    required this.date,
    required this.status,
  });
}


enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}
