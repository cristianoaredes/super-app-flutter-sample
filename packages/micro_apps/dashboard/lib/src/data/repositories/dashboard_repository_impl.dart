import 'package:core_interfaces/core_interfaces.dart';
import 'package:dashboard/src/data/models/transaction_summary_model.dart';

import '../../domain/entities/account_summary.dart';
import '../../domain/entities/transaction_summary.dart';
import '../../domain/entities/quick_action.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../datasources/dashboard_local_datasource.dart';


class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remoteDataSource;
  final DashboardLocalDataSource _localDataSource;
  final NetworkService _networkService;

  DashboardRepositoryImpl({
    required DashboardRemoteDataSource remoteDataSource,
    required DashboardLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;

  @override
  Future<AccountSummary> getAccountSummary() async {
    final hasInternet = await _networkService.hasInternetConnection;

    if (hasInternet) {
      try {
        final accountSummary = await _remoteDataSource.getAccountSummary();
        await _localDataSource.saveAccountSummary(accountSummary);
        return accountSummary;
      } catch (e) {
        
        final localAccountSummary = await _localDataSource.getAccountSummary();
        if (localAccountSummary != null) {
          return localAccountSummary;
        }
        throw Exception('Falha ao obter o resumo da conta');
      }
    } else {
      
      final localAccountSummary = await _localDataSource.getAccountSummary();
      if (localAccountSummary != null) {
        return localAccountSummary;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }

  @override
  Future<TransactionSummary> getTransactionSummary() async {
    final hasInternet = await _networkService.hasInternetConnection;

    if (hasInternet) {
      try {
        final transactionSummary =
            await _remoteDataSource.getTransactionSummary();
        await _localDataSource.saveTransactionSummary(transactionSummary);

        
        for (final transaction in transactionSummary.recentTransactions) {
          if (transaction is TransactionModel) {
            await _localDataSource.saveTransaction(transaction);
          }
        }

        return transactionSummary;
      } catch (e) {
        
        final localTransactionSummary =
            await _localDataSource.getTransactionSummary();
        if (localTransactionSummary != null) {
          return localTransactionSummary;
        }
        throw Exception('Falha ao obter o resumo de transações');
      }
    } else {
      
      final localTransactionSummary =
          await _localDataSource.getTransactionSummary();
      if (localTransactionSummary != null) {
        return localTransactionSummary;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }

  @override
  Future<List<QuickAction>> getQuickActions() async {
    final hasInternet = await _networkService.hasInternetConnection;

    if (hasInternet) {
      try {
        final quickActions = await _remoteDataSource.getQuickActions();
        await _localDataSource.saveQuickActions(quickActions);
        return quickActions;
      } catch (e) {
        
        final localQuickActions = await _localDataSource.getQuickActions();
        if (localQuickActions != null) {
          return localQuickActions;
        }
        throw Exception('Falha ao obter as ações rápidas');
      }
    } else {
      
      final localQuickActions = await _localDataSource.getQuickActions();
      if (localQuickActions != null) {
        return localQuickActions;
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
}
