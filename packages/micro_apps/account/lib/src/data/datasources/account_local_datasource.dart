import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';

import '../models/account_model.dart';
import '../models/account_balance_model.dart';
import '../models/account_statement_model.dart';
import '../models/transaction_model.dart';


abstract class AccountLocalDataSource {
  
  Future<AccountModel?> getAccount();
  
  
  Future<void> saveAccount(AccountModel account);
  
  
  Future<AccountBalanceModel?> getAccountBalance();
  
  
  Future<void> saveAccountBalance(AccountBalanceModel balance);
  
  
  Future<AccountStatementModel?> getAccountStatement();
  
  
  Future<void> saveAccountStatement(AccountStatementModel statement);
  
  
  Future<TransactionModel?> getTransactionById(String id);
  
  
  Future<void> saveTransaction(TransactionModel transaction);
}


class AccountLocalDataSourceImpl implements AccountLocalDataSource {
  final StorageService _storageService;
  
  static const String _accountKey = 'account';
  static const String _accountBalanceKey = 'account_balance';
  static const String _accountStatementKey = 'account_statement';
  static const String _transactionPrefix = 'transaction_';
  
  AccountLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;
  
  @override
  Future<AccountModel?> getAccount() async {
    final accountJson = await _storageService.getValue<String>(_accountKey);
    
    if (accountJson == null) {
      return null;
    }
    
    try {
      final accountMap = jsonDecode(accountJson) as Map<String, dynamic>;
      return AccountModel.fromJson(accountMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveAccount(AccountModel account) async {
    final accountJson = jsonEncode(account.toJson());
    await _storageService.setValue(_accountKey, accountJson);
  }
  
  @override
  Future<AccountBalanceModel?> getAccountBalance() async {
    final balanceJson = await _storageService.getValue<String>(_accountBalanceKey);
    
    if (balanceJson == null) {
      return null;
    }
    
    try {
      final balanceMap = jsonDecode(balanceJson) as Map<String, dynamic>;
      return AccountBalanceModel.fromJson(balanceMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveAccountBalance(AccountBalanceModel balance) async {
    final balanceJson = jsonEncode(balance.toJson());
    await _storageService.setValue(_accountBalanceKey, balanceJson);
  }
  
  @override
  Future<AccountStatementModel?> getAccountStatement() async {
    final statementJson = await _storageService.getValue<String>(_accountStatementKey);
    
    if (statementJson == null) {
      return null;
    }
    
    try {
      final statementMap = jsonDecode(statementJson) as Map<String, dynamic>;
      return AccountStatementModel.fromJson(statementMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveAccountStatement(AccountStatementModel statement) async {
    final statementJson = jsonEncode(statement.toJson());
    await _storageService.setValue(_accountStatementKey, statementJson);
    
    
    for (final transaction in statement.transactions) {
      await saveTransaction(transaction as TransactionModel);
    }
  }
  
  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final transactionJson = await _storageService.getValue<String>('$_transactionPrefix$id');
    
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
    await _storageService.setValue('$_transactionPrefix${transaction.id}', transactionJson);
  }
}
