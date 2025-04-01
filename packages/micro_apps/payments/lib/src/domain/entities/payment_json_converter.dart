import 'package:freezed_annotation/freezed_annotation.dart';

import 'payment.dart';


class PaymentConverter implements JsonConverter<Payment, Map<String, dynamic>> {
  const PaymentConverter();

  @override
  Payment fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      recipient: json['recipient'] as String,
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
    );
  }

  @override
  Map<String, dynamic> toJson(Payment payment) {
    return {
      'id': payment.id,
      'amount': payment.amount,
      'recipient': payment.recipient,
      'description': payment.description,
      'date': payment.date.toIso8601String(),
      'status': payment.status.toString().split('.').last,
    };
  }
}
