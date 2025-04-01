import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/pix_key.dart';
import '../../domain/entities/pix_transaction.dart';
import '../../domain/entities/pix_qr_code.dart';
import '../../domain/repositories/pix_repository.dart';
import '../datasources/pix_remote_datasource.dart';
import '../datasources/pix_local_datasource.dart';


class PixRepositoryImpl implements PixRepository {
  final PixRemoteDataSource _remoteDataSource;
  final PixLocalDataSource _localDataSource;
  final NetworkService _networkService;
  
  PixRepositoryImpl({
    required PixRemoteDataSource remoteDataSource,
    required PixLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;
  
  @override
  Future<List<PixKey>> getPixKeys() async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final keys = await _remoteDataSource.getPixKeys();
        await _localDataSource.savePixKeys(keys);
        return keys;
      } catch (e) {
        
        final localKeys = await _localDataSource.getPixKeys();
        if (localKeys != null) {
          return localKeys;
        }
        throw Exception('Falha ao obter as chaves Pix');
      }
    } else {
      
      final localKeys = await _localDataSource.getPixKeys();
      if (localKeys != null) {
        return localKeys;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<PixKey?> getPixKeyById(String id) async {
    
    final localKey = await _localDataSource.getPixKeyById(id);
    if (localKey != null) {
      return localKey;
    }
    
    
    final hasInternet = await _networkService.hasInternetConnection;
    if (hasInternet) {
      try {
        final key = await _remoteDataSource.getPixKeyById(id);
        if (key != null) {
          await _localDataSource.savePixKey(key);
        }
        return key;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  @override
  Future<PixKey> registerPixKey(PixKeyType type, String value, {String? name}) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final key = await _remoteDataSource.registerPixKey(type, value, name: name);
    await _localDataSource.savePixKey(key);
    
    
    final keys = await _localDataSource.getPixKeys();
    if (keys != null) {
      keys.add(key);
      await _localDataSource.savePixKeys(keys);
    } else {
      await _localDataSource.savePixKeys([key]);
    }
    
    return key;
  }
  
  @override
  Future<void> deletePixKey(String id) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    await _remoteDataSource.deletePixKey(id);
    await _localDataSource.deletePixKey(id);
  }
  
  @override
  Future<List<PixTransaction>> getPixTransactions() async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final transactions = await _remoteDataSource.getPixTransactions();
        await _localDataSource.savePixTransactions(transactions);
        return transactions;
      } catch (e) {
        
        final localTransactions = await _localDataSource.getPixTransactions();
        if (localTransactions != null) {
          return localTransactions;
        }
        throw Exception('Falha ao obter as transações Pix');
      }
    } else {
      
      final localTransactions = await _localDataSource.getPixTransactions();
      if (localTransactions != null) {
        return localTransactions;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<PixTransaction?> getPixTransactionById(String id) async {
    
    final localTransaction = await _localDataSource.getPixTransactionById(id);
    if (localTransaction != null) {
      return localTransaction;
    }
    
    
    final hasInternet = await _networkService.hasInternetConnection;
    if (hasInternet) {
      try {
        final transaction = await _remoteDataSource.getPixTransactionById(id);
        if (transaction != null) {
          await _localDataSource.savePixTransaction(transaction);
        }
        return transaction;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  @override
  Future<PixTransaction> sendPix({
    required String pixKeyValue,
    required PixKeyType pixKeyType,
    required double amount,
    String? description,
    String? receiverName,
  }) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final transaction = await _remoteDataSource.sendPix(
      pixKeyValue: pixKeyValue,
      pixKeyType: pixKeyType,
      amount: amount,
      description: description,
      receiverName: receiverName,
    );
    
    await _localDataSource.savePixTransaction(transaction);
    
    
    final transactions = await _localDataSource.getPixTransactions();
    if (transactions != null) {
      transactions.add(transaction);
      await _localDataSource.savePixTransactions(transactions);
    } else {
      await _localDataSource.savePixTransactions([transaction]);
    }
    
    return transaction;
  }
  
  @override
  Future<PixQrCode> receivePixWithQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final qrCode = await _remoteDataSource.receivePixWithQrCode(
      pixKeyId: pixKeyId,
      amount: amount,
      description: description,
      isStatic: isStatic,
      expiresAt: expiresAt,
    );
    
    await _localDataSource.savePixQrCode(qrCode);
    
    return qrCode;
  }
  
  @override
  Future<PixQrCode> generateQrCode({
    required String pixKeyId,
    double? amount,
    String? description,
    bool isStatic = false,
    DateTime? expiresAt,
  }) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final qrCode = await _remoteDataSource.generateQrCode(
      pixKeyId: pixKeyId,
      amount: amount,
      description: description,
      isStatic: isStatic,
      expiresAt: expiresAt,
    );
    
    await _localDataSource.savePixQrCode(qrCode);
    
    return qrCode;
  }
  
  @override
  Future<PixQrCode> readQrCode(String payload) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final qrCode = await _remoteDataSource.readQrCode(payload);
    
    await _localDataSource.savePixQrCode(qrCode);
    
    return qrCode;
  }
}
