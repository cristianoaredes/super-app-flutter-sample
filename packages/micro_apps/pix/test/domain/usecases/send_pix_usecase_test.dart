import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pix/src/domain/entities/pix_key.dart';
import 'package:pix/src/domain/entities/pix_qr_code.dart';
import 'package:pix/src/domain/entities/pix_transaction.dart';
import 'package:pix/src/domain/repositories/pix_repository.dart';
import 'package:pix/src/domain/usecases/send_pix_usecase.dart';

class _RecordingPixRepository implements PixRepository {
  int sendCalls = 0;
  double? lastAmount;

  @override
  Future<PixTransaction> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  }) async {
    sendCalls += 1;
    lastAmount = amount;
    return PixTransaction(
      id: 'tx-1',
      description: description ?? '',
      amount: amount,
      date: DateTime(2024, 1, 1),
      type: PixTransactionType.outgoing,
      status: PixTransactionStatus.completed,
      sender: const PixParticipant(
        name: 'A',
        document: '1',
        bank: '001',
      ),
      receiver: PixParticipant(
        name: receiverName ?? 'B',
        document: '2',
        bank: '001',
      ),
    );
  }

  @override
  Future<void> deletePixKey(String id) => throw UnimplementedError();

  @override
  Future<PixQrCode> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<PixKey?> getPixKeyById(String id) => throw UnimplementedError();

  @override
  Future<List<PixKey>> getPixKeys() => throw UnimplementedError();

  @override
  Future<PixTransaction?> getPixTransactionById(String id) =>
      throw UnimplementedError();

  @override
  Future<List<PixTransaction>> getPixTransactions() =>
      throw UnimplementedError();

  @override
  Future<PixQrCode> readQrCode(String payload) => throw UnimplementedError();

  @override
  Future<PixQrCode> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<PixKey> registerPixKey(PixKeyType type, String value, {String? name}) =>
      throw UnimplementedError();
}

void main() {
  late _RecordingPixRepository repository;
  late SendPixUseCase useCase;

  setUp(() {
    repository = _RecordingPixRepository();
    useCase = SendPixUseCase(repository: repository);
  });

  test('rejects non-positive amount without calling repository', () async {
    expect(
      () => useCase.execute(
        pixKeyValue: '12345678900',
        pixKeyType: PixKeyType.cpf,
        amount: 0,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(repository.sendCalls, 0);
  });

  test('rejects empty pix key without calling repository', () async {
    expect(
      () => useCase.execute(
        pixKeyValue: '  ',
        pixKeyType: PixKeyType.email,
        amount: 10,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(repository.sendCalls, 0);
  });

  test('forwards a valid send to the repository', () async {
    final tx = await useCase.execute(
      pixKeyValue: '12345678900',
      pixKeyType: PixKeyType.cpf,
      amount: 25.5,
      description: 'almoço',
    );

    expect(tx.amount, 25.5);
    expect(repository.sendCalls, 1);
    expect(repository.lastAmount, 25.5);
  });
}
