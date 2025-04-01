import 'package:equatable/equatable.dart';

import '../../domain/entities/pix_key.dart';


abstract class PixEvent extends Equatable {
  const PixEvent();
  
  @override
  List<Object?> get props => [];
}


class LoadPixKeysEvent extends PixEvent {
  const LoadPixKeysEvent();
}


class RegisterPixKeyEvent extends PixEvent {
  final PixKeyType type;
  final String value;
  final String? name;
  
  const RegisterPixKeyEvent({
    required this.type,
    required this.value,
    this.name,
  });
  
  @override
  List<Object?> get props => [type, value, name];
}


class DeletePixKeyEvent extends PixEvent {
  final String id;
  
  const DeletePixKeyEvent({required this.id});
  
  @override
  List<Object?> get props => [id];
}


class LoadPixTransactionsEvent extends PixEvent {
  const LoadPixTransactionsEvent();
}


class LoadPixTransactionEvent extends PixEvent {
  final String id;
  
  const LoadPixTransactionEvent({required this.id});
  
  @override
  List<Object?> get props => [id];
}


class SendPixEvent extends PixEvent {
  final String pixKeyValue;
  final PixKeyType pixKeyType;
  final double amount;
  final String? description;
  final String? receiverName;
  
  const SendPixEvent({
    required this.pixKeyValue,
    required this.pixKeyType,
    required this.amount,
    this.description,
    this.receiverName,
  });
  
  @override
  List<Object?> get props => [pixKeyValue, pixKeyType, amount, description, receiverName];
}


class ReceivePixEvent extends PixEvent {
  final String pixKeyId;
  final double? amount;
  final String? description;
  final bool isStatic;
  final DateTime? expiresAt;
  
  const ReceivePixEvent({
    required this.pixKeyId,
    this.amount,
    this.description,
    this.isStatic = false,
    this.expiresAt,
  });
  
  @override
  List<Object?> get props => [pixKeyId, amount, description, isStatic, expiresAt];
}


class GenerateQrCodeEvent extends PixEvent {
  final String pixKeyId;
  final double? amount;
  final String? description;
  final bool isStatic;
  final DateTime? expiresAt;
  
  const GenerateQrCodeEvent({
    required this.pixKeyId,
    this.amount,
    this.description,
    this.isStatic = false,
    this.expiresAt,
  });
  
  @override
  List<Object?> get props => [pixKeyId, amount, description, isStatic, expiresAt];
}


class ReadQrCodeEvent extends PixEvent {
  final String payload;
  
  const ReadQrCodeEvent({required this.payload});
  
  @override
  List<Object?> get props => [payload];
}
