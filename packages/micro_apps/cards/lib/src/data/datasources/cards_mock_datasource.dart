import 'package:flutter/foundation.dart';

import '../../domain/entities/card.dart';
import '../../domain/entities/card_transaction.dart';
import '../models/card_model.dart';
import '../models/card_statement_model.dart';
import '../models/card_transaction_model.dart';
import 'cards_remote_datasource.dart';


class CardsMockDataSource implements CardsRemoteDataSource {
  CardsMockDataSource();

  @override
  Future<List<CardModel>> getCards() async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.getCards');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      CardModel(
        id: 'card001',
        number: '5432 **** **** 1234',
        holderName: 'João da Silva',
        type: 'credit',
        brand: 'Mastercard',
        expirationDate: DateTime.now().add(const Duration(days: 365 * 2)),
        cvv: '123',
        limit: 5000.0,
        availableLimit: 3500.0,
        isBlocked: false,
        isVirtual: false,
        isContactless: true,
        status: CardStatus.active,
      ),
      CardModel(
        id: 'card002',
        number: '4321 **** **** 5678',
        holderName: 'João da Silva',
        type: 'debit',
        brand: 'Visa',
        expirationDate: DateTime.now().add(const Duration(days: 365 * 3)),
        cvv: '456',
        limit: 0.0,
        availableLimit: 0.0,
        isBlocked: false,
        isVirtual: false,
        isContactless: true,
        status: CardStatus.active,
      ),
      CardModel(
        id: 'card003',
        number: '9876 **** **** 5432',
        holderName: 'João da Silva',
        type: 'credit',
        brand: 'Visa',
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        cvv: '789',
        limit: 2000.0,
        availableLimit: 1500.0,
        isBlocked: false,
        isVirtual: true,
        isContactless: false,
        status: CardStatus.active,
      ),
    ];
  }

  @override
  Future<CardModel?> getCardById(String id) async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.getCardById');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final cards = {
      'card001': CardModel(
        id: 'card001',
        number: '5432 **** **** 1234',
        holderName: 'João da Silva',
        type: 'credit',
        brand: 'Mastercard',
        expirationDate: DateTime.now().add(const Duration(days: 365 * 2)),
        cvv: '123',
        limit: 5000.0,
        availableLimit: 3500.0,
        isBlocked: false,
        isVirtual: false,
        isContactless: true,
        status: CardStatus.active,
      ),
      'card002': CardModel(
        id: 'card002',
        number: '4321 **** **** 5678',
        holderName: 'João da Silva',
        type: 'debit',
        brand: 'Visa',
        expirationDate: DateTime.now().add(const Duration(days: 365 * 3)),
        cvv: '456',
        limit: 0.0,
        availableLimit: 0.0,
        isBlocked: false,
        isVirtual: false,
        isContactless: true,
        status: CardStatus.active,
      ),
      'card003': CardModel(
        id: 'card003',
        number: '9876 **** **** 5432',
        holderName: 'João da Silva',
        type: 'credit',
        brand: 'Visa',
        expirationDate: DateTime.now().add(const Duration(days: 365)),
        cvv: '789',
        limit: 2000.0,
        availableLimit: 1500.0,
        isBlocked: false,
        isVirtual: true,
        isContactless: false,
        status: CardStatus.active,
      ),
    };

    return cards[id];
  }

  @override
  Future<CardStatementModel> getCardStatement(String cardId,
      {DateTime? startDate, DateTime? endDate}) async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.getCardStatement');
      print('Card ID: $cardId, Start Date: $startDate, End Date: $endDate');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    
    final transactions = [
      CardTransactionModel(
        id: 'tx001',
        cardId: cardId,
        description: 'Supermercado',
        merchant: 'Supermercado ABC',
        category: 'Alimentação',
        amount: 150.0,
        date: now.subtract(const Duration(days: 25)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '123456',
      ),
      CardTransactionModel(
        id: 'tx002',
        cardId: cardId,
        description: 'Restaurante',
        merchant: 'Restaurante XYZ',
        category: 'Alimentação',
        amount: 75.0,
        date: now.subtract(const Duration(days: 20)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '234567',
      ),
      CardTransactionModel(
        id: 'tx003',
        cardId: cardId,
        description: 'Farmácia',
        merchant: 'Farmácia 123',
        category: 'Saúde',
        amount: 50.0,
        date: now.subtract(const Duration(days: 15)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '345678',
      ),
      CardTransactionModel(
        id: 'tx004',
        cardId: cardId,
        description: 'Pagamento da Fatura',
        merchant: 'Banco',
        category: 'Pagamento',
        amount: 500.0,
        date: now.subtract(const Duration(days: 10)),
        type: CardTransactionType.payment,
        status: CardTransactionStatus.approved,
        authorizationCode: '456789',
      ),
      CardTransactionModel(
        id: 'tx005',
        cardId: cardId,
        description: 'Posto de Gasolina',
        merchant: 'Posto ABC',
        category: 'Transporte',
        amount: 100.0,
        date: now.subtract(const Duration(days: 5)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '567890',
      ),
    ];

    
    final filteredTransactions = transactions.where((transaction) {
      return transaction.date.isAfter(start) && transaction.date.isBefore(end);
    }).toList();

    
    double totalSpent = 0.0;
    double totalPayments = 0.0;
    double totalRefunds = 0.0;
    double totalFees = 0.0;
    final categoryDistribution = <String, double>{};

    for (final transaction in filteredTransactions) {
      switch (transaction.type) {
        case CardTransactionType.purchase:
          totalSpent += transaction.amount;
          categoryDistribution[transaction.category] =
              (categoryDistribution[transaction.category] ?? 0.0) +
                  transaction.amount;
          break;
        case CardTransactionType.payment:
          totalPayments += transaction.amount;
          break;
        case CardTransactionType.refund:
          totalRefunds += transaction.amount;
          break;
        case CardTransactionType.fee:
          totalFees += transaction.amount;
          break;
        default:
          break;
      }
    }

    return CardStatementModel(
      cardId: cardId,
      startDate: start,
      endDate: end,
      totalSpent: totalSpent,
      totalPayments: totalPayments,
      totalRefunds: totalRefunds,
      totalFees: totalFees,
      transactions: filteredTransactions,
      categoryDistribution: categoryDistribution,
    );
  }

  @override
  Future<CardTransactionModel?> getTransactionById(String id) async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.getTransactionById');
      print('ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final transactions = {
      'tx001': CardTransactionModel(
        id: 'tx001',
        cardId: 'card001',
        description: 'Supermercado',
        merchant: 'Supermercado ABC',
        category: 'Alimentação',
        amount: 150.0,
        date: DateTime.now().subtract(const Duration(days: 25)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '123456',
      ),
      'tx002': CardTransactionModel(
        id: 'tx002',
        cardId: 'card001',
        description: 'Restaurante',
        merchant: 'Restaurante XYZ',
        category: 'Alimentação',
        amount: 75.0,
        date: DateTime.now().subtract(const Duration(days: 20)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '234567',
      ),
      'tx003': CardTransactionModel(
        id: 'tx003',
        cardId: 'card001',
        description: 'Farmácia',
        merchant: 'Farmácia 123',
        category: 'Saúde',
        amount: 50.0,
        date: DateTime.now().subtract(const Duration(days: 15)),
        type: CardTransactionType.purchase,
        status: CardTransactionStatus.approved,
        authorizationCode: '345678',
      ),
    };

    return transactions[id];
  }

  @override
  Future<CardModel> blockCard(String cardId) async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.blockCard');
      print('Card ID: $cardId');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final card = await getCardById(cardId);
    if (card == null) {
      throw Exception('Cartão não encontrado');
    }

    
    return card.copyWith(
      isBlocked: true,
      status: CardStatus.blocked,
    );
  }

  @override
  Future<CardModel> unblockCard(String cardId) async {
    if (kDebugMode) {
      print('🌐 CardsMockDataSource.unblockCard');
      print('Card ID: $cardId');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final card = await getCardById(cardId);
    if (card == null) {
      throw Exception('Cartão não encontrado');
    }

    
    return card.copyWith(
      isBlocked: false,
      status: CardStatus.active,
    );
  }
}
