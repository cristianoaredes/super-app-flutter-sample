import 'package:equatable/equatable.dart';


class Transaction extends Equatable {
  final String id;
  final String accountId;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final TransactionStatus status;
  final String? category;
  final String? reference;
  final Map<String, dynamic>? metadata;
  
  const Transaction({
    required this.id,
    required this.accountId,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    this.category,
    this.reference,
    this.metadata,
  });
  
  @override
  List<Object?> get props => [
    id,
    accountId,
    description,
    amount,
    date,
    type,
    status,
    category,
    reference,
    metadata,
  ];
  
  
  Transaction copyWith({
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
    return Transaction(
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
  
  
  bool get isIncoming => type == TransactionType.credit;
  
  
  bool get isOutgoing => type == TransactionType.debit;
  
  
  bool get isPending => status == TransactionStatus.pending;
  
  
  bool get isCompleted => status == TransactionStatus.completed;
  
  
  bool get isFailed => status == TransactionStatus.failed;
  
  
  bool get isCanceled => status == TransactionStatus.canceled;
}


enum TransactionType {
  credit,
  debit,
}


enum TransactionStatus {
  pending,
  completed,
  failed,
  canceled,
}
