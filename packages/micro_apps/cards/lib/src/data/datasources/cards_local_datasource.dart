import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';

import '../models/card_model.dart';
import '../models/card_statement_model.dart';
import '../models/card_transaction_model.dart';


abstract class CardsLocalDataSource {
  
  Future<List<CardModel>?> getCards();
  
  
  Future<void> saveCards(List<CardModel> cards);
  
  
  Future<CardModel?> getCardById(String id);
  
  
  Future<void> saveCard(CardModel card);
  
  
  Future<CardStatementModel?> getCardStatement(String cardId);
  
  
  Future<void> saveCardStatement(CardStatementModel statement);
  
  
  Future<CardTransactionModel?> getTransactionById(String id);
  
  
  Future<void> saveTransaction(CardTransactionModel transaction);
}


class CardsLocalDataSourceImpl implements CardsLocalDataSource {
  final StorageService _storageService;
  
  static const String _cardsKey = 'cards';
  static const String _cardPrefix = 'card_';
  static const String _statementPrefix = 'statement_';
  static const String _transactionPrefix = 'transaction_';
  
  CardsLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;
  
  @override
  Future<List<CardModel>?> getCards() async {
    final cardsJson = await _storageService.getValue<String>(_cardsKey);
    
    if (cardsJson == null) {
      return null;
    }
    
    try {
      final cardsListJson = jsonDecode(cardsJson) as List<dynamic>;
      return cardsListJson
          .map((cardJson) => CardModel.fromJson(cardJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveCards(List<CardModel> cards) async {
    final cardsJson = jsonEncode(
      cards.map((card) => card.toJson()).toList(),
    );
    await _storageService.setValue(_cardsKey, cardsJson);
    
    
    for (final card in cards) {
      await saveCard(card);
    }
  }
  
  @override
  Future<CardModel?> getCardById(String id) async {
    final cardJson = await _storageService.getValue<String>('$_cardPrefix$id');
    
    if (cardJson == null) {
      return null;
    }
    
    try {
      final cardMap = jsonDecode(cardJson) as Map<String, dynamic>;
      return CardModel.fromJson(cardMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveCard(CardModel card) async {
    final cardJson = jsonEncode(card.toJson());
    await _storageService.setValue('$_cardPrefix${card.id}', cardJson);
  }
  
  @override
  Future<CardStatementModel?> getCardStatement(String cardId) async {
    final statementJson = await _storageService.getValue<String>('$_statementPrefix$cardId');
    
    if (statementJson == null) {
      return null;
    }
    
    try {
      final statementMap = jsonDecode(statementJson) as Map<String, dynamic>;
      return CardStatementModel.fromJson(statementMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveCardStatement(CardStatementModel statement) async {
    final statementJson = jsonEncode(statement.toJson());
    await _storageService.setValue('$_statementPrefix${statement.cardId}', statementJson);
    
    
    for (final transaction in statement.transactions) {
      await saveTransaction(transaction as CardTransactionModel);
    }
  }
  
  @override
  Future<CardTransactionModel?> getTransactionById(String id) async {
    final transactionJson = await _storageService.getValue<String>('$_transactionPrefix$id');
    
    if (transactionJson == null) {
      return null;
    }
    
    try {
      final transactionMap = jsonDecode(transactionJson) as Map<String, dynamic>;
      return CardTransactionModel.fromJson(transactionMap);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<void> saveTransaction(CardTransactionModel transaction) async {
    final transactionJson = jsonEncode(transaction.toJson());
    await _storageService.setValue('$_transactionPrefix${transaction.id}', transactionJson);
  }
}
