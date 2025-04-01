import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';

import '../models/pix_key_model.dart';
import '../models/pix_transaction_model.dart';
import '../models/pix_qr_code_model.dart';


abstract class PixLocalDataSource {
  
  Future<List<PixKeyModel>?> getPixKeys();
  
  
  Future<void> savePixKeys(List<PixKeyModel> keys);
  
  
  Future<PixKeyModel?> getPixKeyById(String id);
  
  
  Future<void> savePixKey(PixKeyModel key);
  
  
  Future<void> deletePixKey(String id);
  
  
  Future<List<PixTransactionModel>?> getPixTransactions();
  
  
  Future<void> savePixTransactions(List<PixTransactionModel> transactions);
  
  
  Future<PixTransactionModel?> getPixTransactionById(String id);
  
  
  Future<void> savePixTransaction(PixTransactionModel transaction);
  
  
  Future<PixQrCodeModel?> getPixQrCodeById(String id);
  
  
  Future<void> savePixQrCode(PixQrCodeModel qrCode);
}


class PixLocalDataSourceImpl implements PixLocalDataSource {
  final StorageService _storageService;
  
  static const String _pixKeysKey = 'pix_keys';
  static const String _pixKeyPrefix = 'pix_key_';
  static const String _pixTransactionsKey = 'pix_transactions';
  static const String _pixTransactionPrefix = 'pix_transaction_';
  static const String _pixQrCodePrefix = 'pix_qrcode_';
  
  PixLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;
  
  @override
  Future<List<PixKeyModel>?> getPixKeys() async {
    final pixKeysJson = await _storageService.getValue<String>(_pixKeysKey);
    
    if (pixKeysJson == null) {
      return null;
    }
    
    try {
      final pixKeysListJson = jsonDecode(pixKeysJson) as List<dynamic>;
      return pixKeysListJson
          .map((pixKeyJson) => PixKeyModel.fromJson(pixKeyJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> savePixKeys(List<PixKeyModel> keys) async {
    final pixKeysJson = jsonEncode(
      keys.map((key) => key.toJson()).toList(),
    );
    await _storageService.setValue(_pixKeysKey, pixKeysJson);
    
    
    for (final key in keys) {
      await savePixKey(key);
    }
  }
  
  @override
  Future<PixKeyModel?> getPixKeyById(String id) async {
    final pixKeyJson = await _storageService.getValue<String>('$_pixKeyPrefix$id');
    
    if (pixKeyJson == null) {
      return null;
    }
    
    try {
      final pixKeyMap = jsonDecode(pixKeyJson) as Map<String, dynamic>;
      return PixKeyModel.fromJson(pixKeyMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> savePixKey(PixKeyModel key) async {
    final pixKeyJson = jsonEncode(key.toJson());
    await _storageService.setValue('$_pixKeyPrefix${key.id}', pixKeyJson);
  }
  
  @override
  Future<void> deletePixKey(String id) async {
    await _storageService.removeValue('$_pixKeyPrefix$id');
    
    
    final keys = await getPixKeys();
    if (keys != null) {
      final updatedKeys = keys.where((key) => key.id != id).toList();
      await savePixKeys(updatedKeys);
    }
  }
  
  @override
  Future<List<PixTransactionModel>?> getPixTransactions() async {
    final pixTransactionsJson = await _storageService.getValue<String>(_pixTransactionsKey);
    
    if (pixTransactionsJson == null) {
      return null;
    }
    
    try {
      final pixTransactionsListJson = jsonDecode(pixTransactionsJson) as List<dynamic>;
      return pixTransactionsListJson
          .map((pixTransactionJson) => PixTransactionModel.fromJson(pixTransactionJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> savePixTransactions(List<PixTransactionModel> transactions) async {
    final pixTransactionsJson = jsonEncode(
      transactions.map((transaction) => transaction.toJson()).toList(),
    );
    await _storageService.setValue(_pixTransactionsKey, pixTransactionsJson);
    
    
    for (final transaction in transactions) {
      await savePixTransaction(transaction);
    }
  }
  
  @override
  Future<PixTransactionModel?> getPixTransactionById(String id) async {
    final pixTransactionJson = await _storageService.getValue<String>('$_pixTransactionPrefix$id');
    
    if (pixTransactionJson == null) {
      return null;
    }
    
    try {
      final pixTransactionMap = jsonDecode(pixTransactionJson) as Map<String, dynamic>;
      return PixTransactionModel.fromJson(pixTransactionMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> savePixTransaction(PixTransactionModel transaction) async {
    final pixTransactionJson = jsonEncode(transaction.toJson());
    await _storageService.setValue('$_pixTransactionPrefix${transaction.id}', pixTransactionJson);
  }
  
  @override
  Future<PixQrCodeModel?> getPixQrCodeById(String id) async {
    final pixQrCodeJson = await _storageService.getValue<String>('$_pixQrCodePrefix$id');
    
    if (pixQrCodeJson == null) {
      return null;
    }
    
    try {
      final pixQrCodeMap = jsonDecode(pixQrCodeJson) as Map<String, dynamic>;
      return PixQrCodeModel.fromJson(pixQrCodeMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> savePixQrCode(PixQrCodeModel qrCode) async {
    final pixQrCodeJson = jsonEncode(qrCode.toJson());
    await _storageService.setValue('$_pixQrCodePrefix${qrCode.id}', pixQrCodeJson);
  }
}
