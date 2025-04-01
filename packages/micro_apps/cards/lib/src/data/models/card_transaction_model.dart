import '../../domain/entities/card_transaction.dart';


class CardTransactionModel extends CardTransaction {
  const CardTransactionModel({
    required super.id,
    required super.cardId,
    required super.description,
    required super.merchant,
    required super.category,
    required super.amount,
    required super.date,
    required super.type,
    required super.status,
    super.authorizationCode,
  });
  
  
  factory CardTransactionModel.fromJson(Map<String, dynamic> json) {
    return CardTransactionModel(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      description: json['description'] as String,
      merchant: json['merchant'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      type: _parseTransactionType(json['type'] as String),
      status: _parseTransactionStatus(json['status'] as String),
      authorizationCode: json['authorization_code'] as String?,
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_id': cardId,
      'description': description,
      'merchant': merchant,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': _transactionTypeToString(type),
      'status': _transactionStatusToString(status),
      'authorization_code': authorizationCode,
    };
  }
  
  
  @override
  CardTransactionModel copyWith({
    String? id,
    String? cardId,
    String? description,
    String? merchant,
    String? category,
    double? amount,
    DateTime? date,
    CardTransactionType? type,
    CardTransactionStatus? status,
    String? authorizationCode,
  }) {
    return CardTransactionModel(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      description: description ?? this.description,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      authorizationCode: authorizationCode ?? this.authorizationCode,
    );
  }
  
  
  static CardTransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'purchase':
        return CardTransactionType.purchase;
      case 'payment':
        return CardTransactionType.payment;
      case 'refund':
        return CardTransactionType.refund;
      case 'withdrawal':
        return CardTransactionType.withdrawal;
      case 'fee':
        return CardTransactionType.fee;
      case 'adjustment':
        return CardTransactionType.adjustment;
      default:
        return CardTransactionType.purchase;
    }
  }
  
  
  static String _transactionTypeToString(CardTransactionType type) {
    switch (type) {
      case CardTransactionType.purchase:
        return 'purchase';
      case CardTransactionType.payment:
        return 'payment';
      case CardTransactionType.refund:
        return 'refund';
      case CardTransactionType.withdrawal:
        return 'withdrawal';
      case CardTransactionType.fee:
        return 'fee';
      case CardTransactionType.adjustment:
        return 'adjustment';
    }
  }
  
  
  static CardTransactionStatus _parseTransactionStatus(String status) {
    switch (status) {
      case 'pending':
        return CardTransactionStatus.pending;
      case 'approved':
        return CardTransactionStatus.approved;
      case 'declined':
        return CardTransactionStatus.declined;
      case 'canceled':
        return CardTransactionStatus.canceled;
      case 'refunded':
        return CardTransactionStatus.refunded;
      default:
        return CardTransactionStatus.pending;
    }
  }
  
  
  static String _transactionStatusToString(CardTransactionStatus status) {
    switch (status) {
      case CardTransactionStatus.pending:
        return 'pending';
      case CardTransactionStatus.approved:
        return 'approved';
      case CardTransactionStatus.declined:
        return 'declined';
      case CardTransactionStatus.canceled:
        return 'canceled';
      case CardTransactionStatus.refunded:
        return 'refunded';
    }
  }
}
