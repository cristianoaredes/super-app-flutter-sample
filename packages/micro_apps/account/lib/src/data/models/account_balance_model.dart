import '../../domain/entities/account_balance.dart';


class AccountBalanceModel extends AccountBalance {
  const AccountBalanceModel({
    required super.accountId,
    required super.available,
    required super.total,
    required super.blocked,
    required super.overdraftLimit,
    required super.overdraftUsed,
    required super.updatedAt,
  });
  
  
  factory AccountBalanceModel.fromJson(Map<String, dynamic> json) {
    return AccountBalanceModel(
      accountId: json['account_id'] as String,
      available: (json['available'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      blocked: (json['blocked'] as num).toDouble(),
      overdraftLimit: (json['overdraft_limit'] as num).toDouble(),
      overdraftUsed: (json['overdraft_used'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'available': available,
      'total': total,
      'blocked': blocked,
      'overdraft_limit': overdraftLimit,
      'overdraft_used': overdraftUsed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  
  @override
  AccountBalanceModel copyWith({
    String? accountId,
    double? available,
    double? total,
    double? blocked,
    double? overdraftLimit,
    double? overdraftUsed,
    DateTime? updatedAt,
  }) {
    return AccountBalanceModel(
      accountId: accountId ?? this.accountId,
      available: available ?? this.available,
      total: total ?? this.total,
      blocked: blocked ?? this.blocked,
      overdraftLimit: overdraftLimit ?? this.overdraftLimit,
      overdraftUsed: overdraftUsed ?? this.overdraftUsed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
