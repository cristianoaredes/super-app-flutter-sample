import 'package:equatable/equatable.dart';

import 'pix_key.dart';


class PixTransaction extends Equatable {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final PixTransactionType type;
  final PixTransactionStatus status;
  final String? endToEndId;
  final PixParticipant sender;
  final PixParticipant receiver;
  
  const PixTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.status,
    this.endToEndId,
    required this.sender,
    required this.receiver,
  });
  
  @override
  List<Object?> get props => [
    id,
    description,
    amount,
    date,
    type,
    status,
    endToEndId,
    sender,
    receiver,
  ];
  
  
  PixTransaction copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? date,
    PixTransactionType? type,
    PixTransactionStatus? status,
    String? endToEndId,
    PixParticipant? sender,
    PixParticipant? receiver,
  }) {
    return PixTransaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      endToEndId: endToEndId ?? this.endToEndId,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
    );
  }
  
  
  bool get isIncoming => type == PixTransactionType.incoming;
  
  
  bool get isOutgoing => type == PixTransactionType.outgoing;
  
  
  bool get isPending => status == PixTransactionStatus.pending;
  
  
  bool get isCompleted => status == PixTransactionStatus.completed;
  
  
  bool get isFailed => status == PixTransactionStatus.failed;
  
  
  bool get isReturned => status == PixTransactionStatus.returned;
}


enum PixTransactionType {
  incoming,
  outgoing,
}


enum PixTransactionStatus {
  pending,
  completed,
  failed,
  returned,
}


class PixParticipant extends Equatable {
  final String name;
  final String document;
  final String bank;
  final String? agency;
  final String? account;
  final PixKey? pixKey;
  
  const PixParticipant({
    required this.name,
    required this.document,
    required this.bank,
    this.agency,
    this.account,
    this.pixKey,
  });
  
  @override
  List<Object?> get props => [name, document, bank, agency, account, pixKey];
  
  
  PixParticipant copyWith({
    String? name,
    String? document,
    String? bank,
    String? agency,
    String? account,
    PixKey? pixKey,
  }) {
    return PixParticipant(
      name: name ?? this.name,
      document: document ?? this.document,
      bank: bank ?? this.bank,
      agency: agency ?? this.agency,
      account: account ?? this.account,
      pixKey: pixKey ?? this.pixKey,
    );
  }
}
