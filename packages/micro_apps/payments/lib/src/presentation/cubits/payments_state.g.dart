// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payments_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PaymentsStateImpl _$$PaymentsStateImplFromJson(Map<String, dynamic> json) =>
    _$PaymentsStateImpl(
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) =>
                  const PaymentConverter().fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isLoading: json['isLoading'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$$PaymentsStateImplToJson(_$PaymentsStateImpl instance) =>
    <String, dynamic>{
      'payments':
          instance.payments.map(const PaymentConverter().toJson).toList(),
      'isLoading': instance.isLoading,
      'errorMessage': instance.errorMessage,
    };
