import 'package:equatable/equatable.dart';


class PixKey extends Equatable {
  final String id;
  final String value;
  final PixKeyType type;
  final String? name;
  final DateTime createdAt;
  final bool isActive;
  
  const PixKey({
    required this.id,
    required this.value,
    required this.type,
    this.name,
    required this.createdAt,
    required this.isActive,
  });
  
  @override
  List<Object?> get props => [id, value, type, name, createdAt, isActive];
  
  
  PixKey copyWith({
    String? id,
    String? value,
    PixKeyType? type,
    String? name,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PixKey(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
  
  
  String get formattedName => name ?? 'Chave ${type.name}';
  
  
  String get formattedValue {
    switch (type) {
      case PixKeyType.cpf:
        return _formatCpf(value);
      case PixKeyType.cnpj:
        return _formatCnpj(value);
      case PixKeyType.phone:
        return _formatPhone(value);
      case PixKeyType.email:
      case PixKeyType.random:
      default:
        return value;
    }
  }
  
  
  String _formatCpf(String cpf) {
    if (cpf.length != 11) return cpf;
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }
  
  
  String _formatCnpj(String cnpj) {
    if (cnpj.length != 14) return cnpj;
    return '${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12)}';
  }
  
  
  String _formatPhone(String phone) {
    if (phone.length != 11) return phone;
    return '(${phone.substring(0, 2)}) ${phone.substring(2, 7)}-${phone.substring(7)}';
  }
}


enum PixKeyType {
  cpf,
  cnpj,
  email,
  phone,
  random,
}
