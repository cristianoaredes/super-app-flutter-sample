import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/account_balance.dart';
import '../../domain/entities/account_statement.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_datasource.dart';
import '../datasources/account_local_datasource.dart';


class AccountRepositoryImpl implements AccountRepository {
  final AccountRemoteDataSource _remoteDataSource;
  final AccountLocalDataSource _localDataSource;
  final NetworkService _networkService;
  
  AccountRepositoryImpl({
    required AccountRemoteDataSource remoteDataSource,
    required AccountLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;
  
  @override
  Future<Account> getAccount() async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final account = await _remoteDataSource.getAccount();
        await _localDataSource.saveAccount(account);
        return account;
      } catch (e) {
        
        final localAccount = await _localDataSource.getAccount();
        if (localAccount != null) {
          return localAccount;
        }
        throw Exception('Falha ao obter os dados da conta');
      }
    } else {
      
      final localAccount = await _localDataSource.getAccount();
      if (localAccount != null) {
        return localAccount;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<AccountBalance> getAccountBalance() async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final balance = await _remoteDataSource.getAccountBalance();
        await _localDataSource.saveAccountBalance(balance);
        return balance;
      } catch (e) {
        
        final localBalance = await _localDataSource.getAccountBalance();
        if (localBalance != null) {
          return localBalance;
        }
        throw Exception('Falha ao obter o saldo da conta');
      }
    } else {
      
      final localBalance = await _localDataSource.getAccountBalance();
      if (localBalance != null) {
        return localBalance;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<AccountStatement> getAccountStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final statement = await _remoteDataSource.getAccountStatement(
          startDate: startDate,
          endDate: endDate,
        );
        await _localDataSource.saveAccountStatement(statement);
        return statement;
      } catch (e) {
        
        final localStatement = await _localDataSource.getAccountStatement();
        if (localStatement != null) {
          return localStatement;
        }
        throw Exception('Falha ao obter o extrato da conta');
      }
    } else {
      
      final localStatement = await _localDataSource.getAccountStatement();
      if (localStatement != null) {
        return localStatement;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<Transaction?> getTransactionById(String id) async {
    
    final localTransaction = await _localDataSource.getTransactionById(id);
    if (localTransaction != null) {
      return localTransaction;
    }
    
    
    final hasInternet = await _networkService.hasInternetConnection;
    if (hasInternet) {
      try {
        final transaction = await _remoteDataSource.getTransactionById(id);
        if (transaction != null) {
          await _localDataSource.saveTransaction(transaction);
        }
        return transaction;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  @override
  Future<Transaction> transferMoney({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  }) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final transaction = await _remoteDataSource.transferMoney(
      destinationAccount: destinationAccount,
      destinationAgency: destinationAgency,
      destinationBank: destinationBank,
      destinationName: destinationName,
      destinationDocument: destinationDocument,
      amount: amount,
      description: description,
    );
    
    await _localDataSource.saveTransaction(transaction);
    
    return transaction;
  }
}
