import '../../domain/entities/pix_qr_code.dart';
import '../../domain/entities/pix_key.dart';
import 'pix_key_model.dart';


class PixQrCodeModel extends PixQrCode {
  const PixQrCodeModel({
    required super.id,
    required super.payload,
    required super.pixKey,
    super.amount,
    super.description,
    required super.createdAt,
    super.expiresAt,
    required super.isStatic,
  });

  
  factory PixQrCodeModel.fromJson(Map<String, dynamic> json) {
    return PixQrCodeModel(
      id: json['id'] as String,
      payload: json['payload'] as String,
      pixKey: PixKeyModel.fromJson(json['pix_key'] as Map<String, dynamic>),
      amount:
          json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isStatic: json['is_static'] as bool,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payload': payload,
      'pix_key': (pixKey as PixKeyModel).toJson(),
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_static': isStatic,
    };
  }

  
  @override
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
    return PixQrCodeModel(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      pixKey: pixKey ?? this.pixKey as PixKeyModel,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isStatic: isStatic ?? this.isStatic,
    );
  }
}
