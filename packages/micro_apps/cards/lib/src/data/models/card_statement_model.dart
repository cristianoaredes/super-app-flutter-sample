import '../../domain/entities/card_statement.dart';
import '../../domain/entities/card_transaction.dart';
import 'card_transaction_model.dart';


class CardStatementModel extends CardStatement {
  const CardStatementModel({
    required super.cardId,
    required super.startDate,
    required super.endDate,
    required super.totalSpent,
    required super.totalPayments,
    required super.totalRefunds,
    required super.totalFees,
    required super.transactions,
    required super.categoryDistribution,
  });

  
  factory CardStatementModel.fromJson(Map<String, dynamic> json) {
    final transactionsJson = json['transactions'] as List<dynamic>;
    final transactions = transactionsJson
        .map((transactionJson) => CardTransactionModel.fromJson(
            transactionJson as Map<String, dynamic>))
        .toList();

    final categoryDistributionJson =
        json['category_distribution'] as Map<String, dynamic>;
    final categoryDistribution = categoryDistributionJson.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return CardStatementModel(
      cardId: json['card_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalSpent: (json['total_spent'] as num).toDouble(),
      totalPayments: (json['total_payments'] as num).toDouble(),
      totalRefunds: (json['total_refunds'] as num).toDouble(),
      totalFees: (json['total_fees'] as num).toDouble(),
      transactions: transactions,
      categoryDistribution: categoryDistribution,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'card_id': cardId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_spent': totalSpent,
      'total_payments': totalPayments,
      'total_refunds': totalRefunds,
      'total_fees': totalFees,
      'transactions': transactions
          .map((transaction) => (transaction as CardTransactionModel).toJson())
          .toList(),
      'category_distribution': categoryDistribution,
    };
  }

  
  @override
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
    return CardStatementModel(
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
}
