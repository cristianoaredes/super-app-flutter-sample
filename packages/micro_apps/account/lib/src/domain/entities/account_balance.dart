import 'package:equatable/equatable.dart';


class AccountBalance extends Equatable {
  final String accountId;
  final double available;
  final double total;
  final double blocked;
  final double overdraftLimit;
  final double overdraftUsed;
  final DateTime updatedAt;
  
  const AccountBalance({
    required this.accountId,
    required this.available,
    required this.total,
    required this.blocked,
    required this.overdraftLimit,
    required this.overdraftUsed,
    required this.updatedAt,
  });
  
  @override
  List<Object?> get props => [
    accountId,
    available,
    total,
    blocked,
    overdraftLimit,
    overdraftUsed,
    updatedAt,
  ];
  
  
  AccountBalance copyWith({
    String? accountId,
    double? available,
    double? total,
    double? blocked,
    double? overdraftLimit,
    double? overdraftUsed,
    DateTime? updatedAt,
  }) {
    return AccountBalance(
      accountId: accountId ?? this.accountId,
      available: available ?? this.available,
      total: total ?? this.total,
      blocked: blocked ?? this.blocked,
      overdraftLimit: overdraftLimit ?? this.overdraftLimit,
      overdraftUsed: overdraftUsed ?? this.overdraftUsed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  
  double get availableWithOverdraft => available + (overdraftLimit - overdraftUsed);
  
  
  bool get isNegative => available < 0;
  
  
  bool get isUsingOverdraft => overdraftUsed > 0;
}
