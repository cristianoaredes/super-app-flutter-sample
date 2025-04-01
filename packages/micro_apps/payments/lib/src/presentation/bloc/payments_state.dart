import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_json_converter.dart';

part 'payments_state.freezed.dart';
part 'payments_state.g.dart';

@freezed
class PaymentsState with _$PaymentsState {
  const factory PaymentsState({
    @Default([]) @PaymentConverter() List<Payment> payments,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _PaymentsState;

  factory PaymentsState.fromJson(Map<String, dynamic> json) =>
      _$PaymentsStateFromJson(json);
}
