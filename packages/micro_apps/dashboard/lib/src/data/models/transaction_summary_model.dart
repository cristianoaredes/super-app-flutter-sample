import '../../domain/entities/transaction_summary.dart';


class TransactionSummaryModel extends TransactionSummary {
  const TransactionSummaryModel({
    required super.recentTransactions,
    required super.categoryDistribution,
    required super.monthlyExpenses,
  });
  
  
  factory TransactionSummaryModel.fromJson(Map<String, dynamic> json) {
    final recentTransactionsJson = json['recent_transactions'] as List<dynamic>;
    final recentTransactions = recentTransactionsJson
        .map((transactionJson) => TransactionModel.fromJson(transactionJson as Map<String, dynamic>))
        .toList();
    
    final categoryDistributionJson = json['category_distribution'] as Map<String, dynamic>;
    final categoryDistribution = categoryDistributionJson.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    
    final monthlyExpensesJson = json['monthly_expenses'] as List<dynamic>;
    final monthlyExpenses = monthlyExpensesJson
        .map((expenseJson) => MonthlyExpenseModel.fromJson(expenseJson as Map<String, dynamic>))
        .toList();
    
    return TransactionSummaryModel(
      recentTransactions: recentTransactions,
      categoryDistribution: categoryDistribution,
      monthlyExpenses: monthlyExpenses,
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'recent_transactions': (recentTransactions as List<TransactionModel>)
          .map((transaction) => transaction.toJson())
          .toList(),
      'category_distribution': categoryDistribution,
      'monthly_expenses': (monthlyExpenses as List<MonthlyExpenseModel>)
          .map((expense) => expense.toJson())
          .toList(),
    };
  }
  
  
  @override
  TransactionSummaryModel copyWith({
    List<Transaction>? recentTransactions,
    Map<String, double>? categoryDistribution,
    List<MonthlyExpense>? monthlyExpenses,
  }) {
    return TransactionSummaryModel(
      recentTransactions: recentTransactions ?? this.recentTransactions,
      categoryDistribution: categoryDistribution ?? this.categoryDistribution,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
    );
  }
}


class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.title,
    required super.description,
    required super.amount,
    required super.date,
    required super.category,
    required super.type,
  });
  
  
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String,
      type: _parseTransactionType(json['type'] as String),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': _transactionTypeToString(type),
    };
  }
  
  
  @override
  TransactionModel copyWith({
    String? id,
    String? title,
    String? description,
    double? amount,
    DateTime? date,
    String? category,
    TransactionType? type,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
    );
  }
  
  
  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.expense;
    }
  }
  
  
  static String _transactionTypeToString(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
    }
  }
}


class MonthlyExpenseModel extends MonthlyExpense {
  const MonthlyExpenseModel({
    required super.month,
    required super.amount,
  });
  
  
  factory MonthlyExpenseModel.fromJson(Map<String, dynamic> json) {
    return MonthlyExpenseModel(
      month: json['month'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'amount': amount,
    };
  }
  
  
  @override
  MonthlyExpenseModel copyWith({
    String? month,
    double? amount,
  }) {
    return MonthlyExpenseModel(
      month: month ?? this.month,
      amount: amount ?? this.amount,
    );
  }
}
