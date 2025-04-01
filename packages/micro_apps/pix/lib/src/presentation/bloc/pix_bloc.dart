import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_pix_keys_usecase.dart';
import '../../domain/usecases/register_pix_key_usecase.dart';
import '../../domain/usecases/delete_pix_key_usecase.dart';
import '../../domain/usecases/send_pix_usecase.dart';
import '../../domain/usecases/receive_pix_usecase.dart';
import '../../domain/usecases/generate_qr_code_usecase.dart';
import '../../domain/usecases/read_qr_code_usecase.dart';
import 'pix_event.dart';
import 'pix_state.dart';

class PixBloc extends Bloc<PixEvent, PixState> {
  final GetPixKeysUseCase _getPixKeysUseCase;
  final RegisterPixKeyUseCase _registerPixKeyUseCase;
  final DeletePixKeyUseCase _deletePixKeyUseCase;
  final SendPixUseCase _sendPixUseCase;
  final ReceivePixUseCase _receivePixUseCase;
  final GenerateQrCodeUseCase _generateQrCodeUseCase;
  final ReadQrCodeUseCase _readQrCodeUseCase;
  final AnalyticsService _analyticsService;

  PixBloc({
    required GetPixKeysUseCase getPixKeysUseCase,
    required RegisterPixKeyUseCase registerPixKeyUseCase,
    required DeletePixKeyUseCase deletePixKeyUseCase,
    required SendPixUseCase sendPixUseCase,
    required ReceivePixUseCase receivePixUseCase,
    required GenerateQrCodeUseCase generateQrCodeUseCase,
    required ReadQrCodeUseCase readQrCodeUseCase,
    required AnalyticsService analyticsService,
  })  : _getPixKeysUseCase = getPixKeysUseCase,
        _registerPixKeyUseCase = registerPixKeyUseCase,
        _deletePixKeyUseCase = deletePixKeyUseCase,
        _sendPixUseCase = sendPixUseCase,
        _receivePixUseCase = receivePixUseCase,
        _generateQrCodeUseCase = generateQrCodeUseCase,
        _readQrCodeUseCase = readQrCodeUseCase,
        _analyticsService = analyticsService,
        super(const PixCompositeState()) {
    on<LoadPixKeysEvent>(_onLoadPixKeys);
    on<RegisterPixKeyEvent>(_onRegisterPixKey);
    on<DeletePixKeyEvent>(_onDeletePixKey);
    on<LoadPixTransactionsEvent>(_onLoadPixTransactions);
    on<LoadPixTransactionEvent>(_onLoadPixTransaction);
    on<SendPixEvent>(_onSendPix);
    on<ReceivePixEvent>(_onReceivePix);
    on<GenerateQrCodeEvent>(_onGenerateQrCode);
    on<ReadQrCodeEvent>(_onReadQrCode);
  }

  Future<void> _onLoadPixKeys(
    LoadPixKeysEvent event,
    Emitter<PixState> emit,
  ) async {
    // Obter o estado atual como PixCompositeState
    final currentState = state as PixCompositeState;

    // Emitir um novo estado com keysState atualizado para loading
    emit(currentState.copyWith(
      keysState: const PixKeysLoadingState(),
    ));

    try {
      _analyticsService.trackEvent(
        'pix_keys_load',
        {},
      );

      final keys = await _getPixKeysUseCase.execute();

      // Emitir um novo estado com keysState atualizado para loaded
      emit(currentState.copyWith(
        keysState: PixKeysLoadedState(keys: keys),
      ));
    } catch (e) {
      _analyticsService.trackError(
        'pix_keys_load_error',
        e.toString(),
      );

      // Emitir um novo estado com keysState atualizado para error
      emit(currentState.copyWith(
        keysState: PixKeysErrorState(message: e.toString()),
      ));
    }
  }

  Future<void> _onRegisterPixKey(
    RegisterPixKeyEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixKeyRegisteringState());

    try {
      _analyticsService.trackEvent(
        'pix_key_register',
        {
          'type': event.type.toString(),
        },
      );

      final key = await _registerPixKeyUseCase.execute(
        event.type,
        event.value,
        name: event.name,
      );

      emit(PixKeyRegisteredState(key: key));
    } catch (e) {
      _analyticsService.trackError(
        'pix_key_register_error',
        e.toString(),
      );

      emit(PixKeysErrorState(message: e.toString()));
    }
  }

  Future<void> _onDeletePixKey(
    DeletePixKeyEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixKeyDeletingState());

    try {
      _analyticsService.trackEvent(
        'pix_key_delete',
        {
          'key_id': event.id,
        },
      );

      await _deletePixKeyUseCase.execute(event.id);

      emit(PixKeyDeletedState(id: event.id));
    } catch (e) {
      _analyticsService.trackError(
        'pix_key_delete_error',
        e.toString(),
      );

      emit(PixKeysErrorState(message: e.toString()));
    }
  }

  Future<void> _onLoadPixTransactions(
    LoadPixTransactionsEvent event,
    Emitter<PixState> emit,
  ) async {
    // Obter o estado atual como PixCompositeState
    final currentState = state as PixCompositeState;

    // Emitir um novo estado com transactionsState atualizado para loading
    emit(currentState.copyWith(
      transactionsState: const PixTransactionsLoadingState(),
    ));

    try {
      _analyticsService.trackEvent(
        'pix_transactions_load',
        {},
      );

      final transactions = await _sendPixUseCase.getPixTransactions();

      // Emitir um novo estado com transactionsState atualizado para loaded
      emit(currentState.copyWith(
        transactionsState:
            PixTransactionsLoadedState(transactions: transactions),
      ));
    } catch (e) {
      _analyticsService.trackError(
        'pix_transactions_load_error',
        e.toString(),
      );

      // Emitir um novo estado com transactionsState atualizado para error
      emit(currentState.copyWith(
        transactionsState: PixTransactionsErrorState(message: e.toString()),
      ));
    }
  }

  Future<void> _onLoadPixTransaction(
    LoadPixTransactionEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixTransactionLoadingState());

    try {
      _analyticsService.trackEvent(
        'pix_transaction_load',
        {
          'transaction_id': event.id,
        },
      );

      final transaction = await _sendPixUseCase.getPixTransactionById(event.id);

      if (transaction != null) {
        emit(PixTransactionLoadedState(transaction: transaction));
      } else {
        emit(const PixTransactionErrorState(
            message: 'Transação não encontrada'));
      }
    } catch (e) {
      _analyticsService.trackError(
        'pix_transaction_load_error',
        e.toString(),
      );

      emit(PixTransactionErrorState(message: e.toString()));
    }
  }

  Future<void> _onSendPix(
    SendPixEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixSendingState());

    try {
      _analyticsService.trackEvent(
        'pix_send',
        {
          'amount': event.amount,
          'key_type': event.pixKeyType.toString(),
        },
      );

      final transaction = await _sendPixUseCase.execute(
        pixKeyValue: event.pixKeyValue,
        pixKeyType: event.pixKeyType,
        amount: event.amount,
        description: event.description,
        receiverName: event.receiverName,
      );

      emit(PixSentState(transaction: transaction));
    } catch (e) {
      _analyticsService.trackError(
        'pix_send_error',
        e.toString(),
      );

      emit(PixSendErrorState(message: e.toString()));
    }
  }

  Future<void> _onReceivePix(
    ReceivePixEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixQrCodeGeneratingState());

    try {
      _analyticsService.trackEvent(
        'pix_receive',
        {
          'key_id': event.pixKeyId,
          'amount': event.amount,
          'is_static': event.isStatic,
        },
      );

      final qrCode = await _receivePixUseCase.execute(
        pixKeyId: event.pixKeyId,
        amount: event.amount,
        description: event.description,
        isStatic: event.isStatic,
        expiresAt: event.expiresAt,
      );

      emit(PixQrCodeGeneratedState(qrCode: qrCode));
    } catch (e) {
      _analyticsService.trackError(
        'pix_receive_error',
        e.toString(),
      );

      emit(PixQrCodeGenerateErrorState(message: e.toString()));
    }
  }

  Future<void> _onGenerateQrCode(
    GenerateQrCodeEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixQrCodeGeneratingState());

    try {
      _analyticsService.trackEvent(
        'pix_qrcode_generate',
        {
          'key_id': event.pixKeyId,
          'amount': event.amount,
          'is_static': event.isStatic,
        },
      );

      final qrCode = await _generateQrCodeUseCase.execute(
        pixKeyId: event.pixKeyId,
        amount: event.amount,
        description: event.description,
        isStatic: event.isStatic,
        expiresAt: event.expiresAt,
      );

      emit(PixQrCodeGeneratedState(qrCode: qrCode));
    } catch (e) {
      _analyticsService.trackError(
        'pix_qrcode_generate_error',
        e.toString(),
      );

      emit(PixQrCodeGenerateErrorState(message: e.toString()));
    }
  }

  Future<void> _onReadQrCode(
    ReadQrCodeEvent event,
    Emitter<PixState> emit,
  ) async {
    emit(const PixQrCodeReadingState());

    try {
      _analyticsService.trackEvent(
        'pix_qrcode_read',
        {},
      );

      final qrCode = await _readQrCodeUseCase.execute(event.payload);

      emit(PixQrCodeReadState(qrCode: qrCode));
    } catch (e) {
      _analyticsService.trackError(
        'pix_qrcode_read_error',
        e.toString(),
      );

      emit(PixQrCodeReadErrorState(message: e.toString()));
    }
  }
}
