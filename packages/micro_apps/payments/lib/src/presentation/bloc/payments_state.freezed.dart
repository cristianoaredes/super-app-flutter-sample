// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payments_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PaymentsState _$PaymentsStateFromJson(Map<String, dynamic> json) {
  return _PaymentsState.fromJson(json);
}

/// @nodoc
mixin _$PaymentsState {
  @PaymentConverter()
  List<Payment> get payments => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PaymentsStateCopyWith<PaymentsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentsStateCopyWith<$Res> {
  factory $PaymentsStateCopyWith(
          PaymentsState value, $Res Function(PaymentsState) then) =
      _$PaymentsStateCopyWithImpl<$Res, PaymentsState>;
  @useResult
  $Res call(
      {@PaymentConverter() List<Payment> payments,
      bool isLoading,
      String? errorMessage});
}

/// @nodoc
class _$PaymentsStateCopyWithImpl<$Res, $Val extends PaymentsState>
    implements $PaymentsStateCopyWith<$Res> {
  _$PaymentsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? payments = null,
    Object? isLoading = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      payments: null == payments
          ? _value.payments
          : payments // ignore: cast_nullable_to_non_nullable
              as List<Payment>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentsStateImplCopyWith<$Res>
    implements $PaymentsStateCopyWith<$Res> {
  factory _$$PaymentsStateImplCopyWith(
          _$PaymentsStateImpl value, $Res Function(_$PaymentsStateImpl) then) =
      __$$PaymentsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@PaymentConverter() List<Payment> payments,
      bool isLoading,
      String? errorMessage});
}

/// @nodoc
class __$$PaymentsStateImplCopyWithImpl<$Res>
    extends _$PaymentsStateCopyWithImpl<$Res, _$PaymentsStateImpl>
    implements _$$PaymentsStateImplCopyWith<$Res> {
  __$$PaymentsStateImplCopyWithImpl(
      _$PaymentsStateImpl _value, $Res Function(_$PaymentsStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? payments = null,
    Object? isLoading = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$PaymentsStateImpl(
      payments: null == payments
          ? _value._payments
          : payments // ignore: cast_nullable_to_non_nullable
              as List<Payment>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentsStateImpl implements _PaymentsState {
  const _$PaymentsStateImpl(
      {@PaymentConverter() final List<Payment> payments = const [],
      this.isLoading = false,
      this.errorMessage})
      : _payments = payments;

  factory _$PaymentsStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentsStateImplFromJson(json);

  final List<Payment> _payments;
  @override
  @JsonKey()
  @PaymentConverter()
  List<Payment> get payments {
    if (_payments is EqualUnmodifiableListView) return _payments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_payments);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? errorMessage;

  @override
  String toString() {
    return 'PaymentsState(payments: $payments, isLoading: $isLoading, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentsStateImpl &&
            const DeepCollectionEquality().equals(other._payments, _payments) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType,
      const DeepCollectionEquality().hash(_payments), isLoading, errorMessage);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentsStateImplCopyWith<_$PaymentsStateImpl> get copyWith =>
      __$$PaymentsStateImplCopyWithImpl<_$PaymentsStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentsStateImplToJson(
      this,
    );
  }
}

abstract class _PaymentsState implements PaymentsState {
  const factory _PaymentsState(
      {@PaymentConverter() final List<Payment> payments,
      final bool isLoading,
      final String? errorMessage}) = _$PaymentsStateImpl;

  factory _PaymentsState.fromJson(Map<String, dynamic> json) =
      _$PaymentsStateImpl.fromJson;

  @override
  @PaymentConverter()
  List<Payment> get payments;
  @override
  bool get isLoading;
  @override
  String? get errorMessage;
  @override
  @JsonKey(ignore: true)
  _$$PaymentsStateImplCopyWith<_$PaymentsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
