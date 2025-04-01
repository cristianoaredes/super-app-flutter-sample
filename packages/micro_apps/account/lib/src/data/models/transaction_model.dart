import '../../domain/entities/transaction.dart';


class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.accountId,
    required super.description,
    required super.amount,
    required super.date,
    required super.type,
    required super.status,
    super.category,
    super.reference,
    super.metadata,
  });
  
  
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      type: _parseTransactionType(json['type'] as String),
      status: _parseTransactionStatus(json['status'] as String),
      category: json['category'] as String?,
      reference: json['reference'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': _transactionTypeToString(type),
      'status': _transactionStatusToString(status),
      'category': category,
      'reference': reference,
      'metadata': metadata,
    };
  }
  
  
  @override
  TransactionModel copyWith({
    String? id,
    String? accountId,
    String? description,
    double? amount,
    DateTime? date,
    TransactionType? type,
    TransactionStatus? status,
    String? category,
    String? reference,
    Map<String, dynamic>? metadata,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      category: category ?? this.category,
      reference: reference ?? this.reference,
      metadata: metadata ?? this.metadata,
    );
  }
  
  
  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'credit':
        return TransactionType.credit;
      case 'debit':
        return TransactionType.debit;
      default:
        return TransactionType.debit;
    }
  }
  
  
  static String _transactionTypeToString(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return 'credit';
      case TransactionType.debit:
        return 'debit';
    }
  }
  
  
  static TransactionStatus _parseTransactionStatus(String status) {
    switch (status) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'canceled':
        return TransactionStatus.canceled;
      default:
        return TransactionStatus.pending;
    }
  }
  
  
  static String _transactionStatusToString(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'pending';
      case TransactionStatus.completed:
        return 'completed';
      case TransactionStatus.failed:
        return 'failed';
      case TransactionStatus.canceled:
        return 'canceled';
    }
  }
}
