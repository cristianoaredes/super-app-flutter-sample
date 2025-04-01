import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';

import '../models/account_summary_model.dart';
import '../models/transaction_summary_model.dart';
import '../models/quick_action_model.dart';


abstract class DashboardLocalDataSource {
  
  Future<AccountSummaryModel?> getAccountSummary();
  
  
  Future<void> saveAccountSummary(AccountSummaryModel accountSummary);
  
  
  Future<TransactionSummaryModel?> getTransactionSummary();
  
  
  Future<void> saveTransactionSummary(TransactionSummaryModel transactionSummary);
  
  
  Future<List<QuickActionModel>?> getQuickActions();
  
  
  Future<void> saveQuickActions(List<QuickActionModel> quickActions);
  
  
  Future<TransactionModel?> getTransactionById(String id);
  
  
  Future<void> saveTransaction(TransactionModel transaction);
}


class DashboardLocalDataSourceImpl implements DashboardLocalDataSource {
  final StorageService _storageService;
  
  static const String _accountSummaryKey = 'account_summary';
  static const String _transactionSummaryKey = 'transaction_summary';
  static const String _quickActionsKey = 'quick_actions';
  static const String _transactionsPrefix = 'transaction_';
  
  DashboardLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;
  
  @override
  Future<AccountSummaryModel?> getAccountSummary() async {
    final accountSummaryJson = await _storageService.getValue<String>(_accountSummaryKey);
    
    if (accountSummaryJson == null) {
      return null;
    }
    
    try {
      final accountSummaryMap = jsonDecode(accountSummaryJson) as Map<String, dynamic>;
      return AccountSummaryModel.fromJson(accountSummaryMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveAccountSummary(AccountSummaryModel accountSummary) async {
    final accountSummaryJson = jsonEncode(accountSummary.toJson());
    await _storageService.setValue(_accountSummaryKey, accountSummaryJson);
  }
  
  @override
  Future<TransactionSummaryModel?> getTransactionSummary() async {
    final transactionSummaryJson = await _storageService.getValue<String>(_transactionSummaryKey);
    
    if (transactionSummaryJson == null) {
      return null;
    }
    
    try {
      final transactionSummaryMap = jsonDecode(transactionSummaryJson) as Map<String, dynamic>;
      return TransactionSummaryModel.fromJson(transactionSummaryMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveTransactionSummary(TransactionSummaryModel transactionSummary) async {
    final transactionSummaryJson = jsonEncode(transactionSummary.toJson());
    await _storageService.setValue(_transactionSummaryKey, transactionSummaryJson);
  }
  
  @override
  Future<List<QuickActionModel>?> getQuickActions() async {
    final quickActionsJson = await _storageService.getValue<String>(_quickActionsKey);
    
    if (quickActionsJson == null) {
      return null;
    }
    
    try {
      final quickActionsList = jsonDecode(quickActionsJson) as List<dynamic>;
      return quickActionsList
          .map((actionJson) => QuickActionModel.fromJson(actionJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveQuickActions(List<QuickActionModel> quickActions) async {
    final quickActionsJson = jsonEncode(
      quickActions.map((action) => action.toJson()).toList(),
    );
    await _storageService.setValue(_quickActionsKey, quickActionsJson);
  }
  
  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final transactionJson = await _storageService.getValue<String>('$_transactionsPrefix$id');
    
    if (transactionJson == null) {
      return null;
    }
    
    try {
      final transactionMap = jsonDecode(transactionJson) as Map<String, dynamic>;
      return TransactionModel.fromJson(transactionMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    final transactionJson = jsonEncode(transaction.toJson());
    await _storageService.setValue('$_transactionsPrefix${transaction.id}', transactionJson);
  }
}
