import '../../domain/entities/account_statement.dart';
import '../../domain/entities/transaction.dart';
import 'transaction_model.dart';


class AccountStatementModel extends AccountStatement {
  const AccountStatementModel({
    required super.accountId,
    required super.startDate,
    required super.endDate,
    required super.initialBalance,
    required super.finalBalance,
    required super.transactions,
  });

  
  factory AccountStatementModel.fromJson(Map<String, dynamic> json) {
    final transactionsJson = json['transactions'] as List<dynamic>;
    final transactions = transactionsJson
        .map((transactionJson) =>
            TransactionModel.fromJson(transactionJson as Map<String, dynamic>))
        .toList();

    return AccountStatementModel(
      accountId: json['account_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      initialBalance: (json['initial_balance'] as num).toDouble(),
      finalBalance: (json['final_balance'] as num).toDouble(),
      transactions: transactions,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'account_id': accountId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'initial_balance': initialBalance,
      'final_balance': finalBalance,
      'transactions': transactions
          .map((transaction) => (transaction as TransactionModel).toJson())
          .toList(),
    };
  }

  
  @override
  AccountStatement copyWith({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    double? initialBalance,
    double? finalBalance,
    List<Transaction>? transactions,
  }) {
    return AccountStatementModel(
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      initialBalance: initialBalance ?? this.initialBalance,
      finalBalance: finalBalance ?? this.finalBalance,
      transactions: transactions ?? this.transactions,
    );
  }
}
