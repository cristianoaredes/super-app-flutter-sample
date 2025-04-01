import '../../domain/entities/account_summary.dart';


class AccountSummaryModel extends AccountSummary {
  const AccountSummaryModel({
    required super.accountId,
    required super.accountNumber,
    required super.agency,
    required super.balance,
    required super.income,
    required super.expenses,
    required super.savings,
    required super.investments,
    required super.lastUpdate,
  });
  
  
  factory AccountSummaryModel.fromJson(Map<String, dynamic> json) {
    return AccountSummaryModel(
      accountId: json['account_id'] as String,
      accountNumber: json['account_number'] as String,
      agency: json['agency'] as String,
      balance: (json['balance'] as num).toDouble(),
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      savings: (json['savings'] as num).toDouble(),
      investments: (json['investments'] as num).toDouble(),
      lastUpdate: DateTime.parse(json['last_update'] as String),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'account_number': accountNumber,
      'agency': agency,
      'balance': balance,
      'income': income,
      'expenses': expenses,
      'savings': savings,
      'investments': investments,
      'last_update': lastUpdate.toIso8601String(),
    };
  }
  
  
  @override
  AccountSummaryModel copyWith({
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
    return AccountSummaryModel(
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
