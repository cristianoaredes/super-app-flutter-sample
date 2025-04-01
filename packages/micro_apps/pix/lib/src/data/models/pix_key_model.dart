import '../../domain/entities/pix_key.dart';


class PixKeyModel extends PixKey {
  const PixKeyModel({
    required super.id,
    required super.value,
    required super.type,
    super.name,
    required super.createdAt,
    required super.isActive,
  });
  
  
  factory PixKeyModel.fromJson(Map<String, dynamic> json) {
    return PixKeyModel(
      id: json['id'] as String,
      value: json['value'] as String,
      type: _parsePixKeyType(json['type'] as String),
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool,
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'type': _pixKeyTypeToString(type),
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
  
  
  @override
  PixKeyModel copyWith({
    String? id,
    String? value,
    PixKeyType? type,
    String? name,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PixKeyModel(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
  
  
  static PixKeyType _parsePixKeyType(String type) {
    switch (type) {
      case 'cpf':
        return PixKeyType.cpf;
      case 'cnpj':
        return PixKeyType.cnpj;
      case 'email':
        return PixKeyType.email;
      case 'phone':
        return PixKeyType.phone;
      case 'random':
        return PixKeyType.random;
      default:
        return PixKeyType.random;
    }
  }
  
  
  static String _pixKeyTypeToString(PixKeyType type) {
    switch (type) {
      case PixKeyType.cpf:
        return 'cpf';
      case PixKeyType.cnpj:
        return 'cnpj';
      case PixKeyType.email:
        return 'email';
      case PixKeyType.phone:
        return 'phone';
      case PixKeyType.random:
        return 'random';
    }
  }
}
