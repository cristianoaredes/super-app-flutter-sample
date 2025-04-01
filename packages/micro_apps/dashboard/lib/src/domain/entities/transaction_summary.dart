import 'package:equatable/equatable.dart';


class TransactionSummary extends Equatable {
  final List<Transaction> recentTransactions;
  final Map<String, double> categoryDistribution;
  final List<MonthlyExpense> monthlyExpenses;

  const TransactionSummary({
    required this.recentTransactions,
    required this.categoryDistribution,
    required this.monthlyExpenses,
  });

  @override
  List<Object?> get props => [
        recentTransactions,
        categoryDistribution,
        monthlyExpenses,
      ];

  
  TransactionSummary copyWith({
    List<Transaction>? recentTransactions,
    Map<String, double>? categoryDistribution,
    List<MonthlyExpense>? monthlyExpenses,
  }) {
    return TransactionSummary(
      recentTransactions: recentTransactions ?? this.recentTransactions,
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
    );
  }
}


class Transaction extends Equatable {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final TransactionType type;

  const Transaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        amount,
        date,
        category,
        type,
      ];

  
  Transaction copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    DateTime? date,
    String? category,
    TransactionType? type,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
    );
  }
}


enum TransactionType {
  income,
  expense,
  transfer,
}


class MonthlyExpense extends Equatable {
  final String month;
  final double amount;

  const MonthlyExpense({
    required this.month,
    required this.amount,
  });

  @override
  List<Object?> get props => [month, amount];

  
  MonthlyExpense copyWith({
    String? month,
    double? amount,
  }) {
    return MonthlyExpense(
      month: month ?? this.month,
      amount: amount ?? this.amount,
    );
  }
}
