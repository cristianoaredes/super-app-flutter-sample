import 'package:equatable/equatable.dart';


class AccountSummary extends Equatable {
  final String accountId;
  final String accountNumber;
  final String agency;
  final double balance;
  final double income;
  final double expenses;
  final double savings;
  final double investments;
  final DateTime lastUpdate;
  
  const AccountSummary({
    required this.accountId,
    required this.accountNumber,
    required this.agency,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.investments,
    required this.lastUpdate,
  });
  
  @override
  List<Object?> get props => [
    accountId,
    accountNumber,
    agency,
    balance,
    income,
    expenses,
    savings,
    investments,
    lastUpdate,
  ];
  
  
  AccountSummary copyWith({
    String? accountId,
    String? accountNumber,
    String? agency,
    double? balance,
    double? income,
    double? expenses,
    double? savings,
    double? investments,
    DateTime? lastUpdate,
  }) {
    return AccountSummary(
      accountId: accountId ?? this.accountId,
      accountNumber: accountNumber ?? this.accountNumber,
      agency: agency ?? this.agency,
      balance: balance ?? this.balance,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      savings: savings ?? this.savings,
      investments: investments ?? this.investments,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}
