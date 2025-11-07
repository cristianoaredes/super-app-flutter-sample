import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pix/src/domain/entities/pix_key.dart';
import 'package:pix/src/domain/entities/pix_qr_code.dart';
import 'package:pix/src/domain/entities/pix_transaction.dart';
import 'package:pix/src/domain/usecases/delete_pix_key_usecase.dart';
import 'package:pix/src/domain/usecases/generate_qr_code_usecase.dart';
import 'package:pix/src/domain/usecases/get_pix_keys_usecase.dart';
import 'package:pix/src/domain/usecases/read_qr_code_usecase.dart';
import 'package:pix/src/domain/usecases/receive_pix_usecase.dart';
import 'package:pix/src/domain/usecases/register_pix_key_usecase.dart';
import 'package:pix/src/domain/usecases/send_pix_usecase.dart';
import 'package:pix/src/presentation/bloc/pix_bloc.dart';
import 'package:pix/src/presentation/bloc/pix_event.dart';
import 'package:pix/src/presentation/bloc/pix_state.dart';

import 'pix_bloc_test.mocks.dart';

@GenerateMocks([
  GetPixKeysUseCase,
  RegisterPixKeyUseCase,
  DeletePixKeyUseCase,
  SendPixUseCase,
  ReceivePixUseCase,
  GenerateQrCodeUseCase,
  ReadQrCodeUseCase,
  AnalyticsService,
])
void main() {
  late PixBloc pixBloc;
  late MockGetPixKeysUseCase mockGetPixKeysUseCase;
  late MockRegisterPixKeyUseCase mockRegisterPixKeyUseCase;
  late MockDeletePixKeyUseCase mockDeletePixKeyUseCase;
  late MockSendPixUseCase mockSendPixUseCase;
  late MockReceivePixUseCase mockReceivePixUseCase;
  late MockGenerateQrCodeUseCase mockGenerateQrCodeUseCase;
  late MockReadQrCodeUseCase mockReadQrCodeUseCase;
  late MockAnalyticsService mockAnalyticsService;

  // Test data
  final testPixKey = PixKey(
    id: '1',
    value: '12345678900',
    type: PixKeyType.cpf,
    name: 'Test Key',
    createdAt: DateTime(2024, 1, 1),
    isActive: true,
  );

  final testPixKeys = [testPixKey];

  final testParticipant = PixParticipant(
    name: 'John Doe',
    document: '12345678900',
    bank: 'Premium Bank',
    agency: '0001',
    account: '12345-6',
    pixKey: testPixKey,
  );

  final testTransaction = PixTransaction(
    id: 'tx1',
    description: 'Test payment',
    amount: 100.0,
    date: DateTime(2024, 1, 1),
    type: PixTransactionType.outgoing,
    status: PixTransactionStatus.completed,
    endToEndId: 'E123456789',
    sender: testParticipant,
    receiver: testParticipant,
  );

  final testTransactions = [testTransaction];

  final testQrCode = PixQrCode(
    id: 'qr1',
    payload: 'test_payload',
    pixKey: testPixKey,
    amount: 50.0,
    description: 'Test QR',
    createdAt: DateTime(2024, 1, 1),
    expiresAt: DateTime(2024, 1, 2),
    isStatic: false,
  );

  setUp(() {
    mockGetPixKeysUseCase = MockGetPixKeysUseCase();
    mockRegisterPixKeyUseCase = MockRegisterPixKeyUseCase();
    mockDeletePixKeyUseCase = MockDeletePixKeyUseCase();
    mockSendPixUseCase = MockSendPixUseCase();
    mockReceivePixUseCase = MockReceivePixUseCase();
    mockGenerateQrCodeUseCase = MockGenerateQrCodeUseCase();
    mockReadQrCodeUseCase = MockReadQrCodeUseCase();
    mockAnalyticsService = MockAnalyticsService();

    pixBloc = PixBloc(
      getPixKeysUseCase: mockGetPixKeysUseCase,
      registerPixKeyUseCase: mockRegisterPixKeyUseCase,
      deletePixKeyUseCase: mockDeletePixKeyUseCase,
      sendPixUseCase: mockSendPixUseCase,
      receivePixUseCase: mockReceivePixUseCase,
      generateQrCodeUseCase: mockGenerateQrCodeUseCase,
      readQrCodeUseCase: mockReadQrCodeUseCase,
      analyticsService: mockAnalyticsService,
    );

    // Default stubs for analytics
    when(mockAnalyticsService.trackEvent(any, any))
        .thenAnswer((_) async => {});
    when(mockAnalyticsService.trackError(any, any))
        .thenAnswer((_) async => {});
  });

  tearDown(() {
    pixBloc.close();
  });

  group('PixBloc - LoadPixKeysEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixCompositeState with PixKeysLoadingState, PixKeysLoadedState] when load succeeds',
      build: () {
        when(mockGetPixKeysUseCase.execute())
            .thenAnswer((_) async => testPixKeys);
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixKeysEvent()),
      expect: () => [
        isA<PixCompositeState>()
            .having((s) => s.keysState, 'keysState', isA<PixKeysLoadingState>()),
        isA<PixCompositeState>()
            .having((s) => s.keysState, 'keysState', isA<PixKeysLoadedState>())
            .having(
              (s) => (s.keysState as PixKeysLoadedState).keys,
              'keys',
              testPixKeys,
            ),
      ],
      verify: (_) {
        verify(mockGetPixKeysUseCase.execute()).called(1);
        verify(mockAnalyticsService.trackEvent('pix_keys_load', any)).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixCompositeState with PixKeysLoadingState, PixKeysErrorState] when load fails',
      build: () {
        when(mockGetPixKeysUseCase.execute())
            .thenThrow(Exception('Failed to load keys'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixKeysEvent()),
      expect: () => [
        isA<PixCompositeState>()
            .having((s) => s.keysState, 'keysState', isA<PixKeysLoadingState>()),
        isA<PixCompositeState>()
            .having((s) => s.keysState, 'keysState', isA<PixKeysErrorState>())
            .having(
              (s) => (s.keysState as PixKeysErrorState).message,
              'message',
              contains('Failed to load keys'),
            ),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_keys_load_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - RegisterPixKeyEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixKeyRegisteringState, PixKeyRegisteredState] when registration succeeds',
      build: () {
        when(mockRegisterPixKeyUseCase.execute(
          any,
          any,
          name: anyNamed('name'),
        )).thenAnswer((_) async => testPixKey);
        return pixBloc;
      },
      act: (bloc) => bloc.add(RegisterPixKeyEvent(
        type: PixKeyType.cpf,
        value: '12345678900',
        name: 'Test Key',
      )),
      expect: () => [
        const PixKeyRegisteringState(),
        PixKeyRegisteredState(key: testPixKey),
      ],
      verify: (_) {
        verify(mockRegisterPixKeyUseCase.execute(
          PixKeyType.cpf,
          '12345678900',
          name: 'Test Key',
        )).called(1);
        verify(mockAnalyticsService.trackEvent('pix_key_register', any))
            .called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixKeyRegisteringState, PixKeysErrorState] when registration fails',
      build: () {
        when(mockRegisterPixKeyUseCase.execute(
          any,
          any,
          name: anyNamed('name'),
        )).thenThrow(Exception('Registration failed'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(RegisterPixKeyEvent(
        type: PixKeyType.email,
        value: 'test@example.com',
      )),
      expect: () => [
        const PixKeyRegisteringState(),
        isA<PixKeysErrorState>()
            .having((s) => s.message, 'message', contains('Registration failed')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_key_register_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - DeletePixKeyEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixKeyDeletingState, PixKeyDeletedState] when deletion succeeds',
      build: () {
        when(mockDeletePixKeyUseCase.execute(any))
            .thenAnswer((_) async => {});
        return pixBloc;
      },
      act: (bloc) => bloc.add(const DeletePixKeyEvent(id: '1')),
      expect: () => [
        const PixKeyDeletingState(),
        const PixKeyDeletedState(id: '1'),
      ],
      verify: (_) {
        verify(mockDeletePixKeyUseCase.execute('1')).called(1);
        verify(mockAnalyticsService.trackEvent('pix_key_delete', any)).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixKeyDeletingState, PixKeysErrorState] when deletion fails',
      build: () {
        when(mockDeletePixKeyUseCase.execute(any))
            .thenThrow(Exception('Deletion failed'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const DeletePixKeyEvent(id: '1')),
      expect: () => [
        const PixKeyDeletingState(),
        isA<PixKeysErrorState>()
            .having((s) => s.message, 'message', contains('Deletion failed')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_key_delete_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - LoadPixTransactionsEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixCompositeState with PixTransactionsLoadingState, PixTransactionsLoadedState] when load succeeds',
      build: () {
        when(mockSendPixUseCase.getPixTransactions())
            .thenAnswer((_) async => testTransactions);
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixTransactionsEvent()),
      expect: () => [
        isA<PixCompositeState>().having(
          (s) => s.transactionsState,
          'transactionsState',
          isA<PixTransactionsLoadingState>(),
        ),
        isA<PixCompositeState>()
            .having(
              (s) => s.transactionsState,
              'transactionsState',
              isA<PixTransactionsLoadedState>(),
            )
            .having(
              (s) => (s.transactionsState as PixTransactionsLoadedState)
                  .transactions,
              'transactions',
              testTransactions,
            ),
      ],
      verify: (_) {
        verify(mockSendPixUseCase.getPixTransactions()).called(1);
        verify(mockAnalyticsService.trackEvent('pix_transactions_load', any))
            .called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixCompositeState with PixTransactionsLoadingState, PixTransactionsErrorState] when load fails',
      build: () {
        when(mockSendPixUseCase.getPixTransactions())
            .thenThrow(Exception('Failed to load transactions'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixTransactionsEvent()),
      expect: () => [
        isA<PixCompositeState>().having(
          (s) => s.transactionsState,
          'transactionsState',
          isA<PixTransactionsLoadingState>(),
        ),
        isA<PixCompositeState>()
            .having(
              (s) => s.transactionsState,
              'transactionsState',
              isA<PixTransactionsErrorState>(),
            )
            .having(
              (s) => (s.transactionsState as PixTransactionsErrorState).message,
              'message',
              contains('Failed to load transactions'),
            ),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError(
          'pix_transactions_load_error',
          any,
        )).called(1);
      },
    );
  });

  group('PixBloc - LoadPixTransactionEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixTransactionLoadingState, PixTransactionLoadedState] when load succeeds',
      build: () {
        when(mockSendPixUseCase.getPixTransactionById(any))
            .thenAnswer((_) async => testTransaction);
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixTransactionEvent(id: 'tx1')),
      expect: () => [
        const PixTransactionLoadingState(),
        PixTransactionLoadedState(transaction: testTransaction),
      ],
      verify: (_) {
        verify(mockSendPixUseCase.getPixTransactionById('tx1')).called(1);
        verify(mockAnalyticsService.trackEvent('pix_transaction_load', any))
            .called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixTransactionLoadingState, PixTransactionErrorState] when transaction not found',
      build: () {
        when(mockSendPixUseCase.getPixTransactionById(any))
            .thenAnswer((_) async => null);
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixTransactionEvent(id: 'invalid')),
      expect: () => [
        const PixTransactionLoadingState(),
        const PixTransactionErrorState(message: 'Transação não encontrada'),
      ],
      verify: (_) {
        verify(mockSendPixUseCase.getPixTransactionById('invalid')).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixTransactionLoadingState, PixTransactionErrorState] when load fails',
      build: () {
        when(mockSendPixUseCase.getPixTransactionById(any))
            .thenThrow(Exception('Load failed'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const LoadPixTransactionEvent(id: 'tx1')),
      expect: () => [
        const PixTransactionLoadingState(),
        isA<PixTransactionErrorState>()
            .having((s) => s.message, 'message', contains('Load failed')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_transaction_load_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - SendPixEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixSendingState, PixSentState] when send succeeds',
      build: () {
        when(mockSendPixUseCase.execute(
          pixKeyValue: anyNamed('pixKeyValue'),
          pixKeyType: anyNamed('pixKeyType'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          receiverName: anyNamed('receiverName'),
        )).thenAnswer((_) async => testTransaction);
        return pixBloc;
      },
      act: (bloc) => bloc.add(SendPixEvent(
        pixKeyValue: '12345678900',
        pixKeyType: PixKeyType.cpf,
        amount: 100.0,
        description: 'Test payment',
        receiverName: 'John Doe',
      )),
      expect: () => [
        const PixSendingState(),
        PixSentState(transaction: testTransaction),
      ],
      verify: (_) {
        verify(mockSendPixUseCase.execute(
          pixKeyValue: '12345678900',
          pixKeyType: PixKeyType.cpf,
          amount: 100.0,
          description: 'Test payment',
          receiverName: 'John Doe',
        )).called(1);
        verify(mockAnalyticsService.trackEvent('pix_send', any)).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixSendingState, PixSendErrorState] when send fails',
      build: () {
        when(mockSendPixUseCase.execute(
          pixKeyValue: anyNamed('pixKeyValue'),
          pixKeyType: anyNamed('pixKeyType'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          receiverName: anyNamed('receiverName'),
        )).thenThrow(Exception('Insufficient funds'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(SendPixEvent(
        pixKeyValue: '12345678900',
        pixKeyType: PixKeyType.cpf,
        amount: 1000000.0,
      )),
      expect: () => [
        const PixSendingState(),
        isA<PixSendErrorState>()
            .having((s) => s.message, 'message', contains('Insufficient funds')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_send_error', any)).called(1);
      },
    );
  });

  group('PixBloc - ReceivePixEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeGeneratingState, PixQrCodeGeneratedState] when QR code generation succeeds',
      build: () {
        when(mockReceivePixUseCase.execute(
          pixKeyId: anyNamed('pixKeyId'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          isStatic: anyNamed('isStatic'),
          expiresAt: anyNamed('expiresAt'),
        )).thenAnswer((_) async => testQrCode);
        return pixBloc;
      },
      act: (bloc) => bloc.add(ReceivePixEvent(
        pixKeyId: '1',
        amount: 50.0,
        description: 'Test QR',
        isStatic: false,
      )),
      expect: () => [
        const PixQrCodeGeneratingState(),
        PixQrCodeGeneratedState(qrCode: testQrCode),
      ],
      verify: (_) {
        verify(mockReceivePixUseCase.execute(
          pixKeyId: '1',
          amount: 50.0,
          description: 'Test QR',
          isStatic: false,
          expiresAt: null,
        )).called(1);
        verify(mockAnalyticsService.trackEvent('pix_receive', any)).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeGeneratingState, PixQrCodeGenerateErrorState] when generation fails',
      build: () {
        when(mockReceivePixUseCase.execute(
          pixKeyId: anyNamed('pixKeyId'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          isStatic: anyNamed('isStatic'),
          expiresAt: anyNamed('expiresAt'),
        )).thenThrow(Exception('Generation failed'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const ReceivePixEvent(pixKeyId: '1')),
      expect: () => [
        const PixQrCodeGeneratingState(),
        isA<PixQrCodeGenerateErrorState>()
            .having((s) => s.message, 'message', contains('Generation failed')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_receive_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - GenerateQrCodeEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeGeneratingState, PixQrCodeGeneratedState] when generation succeeds',
      build: () {
        when(mockGenerateQrCodeUseCase.execute(
          pixKeyId: anyNamed('pixKeyId'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          isStatic: anyNamed('isStatic'),
          expiresAt: anyNamed('expiresAt'),
        )).thenAnswer((_) async => testQrCode);
        return pixBloc;
      },
      act: (bloc) => bloc.add(GenerateQrCodeEvent(
        pixKeyId: '1',
        amount: 50.0,
        isStatic: true,
      )),
      expect: () => [
        const PixQrCodeGeneratingState(),
        PixQrCodeGeneratedState(qrCode: testQrCode),
      ],
      verify: (_) {
        verify(mockGenerateQrCodeUseCase.execute(
          pixKeyId: '1',
          amount: 50.0,
          description: null,
          isStatic: true,
          expiresAt: null,
        )).called(1);
        verify(mockAnalyticsService.trackEvent('pix_qrcode_generate', any))
            .called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeGeneratingState, PixQrCodeGenerateErrorState] when generation fails',
      build: () {
        when(mockGenerateQrCodeUseCase.execute(
          pixKeyId: anyNamed('pixKeyId'),
          amount: anyNamed('amount'),
          description: anyNamed('description'),
          isStatic: anyNamed('isStatic'),
          expiresAt: anyNamed('expiresAt'),
        )).thenThrow(Exception('QR generation failed'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const GenerateQrCodeEvent(pixKeyId: '1')),
      expect: () => [
        const PixQrCodeGeneratingState(),
        isA<PixQrCodeGenerateErrorState>()
            .having((s) => s.message, 'message', contains('QR generation failed')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_qrcode_generate_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - ReadQrCodeEvent', () {
    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeReadingState, PixQrCodeReadState] when reading succeeds',
      build: () {
        when(mockReadQrCodeUseCase.execute(any))
            .thenAnswer((_) async => testQrCode);
        return pixBloc;
      },
      act: (bloc) => bloc.add(const ReadQrCodeEvent(payload: 'test_payload')),
      expect: () => [
        const PixQrCodeReadingState(),
        PixQrCodeReadState(qrCode: testQrCode),
      ],
      verify: (_) {
        verify(mockReadQrCodeUseCase.execute('test_payload')).called(1);
        verify(mockAnalyticsService.trackEvent('pix_qrcode_read', any)).called(1);
      },
    );

    blocTest<PixBloc, PixState>(
      'emits [PixQrCodeReadingState, PixQrCodeReadErrorState] when reading fails',
      build: () {
        when(mockReadQrCodeUseCase.execute(any))
            .thenThrow(Exception('Invalid QR code'));
        return pixBloc;
      },
      act: (bloc) => bloc.add(const ReadQrCodeEvent(payload: 'invalid')),
      expect: () => [
        const PixQrCodeReadingState(),
        isA<PixQrCodeReadErrorState>()
            .having((s) => s.message, 'message', contains('Invalid QR code')),
      ],
      verify: (_) {
        verify(mockAnalyticsService.trackError('pix_qrcode_read_error', any))
            .called(1);
      },
    );
  });

  group('PixBloc - Analytics Tracking', () {
    test('tracks analytics for all successful operations', () async {
      // Setup mocks for successful operations
      when(mockGetPixKeysUseCase.execute())
          .thenAnswer((_) async => testPixKeys);

      // Add event and wait
      pixBloc.add(const LoadPixKeysEvent());
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify analytics was called
      verify(mockAnalyticsService.trackEvent('pix_keys_load', any)).called(1);
    });

    test('tracks errors for all failed operations', () async {
      // Setup mocks for failed operations
      when(mockSendPixUseCase.execute(
        pixKeyValue: anyNamed('pixKeyValue'),
        pixKeyType: anyNamed('pixKeyType'),
        amount: anyNamed('amount'),
        description: anyNamed('description'),
        receiverName: anyNamed('receiverName'),
      )).thenThrow(Exception('Network error'));

      // Add event and wait
      pixBloc.add(SendPixEvent(
        pixKeyValue: '123',
        pixKeyType: PixKeyType.random,
        amount: 10.0,
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify error tracking was called
      verify(mockAnalyticsService.trackError('pix_send_error', any)).called(1);
    });
  });
}
