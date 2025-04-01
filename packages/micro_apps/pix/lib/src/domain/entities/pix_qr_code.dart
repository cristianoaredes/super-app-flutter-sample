import 'package:equatable/equatable.dart';

import 'pix_key.dart';


class PixQrCode extends Equatable {
  final String id;
  final String payload;
  final PixKey pixKey;
  final double? amount;
  final String? description;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isStatic;
  
  const PixQrCode({
    required this.id,
    required this.payload,
    required this.pixKey,
    this.amount,
    this.description,
    required this.createdAt,
    this.expiresAt,
    required this.isStatic,
  });
  
  @override
  List<Object?> get props => [
    id,
    payload,
    pixKey,
    amount,
    description,
    createdAt,
    expiresAt,
    isStatic,
  ];
  
  
  PixQrCode copyWith({
    String? id,
    String? payload,
    PixKey? pixKey,
    double? amount,
    String? description,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isStatic,
  }) {
    return PixQrCode(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      pixKey: pixKey ?? this.pixKey,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isStatic: isStatic ?? this.isStatic,
    );
  }
  
  
  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }
  
  
  bool get isDynamic => !isStatic;
}
