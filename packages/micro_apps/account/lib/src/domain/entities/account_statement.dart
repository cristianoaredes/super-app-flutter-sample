import 'package:equatable/equatable.dart';

import 'transaction.dart';


class AccountStatement extends Equatable {
  final String accountId;
  final DateTime startDate;
  final DateTime endDate;
  final double initialBalance;
  final double finalBalance;
  final List<Transaction> transactions;
  
  const AccountStatement({
    required this.accountId,
    required this.startDate,
    required this.endDate,
    required this.initialBalance,
    required this.finalBalance,
    required this.transactions,
  });
  
  @override
  List<Object?> get props => [
    accountId,
    startDate,
    endDate,
    initialBalance,
    finalBalance,
    transactions,
  ];
  
  
  AccountStatement copyWith({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    double? initialBalance,
    double? finalBalance,
    List<Transaction>? transactions,
  }) {
    return AccountStatement(
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      initialBalance: initialBalance ?? this.initialBalance,
      finalBalance: finalBalance ?? this.finalBalance,
      transactions: transactions ?? this.transactions,
    );
  }
  
  
  List<Transaction> get sortedTransactions {
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
  
  
  double get totalCredits {
    return transactions
        .where((transaction) => transaction.isIncoming && transaction.isCompleted)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }
  
  
  double get totalDebits {
    return transactions
        .where((transaction) => transaction.isOutgoing && transaction.isCompleted)
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }
  
  
  List<Transaction> getTransactionsByType(TransactionType type) {
    return transactions.where((transaction) => transaction.type == type).toList();
  }
  
  
  List<Transaction> getTransactionsByCategory(String category) {
    return transactions.where((transaction) => transaction.category == category).toList();
  }
  
  
  List<Transaction> getTransactionsByStatus(TransactionStatus status) {
    return transactions.where((transaction) => transaction.status == status).toList();
  }
}
