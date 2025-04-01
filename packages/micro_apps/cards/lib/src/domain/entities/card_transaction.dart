import 'package:equatable/equatable.dart';


class CardTransaction extends Equatable {
  final String id;
  final String cardId;
  final String description;
  final String merchant;
  final String category;
  final double amount;
  final DateTime date;
  final CardTransactionType type;
  final CardTransactionStatus status;
  final String? authorizationCode;
  
  const CardTransaction({
    required this.id,
    required this.cardId,
    required this.description,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    this.authorizationCode,
  });
  
  @override
  List<Object?> get props => [
    id,
    cardId,
    description,
    merchant,
    category,
    amount,
    date,
    type,
    status,
    authorizationCode,
  ];
  
  
  CardTransaction copyWith({
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
    return CardTransaction(
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
  
  
  bool get isPurchase => type == CardTransactionType.purchase;
  
  
  bool get isPayment => type == CardTransactionType.payment;
  
  
  bool get isRefund => type == CardTransactionType.refund;
  
  
  bool get isWithdrawal => type == CardTransactionType.withdrawal;
  
  
  bool get isPending => status == CardTransactionStatus.pending;
  
  
  bool get isApproved => status == CardTransactionStatus.approved;
  
  
  bool get isDeclined => status == CardTransactionStatus.declined;
}


enum CardTransactionType {
  purchase,
  payment,
  refund,
  withdrawal,
  fee,
  adjustment,
}


enum CardTransactionStatus {
  pending,
  approved,
  declined,
  canceled,
  refunded,
}
