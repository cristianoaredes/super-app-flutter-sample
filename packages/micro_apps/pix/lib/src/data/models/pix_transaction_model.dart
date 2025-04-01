import '../../domain/entities/pix_transaction.dart';
import 'pix_participant_model.dart';


class PixTransactionModel extends PixTransaction {
  const PixTransactionModel({
    required super.id,
    required super.description,
    required super.amount,
    required super.date,
    required super.type,
    required super.status,
    super.endToEndId,
    required super.sender,
    required super.receiver,
  });
  
  
  factory PixTransactionModel.fromJson(Map<String, dynamic> json) {
    return PixTransactionModel(
      id: json['id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      type: _parsePixTransactionType(json['type'] as String),
      status: _parsePixTransactionStatus(json['status'] as String),
      endToEndId: json['end_to_end_id'] as String?,
      sender: PixParticipantModel.fromJson(json['sender'] as Map<String, dynamic>),
      receiver: PixParticipantModel.fromJson(json['receiver'] as Map<String, dynamic>),
    );
  }
  
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': _pixTransactionTypeToString(type),
      'status': _pixTransactionStatusToString(status),
      'end_to_end_id': endToEndId,
      'sender': (sender as PixParticipantModel).toJson(),
      'receiver': (receiver as PixParticipantModel).toJson(),
    };
  }
  
  
  @override
  PixTransactionModel copyWith({
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
    return PixTransactionModel(
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
  
  
  static PixTransactionType _parsePixTransactionType(String type) {
    switch (type) {
      case 'incoming':
        return PixTransactionType.incoming;
      case 'outgoing':
        return PixTransactionType.outgoing;
      default:
        return PixTransactionType.outgoing;
    }
  }
  
  
  static String _pixTransactionTypeToString(PixTransactionType type) {
    switch (type) {
      case PixTransactionType.incoming:
        return 'incoming';
      case PixTransactionType.outgoing:
        return 'outgoing';
    }
  }
  
  
  static PixTransactionStatus _parsePixTransactionStatus(String status) {
    switch (status) {
      case 'pending':
        return PixTransactionStatus.pending;
      case 'completed':
        return PixTransactionStatus.completed;
      case 'failed':
        return PixTransactionStatus.failed;
      case 'returned':
        return PixTransactionStatus.returned;
      default:
        return PixTransactionStatus.pending;
    }
  }
  
  
  static String _pixTransactionStatusToString(PixTransactionStatus status) {
    switch (status) {
      case PixTransactionStatus.pending:
        return 'pending';
      case PixTransactionStatus.completed:
        return 'completed';
      case PixTransactionStatus.failed:
        return 'failed';
      case PixTransactionStatus.returned:
        return 'returned';
    }
  }
}
