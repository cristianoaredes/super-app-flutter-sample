import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/pix_key.dart';
import '../models/pix_key_model.dart';
import '../models/pix_transaction_model.dart';
import '../models/pix_qr_code_model.dart';


abstract class PixRemoteDataSource {
  
  Future<List<PixKeyModel>> getPixKeys();

  
  Future<PixKeyModel?> getPixKeyById(String id);

  
  Future<PixKeyModel> registerPixKey(PixKeyType type, String value,
      {String? name});

  
  Future<void> deletePixKey(String id);

  
  Future<List<PixTransactionModel>> getPixTransactions();

  
  Future<PixTransactionModel?> getPixTransactionById(String id);

  
  Future<PixTransactionModel> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  });

  
  Future<PixQrCodeModel> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  });

  
  Future<PixQrCodeModel> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  });

  
  Future<PixQrCodeModel> readQrCode(String payload);
}


class PixRemoteDataSourceImpl implements PixRemoteDataSource {
  final ApiClient _apiClient;

  PixRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<PixKeyModel>> getPixKeys() async {
    final response = await _apiClient.get('/pix/keys');

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter as chaves Pix');
    }

    final keysJson = response.data as List<dynamic>;
    return keysJson
        .map((keyJson) => PixKeyModel.fromJson(keyJson as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PixKeyModel?> getPixKeyById(String id) async {
    final response = await _apiClient.get('/pix/keys/$id');

    if (response.statusCode != 200) {
      return null;
    }

    return PixKeyModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PixKeyModel> registerPixKey(PixKeyType type, String value,
      {String? name}) async {
    final response = await _apiClient.post(
      '/pix/keys',
      body: {
        'type': _pixKeyTypeToString(type),
        'value': value,
        'name': name,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao registrar a chave Pix');
    }

    return PixKeyModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deletePixKey(String id) async {
    final response = await _apiClient.delete('/pix/keys/$id');

    if (response.statusCode != 204) {
      throw Exception('Falha ao excluir a chave Pix');
    }
  }

  @override
  Future<List<PixTransactionModel>> getPixTransactions() async {
    final response = await _apiClient.get('/pix/transactions');

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter as transações Pix');
    }

    final transactionsJson = response.data as List<dynamic>;
    return transactionsJson
        .map((transactionJson) => PixTransactionModel.fromJson(
            transactionJson as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PixTransactionModel?> getPixTransactionById(String id) async {
    final response = await _apiClient.get('/pix/transactions/$id');

    if (response.statusCode != 200) {
      return null;
    }

    return PixTransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PixTransactionModel> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  }) async {
    final response = await _apiClient.post(
      '/pix/send',
      body: {
        'pix_key_value': pixKeyValue,
        'pix_key_type': _pixKeyTypeToString(pixKeyType),
        'amount': amount,
        'description': description,
        'receiver_name': receiverName,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao enviar o Pix');
    }

    return PixTransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PixQrCodeModel> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    final response = await _apiClient.post(
      '/pix/receive',
      body: {
        'pix_key_id': pixKeyId,
        'amount': amount,
        'description': description,
        'is_static': isStatic,
        'expires_at': expiresAt?.toIso8601String(),
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao gerar o QR Code Pix');
    }

    return PixQrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PixQrCodeModel> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    final response = await _apiClient.post(
      '/pix/qrcode/generate',
      body: {
        'pix_key_id': pixKeyId,
        'amount': amount,
        'description': description,
        'is_static': isStatic,
        'expires_at': expiresAt?.toIso8601String(),
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao gerar o QR Code Pix');
    }

    return PixQrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PixQrCodeModel> readQrCode(String payload) async {
    final response = await _apiClient.post(
      '/pix/qrcode/read',
      body: {
        'payload': payload,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao ler o QR Code Pix');
    }

    return PixQrCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  
  String _pixKeyTypeToString(PixKeyType type) {
    switch (type) {
      case PixKeyType.cpf:
        return 'cpf';
      case PixKeyType.cnpj:
        return 'cnpj';
      case PixKeyType.email:
        return 'email';
      case PixKeyType.phone:
        return 'phone';
      case PixKeyType.random:
        return 'random';
    }
  }
}
