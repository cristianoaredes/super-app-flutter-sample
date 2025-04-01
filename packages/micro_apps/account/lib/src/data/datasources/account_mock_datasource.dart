import 'package:flutter/foundation.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/transaction.dart';
import '../models/account_model.dart';
import '../models/account_balance_model.dart';
import '../models/account_statement_model.dart';
import '../models/transaction_model.dart';
import 'account_remote_datasource.dart';


class AccountMockDataSource implements AccountRemoteDataSource {
  AccountMockDataSource();

  @override
  Future<AccountModel> getAccount() async {
    if (kDebugMode) {
      print('🌐 AccountMockDataSource.getAccount');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return AccountModel(
      id: 'acc001',
      number: '12345-6',
      agency: '0001',
      holderName: 'João da Silva',
      holderDocument: '123.456.789-00',
      type: AccountType.checking,
      status: AccountStatus.active,
      openingDate: DateTime.now().subtract(const Duration(days: 365)),
    );
  }

  @override
  Future<AccountBalanceModel> getAccountBalance() async {
    if (kDebugMode) {
      print('🌐 AccountMockDataSource.getAccountBalance');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return AccountBalanceModel(
      accountId: 'acc001',
      available: 5000.0,
      total: 5000.0,
      blocked: 0.0,
      overdraftLimit: 1000.0,
      overdraftUsed: 0.0,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<AccountStatementModel> getAccountStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kDebugMode) {
      print('🌐 AccountMockDataSource.getAccountStatement');
      print('Start Date: $startDate, End Date: $endDate');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    
    final transactions = [
      TransactionModel(
        id: 'tx001',
        accountId: 'acc001',
        description: 'Depósito',
        amount: 1000.0,
        date: now.subtract(const Duration(days: 25)),
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        category: 'Depósito',
      ),
      TransactionModel(
        id: 'tx002',
        accountId: 'acc001',
        description: 'Pagamento de Conta',
        amount: 150.0,
        date: now.subtract(const Duration(days: 20)),
        type: TransactionType.debit,
        status: TransactionStatus.completed,
        category: 'Contas',
      ),
      TransactionModel(
        id: 'tx003',
        accountId: 'acc001',
        description: 'Transferência Recebida',
        amount: 500.0,
        date: now.subtract(const Duration(days: 15)),
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        category: 'Transferência',
      ),
      TransactionModel(
        id: 'tx004',
        accountId: 'acc001',
        description: 'Compra com Cartão',
        amount: 75.0,
        date: now.subtract(const Duration(days: 10)),
        type: TransactionType.debit,
        status: TransactionStatus.completed,
        category: 'Compras',
      ),
      TransactionModel(
        id: 'tx005',
        accountId: 'acc001',
        description: 'Pagamento de Salário',
        amount: 3000.0,
        date: now.subtract(const Duration(days: 5)),
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        category: 'Salário',
      ),
    ];

    
    final filteredTransactions = transactions.where((transaction) {
      return transaction.date.isAfter(start) && transaction.date.isBefore(end);
    }).toList();

    return AccountStatementModel(
      accountId: 'acc001',
      startDate: start,
      endDate: end,
      initialBalance: 1000.0,
      finalBalance: 5000.0,
      transactions: filteredTransactions,
    );
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    if (kDebugMode) {
      print('🌐 AccountMockDataSource.getTransactionById');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final transactions = {
      'tx001': TransactionModel(
        id: 'tx001',
        accountId: 'acc001',
        description: 'Depósito',
        amount: 1000.0,
        date: DateTime.now().subtract(const Duration(days: 25)),
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        category: 'Depósito',
      ),
      'tx002': TransactionModel(
        id: 'tx002',
        accountId: 'acc001',
        description: 'Pagamento de Conta',
        amount: 150.0,
        date: DateTime.now().subtract(const Duration(days: 20)),
        type: TransactionType.debit,
        status: TransactionStatus.completed,
        category: 'Contas',
      ),
      'tx003': TransactionModel(
        id: 'tx003',
        accountId: 'acc001',
        description: 'Transferência Recebida',
        amount: 500.0,
        date: DateTime.now().subtract(const Duration(days: 15)),
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        category: 'Transferência',
      ),
    };

    return transactions[id];
  }

  @override
  Future<TransactionModel> transferMoney({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  }) async {
    if (kDebugMode) {
      print('🌐 AccountMockDataSource.transferMoney');
      print('Destination: $destinationName ($destinationBank/$destinationAgency/$destinationAccount)');
      print('Amount: $amount, Description: $description');
    }

    
    await Future.delayed(const Duration(milliseconds: 500));

    return TransactionModel(
      id: 'tx${DateTime.now().millisecondsSinceEpoch}',
      accountId: 'acc001',
      description: description ?? 'Transferência para $destinationName',
      amount: amount,
      date: DateTime.now(),
      type: TransactionType.debit,
      status: TransactionStatus.completed,
      category: 'Transferência',
      metadata: {
        'destination_account': destinationAccount,
        'destination_agency': destinationAgency,
        'destination_bank': destinationBank,
        'destination_name': destinationName,
        'destination_document': destinationDocument,
      },
    );
  }
}
