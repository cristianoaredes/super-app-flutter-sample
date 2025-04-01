import 'package:equatable/equatable.dart';

import 'card_transaction.dart';


class CardStatement extends Equatable {
  final String cardId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalSpent;
  final double totalPayments;
  final double totalRefunds;
  final double totalFees;
  final List<CardTransaction> transactions;
  final Map<String, double> categoryDistribution;
  
  const CardStatement({
    required this.cardId,
    required this.startDate,
    required this.endDate,
    required this.totalSpent,
    required this.totalPayments,
    required this.totalRefunds,
    required this.totalFees,
    required this.transactions,
    required this.categoryDistribution,
  });
  
  @override
  List<Object?> get props => [
    cardId,
    startDate,
    endDate,
    totalSpent,
    totalPayments,
    totalRefunds,
    totalFees,
    transactions,
    categoryDistribution,
  ];
  
  
  CardStatement copyWith({
    String? cardId,
    DateTime? startDate,
    DateTime? endDate,
    double? totalSpent,
    double? totalPayments,
    double? totalRefunds,
    double? totalFees,
    List<CardTransaction>? transactions,
    Map<String, double>? categoryDistribution,
  }) {
    return CardStatement(
      cardId: cardId ?? this.cardId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalSpent: totalSpent ?? this.totalSpent,
      totalPayments: totalPayments ?? this.totalPayments,
      totalRefunds: totalRefunds ?? this.totalRefunds,
      totalFees: totalFees ?? this.totalFees,
      transactions: transactions ?? this.transactions,
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
    );
  }
  
  
  double get balance => totalPayments + totalRefunds - totalSpent - totalFees;
  
  
  List<CardTransaction> get sortedTransactions {
    final sorted = List<CardTransaction>.from(transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
  
  
  List<CardTransaction> getTransactionsByType(CardTransactionType type) {
    return transactions.where((transaction) => transaction.type == type).toList();
  }
  
  
  List<CardTransaction> getTransactionsByCategory(String category) {
    return transactions.where((transaction) => transaction.category == category).toList();
  }
  
  
  List<CardTransaction> getTransactionsByStatus(CardTransactionStatus status) {
    return transactions.where((transaction) => transaction.status == status).toList();
  }
}
