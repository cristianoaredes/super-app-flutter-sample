import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/transaction_summary.dart';
import '../models/account_summary_model.dart';
import '../models/transaction_summary_model.dart';
import '../models/quick_action_model.dart';
import 'dashboard_remote_datasource.dart';


class DashboardMockDataSource implements DashboardRemoteDataSource {
  DashboardMockDataSource();

  @override
  Future<AccountSummaryModel> getAccountSummary() async {
    if (kDebugMode) {
      print('🌐 DashboardMockDataSource.getAccountSummary');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return AccountSummaryModel(
      accountId: 'mock-account-id',
      accountNumber: '12345-6',
      agency: '0001',
      balance: 12345.67,
      income: 5000.0,
      expenses: 3500.0,
      savings: 1000.0,
      investments: 2000.0,
      lastUpdate: DateTime.now(),
    );
  }

  @override
  Future<TransactionSummaryModel> getTransactionSummary() async {
    if (kDebugMode) {
      print('🌐 DashboardMockDataSource.getTransactionSummary');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    final transactions = [
      TransactionModel(
        id: 'tx001',
        title: 'Salário',
        description: 'Pagamento mensal',
        amount: 5000.0,
        date: DateTime.parse('2023-05-05'),
        type: TransactionType.income,
        category: 'salary',
      ),
      TransactionModel(
        id: 'tx002',
        title: 'Aluguel',
        description: 'Pagamento mensal do aluguel',
        amount: -1500.0,
        date: DateTime.parse('2023-05-10'),
        type: TransactionType.expense,
        category: 'housing',
      ),
      TransactionModel(
        id: 'tx003',
        title: 'Supermercado',
        description: 'Compras da semana',
        amount: -800.0,
        date: DateTime.parse('2023-05-15'),
        type: TransactionType.expense,
        category: 'food',
      ),
    ];

    final categoryDistribution = {
      'salary': 5000.0, 
      'housing': 1500.0,
      'food': 800.0,
    };

    final monthlyExpenses = [
      MonthlyExpenseModel(month: 'Janeiro', amount: 2800.0),
      MonthlyExpenseModel(month: 'Fevereiro', amount: 3200.0),
      MonthlyExpenseModel(month: 'Março', amount: 2900.0),
      MonthlyExpenseModel(month: 'Abril', amount: 3100.0),
      MonthlyExpenseModel(month: 'Maio', amount: 3500.0),
    ];

    return TransactionSummaryModel(
      recentTransactions: transactions,
      categoryDistribution: categoryDistribution,
      monthlyExpenses: monthlyExpenses,
    );
  }

  @override
  Future<List<QuickActionModel>> getQuickActions() async {
    if (kDebugMode) {
      print('🌐 DashboardMockDataSource.getQuickActions');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      QuickActionModel(
        id: 'qa001',
        title: 'Pix',
        description: 'Faça transferências via Pix',
        icon: Icons.pix,
        route: '/pix',
      ),
      QuickActionModel(
        id: 'qa002',
        title: 'Transferência',
        description: 'Faça transferências entre contas',
        icon: Icons.swap_horiz,
        route: '/account/transfer',
      ),
      QuickActionModel(
        id: 'qa003',
        title: 'Pagamentos',
        description: 'Pague suas contas e boletos',
        icon: Icons.payment,
        route: '/payments',
      ),
      QuickActionModel(
        id: 'qa004',
        title: 'Cartões',
        description: 'Gerencie seus cartões',
        icon: Icons.credit_card,
        route: '/cards',
      ),
    ];
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    if (kDebugMode) {
      print('🌐 DashboardMockDataSource.getTransactionById: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final transactions = {
      'tx001': TransactionModel(
        id: 'tx001',
        title: 'Salário',
        description: 'Pagamento mensal',
        amount: 5000.0,
        date: DateTime.parse('2023-05-05'),
        type: TransactionType.income,
        category: 'salary',
      ),
      'tx002': TransactionModel(
        id: 'tx002',
        title: 'Aluguel',
        description: 'Pagamento mensal do aluguel',
        amount: -1500.0,
        date: DateTime.parse('2023-05-10'),
        type: TransactionType.expense,
        category: 'housing',
      ),
      'tx003': TransactionModel(
        id: 'tx003',
        title: 'Supermercado',
        description: 'Compras da semana',
        amount: -800.0,
        date: DateTime.parse('2023-05-15'),
        type: TransactionType.expense,
        category: 'food',
      ),
    };

    return transactions[id];
  }
}
