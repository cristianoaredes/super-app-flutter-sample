import 'package:flutter/foundation.dart';

import '../../domain/entities/pix_key.dart';
import '../../domain/entities/pix_transaction.dart';
import '../models/pix_key_model.dart';
import '../models/pix_transaction_model.dart';
import '../models/pix_qr_code_model.dart';
import '../models/pix_participant_model.dart';
import 'pix_remote_datasource.dart';


class PixMockDataSource implements PixRemoteDataSource {
  PixMockDataSource();

  @override
  Future<List<PixKeyModel>> getPixKeys() async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.getPixKeys');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      PixKeyModel(
        id: 'key001',
        value: '12345678900',
        type: PixKeyType.cpf,
        name: 'CPF Principal',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
      PixKeyModel(
        id: 'key002',
        value: 'usuario@example.com',
        type: PixKeyType.email,
        name: 'Email Pessoal',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
      ),
      PixKeyModel(
        id: 'key003',
        value: '11987654321',
        type: PixKeyType.phone,
        name: 'Celular',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        isActive: true,
      ),
    ];
  }

  @override
  Future<PixKeyModel?> getPixKeyById(String id) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.getPixKeyById');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final keys = {
      'key001': PixKeyModel(
        id: 'key001',
        value: '12345678900',
        type: PixKeyType.cpf,
        name: 'CPF Principal',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
      'key002': PixKeyModel(
        id: 'key002',
        value: 'usuario@example.com',
        type: PixKeyType.email,
        name: 'Email Pessoal',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
      ),
      'key003': PixKeyModel(
        id: 'key003',
        value: '11987654321',
        type: PixKeyType.phone,
        name: 'Celular',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        isActive: true,
      ),
    };

    return keys[id];
  }

  @override
  Future<PixKeyModel> registerPixKey(PixKeyType type, String value,
      {String? name}) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.registerPixKey');
      print('Type: $type, Value: $value, Name: $name');
    }

    
    await Future.delayed(const Duration(milliseconds: 500));

    return PixKeyModel(
      id: 'key${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      value: value,
      name: name,
      createdAt: DateTime.now(),
      isActive: true,
    );
  }

  @override
  Future<void> deletePixKey(String id) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.deletePixKey');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    return;
  }

  @override
  Future<List<PixTransactionModel>> getPixTransactions() async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.getPixTransactions');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      PixTransactionModel(
        id: 'tx001',
        description: 'Pagamento de serviço',
        amount: 100.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: PixTransactionType.outgoing,
        status: PixTransactionStatus.completed,
        endToEndId: 'E123456789012345678901234',
        sender: _createSender(),
        receiver:
            _createReceiver('João Silva', 'joao@example.com', PixKeyType.email),
      ),
      PixTransactionModel(
        id: 'tx002',
        description: 'Reembolso',
        amount: 50.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: PixTransactionType.incoming,
        status: PixTransactionStatus.completed,
        endToEndId: 'E234567890123456789012345',
        sender: _createReceiver('Maria Souza', '98765432100', PixKeyType.cpf),
        receiver: _createSender(),
      ),
      PixTransactionModel(
        id: 'tx003',
        description: 'Divisão de conta',
        amount: 75.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
        type: PixTransactionType.outgoing,
        status: PixTransactionStatus.completed,
        endToEndId: 'E345678901234567890123456',
        sender: _createSender(),
        receiver:
            _createReceiver('Pedro Oliveira', '11987654321', PixKeyType.phone),
      ),
    ];
  }

  @override
  Future<PixTransactionModel?> getPixTransactionById(String id) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.getPixTransactionById');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final transactions = {
      'tx001': PixTransactionModel(
        id: 'tx001',
        description: 'Pagamento de serviço',
        amount: 100.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: PixTransactionType.outgoing,
        status: PixTransactionStatus.completed,
        endToEndId: 'E123456789012345678901234',
        sender: _createSender(),
        receiver:
            _createReceiver('João Silva', 'joao@example.com', PixKeyType.email),
      ),
      'tx002': PixTransactionModel(
        id: 'tx002',
        description: 'Reembolso',
        amount: 50.0,
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: PixTransactionType.incoming,
        status: PixTransactionStatus.completed,
        endToEndId: 'E234567890123456789012345',
        sender: _createReceiver('Maria Souza', '98765432100', PixKeyType.cpf),
        receiver: _createSender(),
      ),
    };

    return transactions[id];
  }

  @override
  Future<PixTransactionModel> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  }) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.sendPix');
      print(
          'Key Type: $pixKeyType, Key Value: $pixKeyValue, Amount: $amount, Description: $description, Receiver Name: $receiverName');
    }

    
    await Future.delayed(const Duration(milliseconds: 500));

    return PixTransactionModel(
      id: 'tx${DateTime.now().millisecondsSinceEpoch}',
      description: description ?? 'Transferência Pix',
      amount: amount,
      date: DateTime.now(),
      type: PixTransactionType.outgoing,
      status: PixTransactionStatus.completed,
      endToEndId: 'E${DateTime.now().millisecondsSinceEpoch}',
      sender: _createSender(),
      receiver: _createReceiver(
          receiverName ?? 'Destinatário', pixKeyValue, pixKeyType),
    );
  }

  @override
  Future<PixQrCodeModel> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.receivePixWithQrCode');
      print(
          'Pix Key ID: $pixKeyId, Amount: $amount, Description: $description, Is Static: $isStatic, Expires At: $expiresAt');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final pixKey = await getPixKeyById(pixKeyId);
    if (pixKey == null) {
      throw Exception('Chave Pix não encontrada');
    }

    
    final payload =
        _generateQrCodePayload(pixKey.value, pixKey.type, amount, description);

    return PixQrCodeModel(
      id: 'qr${DateTime.now().millisecondsSinceEpoch}',
      payload: payload,
      pixKey: pixKey,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      isStatic: isStatic,
    );
  }

  @override
  Future<PixQrCodeModel> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.generateQrCode');
      print(
          'Pix Key ID: $pixKeyId, Amount: $amount, Description: $description, Is Static: $isStatic, Expires At: $expiresAt');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final pixKey = await getPixKeyById(pixKeyId);
    if (pixKey == null) {
      throw Exception('Chave Pix não encontrada');
    }

    
    final payload =
        _generateQrCodePayload(pixKey.value, pixKey.type, amount, description);

    return PixQrCodeModel(
      id: 'qr${DateTime.now().millisecondsSinceEpoch}',
      payload: payload,
      pixKey: pixKey,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      isStatic: isStatic,
    );
  }

  @override
  Future<PixQrCodeModel> readQrCode(String payload) async {
    if (kDebugMode) {
      print('🌐 PixMockDataSource.readQrCode');
      print('Payload: $payload');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    
    final pixKey = PixKeyModel(
      id: 'key001',
      value: '12345678900',
      type: PixKeyType.cpf,
      name: 'CPF Principal',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      isActive: true,
    );

    
    double? amount;
    String? description;
    if (payload.contains(':')) {
      final parts = payload.split(':');
      if (parts.length > 1) {
        amount = double.tryParse(parts[1]);
      }
      if (parts.length > 2) {
        description = parts[2];
      }
    }

    return PixQrCodeModel(
      id: 'qr${DateTime.now().millisecondsSinceEpoch}',
      payload: payload,
      pixKey: pixKey,
      amount: amount,
      description: description,
      createdAt: DateTime.now(),
      expiresAt: null,
      isStatic: false,
    );
  }

  

  
  PixParticipantModel _createSender() {
    return PixParticipantModel(
      name: 'Usuário Teste',
      document: '12345678900',
      bank: 'Banco Digital',
      agency: '0001',
      account: '12345-6',
      pixKey: PixKeyModel(
        id: 'key002',
        value: 'usuario@example.com',
        type: PixKeyType.email,
        name: 'Email Pessoal',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
      ),
    );
  }

  
  PixParticipantModel _createReceiver(
      String name, String keyValue, PixKeyType keyType) {
    return PixParticipantModel(
      name: name,
      document: '98765432100',
      bank: 'Outro Banco',
      agency: '0002',
      account: '54321-0',
      pixKey: PixKeyModel(
        id: 'key${DateTime.now().millisecondsSinceEpoch}',
        value: keyValue,
        type: keyType,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
      ),
    );
  }

  
  String _generateQrCodePayload(String keyValue, PixKeyType keyType,
      double? amount, String? description) {
    final sb = StringBuffer('00020126');
    sb.write('0014BR.GOV.BCB.PIX');

    
    sb.write('01${keyValue.length.toString().padLeft(2, '0')}$keyValue');

    
    if (amount != null) {
      final amountStr = amount.toStringAsFixed(2);
      sb.write('0215$amountStr');
    }

    
    if (description != null && description.isNotEmpty) {
      sb.write(
          '0350${description.length.toString().padLeft(2, '0')}$description');
    }

    
    sb.write('5303986');

    return sb.toString();
  }
}
