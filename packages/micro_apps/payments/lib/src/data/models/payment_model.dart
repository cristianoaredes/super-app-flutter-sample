import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/payment.dart';

part 'payment_model.freezed.dart';
part 'payment_model.g.dart';

@freezed
class PaymentModel with _$PaymentModel {
  const factory PaymentModel({
    required String id,
    required double amount,
    required String recipient,
    required String description,
    required DateTime date,
    required String status,
  }) = _PaymentModel;
  
  factory PaymentModel.fromJson(Map<String, dynamic> json) => _$PaymentModelFromJson(json);
  
  factory PaymentModel.fromEntity(Payment payment) => PaymentModel(
    id: payment.id,
    amount: payment.amount,
    recipient: payment.recipient,
    description: payment.description,
    date: payment.date,
    status: payment.status.toString().split('.').last,
  );
}

extension PaymentModelX on PaymentModel {
  Payment toEntity() => Payment(
    id: id,
    amount: amount,
    recipient: recipient,
    description: description,
    date: date,
    status: PaymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => PaymentStatus.pending,
    ),
  );
}
