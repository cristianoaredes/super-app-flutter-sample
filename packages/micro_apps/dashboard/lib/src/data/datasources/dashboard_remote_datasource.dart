import 'package:core_interfaces/core_interfaces.dart';

import '../models/account_summary_model.dart';
import '../models/transaction_summary_model.dart';
import '../models/quick_action_model.dart';


abstract class DashboardRemoteDataSource {
  
  Future<AccountSummaryModel> getAccountSummary();
  
  
  Future<TransactionSummaryModel> getTransactionSummary();
  
  
  Future<List<QuickActionModel>> getQuickActions();
  
  
  Future<TransactionModel?> getTransactionById(String id);
}


class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final ApiClient _apiClient;
  
  DashboardRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;
  
  @override
  Future<AccountSummaryModel> getAccountSummary() async {
    final response = await _apiClient.get('/dashboard/account-summary');
    
    if (response.statusCode != 200) {
      throw Exception('Falha ao obter o resumo da conta');
    }
    
    return AccountSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }
  
  @override
  Future<TransactionSummaryModel> getTransactionSummary() async {
    final response = await _apiClient.get('/dashboard/transaction-summary');
    
    if (response.statusCode != 200) {
      throw Exception('Falha ao obter o resumo de transações');
    }
    
    return TransactionSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }
  
  @override
  Future<List<QuickActionModel>> getQuickActions() async {
    final response = await _apiClient.get('/dashboard/quick-actions');
    
    if (response.statusCode != 200) {
      throw Exception('Falha ao obter as ações rápidas');
    }
    
    final quickActionsJson = response.data as List<dynamic>;
    return quickActionsJson
        .map((actionJson) => QuickActionModel.fromJson(actionJson as Map<String, dynamic>))
        .toList();
  }
  
  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final response = await _apiClient.get('/transactions/$id');
    
    if (response.statusCode != 200) {
      return null;
    }
    
    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }
}
