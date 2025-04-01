import 'package:equatable/equatable.dart';

import '../../domain/entities/pix_key.dart';
import '../../domain/entities/pix_transaction.dart';
import '../../domain/entities/pix_qr_code.dart';


abstract class PixState extends Equatable {
  const PixState();
  
  @override
  List<Object?> get props => [];
}


class PixInitialState extends PixState {
  const PixInitialState();
}




class PixKeysLoadingState extends PixState {
  const PixKeysLoadingState();
}


class PixKeysLoadedState extends PixState {
  final List<PixKey> keys;
  
  const PixKeysLoadedState({required this.keys});
  
  @override
  List<Object?> get props => [keys];
}


class PixKeysErrorState extends PixState {
  final String message;
  
  const PixKeysErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}


class PixKeyRegisteringState extends PixState {
  const PixKeyRegisteringState();
}


class PixKeyRegisteredState extends PixState {
  final PixKey key;
  
  const PixKeyRegisteredState({required this.key});
  
  @override
  List<Object?> get props => [key];
}


class PixKeyDeletingState extends PixState {
  const PixKeyDeletingState();
}


class PixKeyDeletedState extends PixState {
  final String id;
  
  const PixKeyDeletedState({required this.id});
  
  @override
  List<Object?> get props => [id];
}




class PixTransactionsLoadingState extends PixState {
  const PixTransactionsLoadingState();
}


class PixTransactionsLoadedState extends PixState {
  final List<PixTransaction> transactions;
  
  const PixTransactionsLoadedState({required this.transactions});
  
  @override
  List<Object?> get props => [transactions];
}


class PixTransactionsErrorState extends PixState {
  final String message;
  
  const PixTransactionsErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}


class PixTransactionLoadingState extends PixState {
  const PixTransactionLoadingState();
}


class PixTransactionLoadedState extends PixState {
  final PixTransaction transaction;
  
  const PixTransactionLoadedState({required this.transaction});
  
  @override
  List<Object?> get props => [transaction];
}


class PixTransactionErrorState extends PixState {
  final String message;
  
  const PixTransactionErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}


class PixSendingState extends PixState {
  const PixSendingState();
}


class PixSentState extends PixState {
  final PixTransaction transaction;
  
  const PixSentState({required this.transaction});
  
  @override
  List<Object?> get props => [transaction];
}


class PixSendErrorState extends PixState {
  final String message;
  
  const PixSendErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}




class PixQrCodeGeneratingState extends PixState {
  const PixQrCodeGeneratingState();
}


class PixQrCodeGeneratedState extends PixState {
  final PixQrCode qrCode;
  
  const PixQrCodeGeneratedState({required this.qrCode});
  
  @override
  List<Object?> get props => [qrCode];
}


class PixQrCodeGenerateErrorState extends PixState {
  final String message;
  
  const PixQrCodeGenerateErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}


class PixQrCodeReadingState extends PixState {
  const PixQrCodeReadingState();
}


class PixQrCodeReadState extends PixState {
  final PixQrCode qrCode;
  
  const PixQrCodeReadState({required this.qrCode});
  
  @override
  List<Object?> get props => [qrCode];
}


class PixQrCodeReadErrorState extends PixState {
  final String message;
  
  const PixQrCodeReadErrorState({required this.message});
  
  @override
  List<Object?> get props => [message];
}
