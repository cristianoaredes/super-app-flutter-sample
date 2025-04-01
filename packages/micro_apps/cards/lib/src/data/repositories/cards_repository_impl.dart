import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/card.dart';
import '../../domain/entities/card_statement.dart';
import '../../domain/entities/card_transaction.dart';
import '../../domain/repositories/cards_repository.dart';
import '../datasources/cards_local_datasource.dart';
import '../datasources/cards_remote_datasource.dart';


class CardsRepositoryImpl implements CardsRepository {
  final CardsRemoteDataSource _remoteDataSource;
  final CardsLocalDataSource _localDataSource;
  final NetworkService _networkService;
  
  CardsRepositoryImpl({
    required CardsRemoteDataSource remoteDataSource,
    required CardsLocalDataSource localDataSource,
    required NetworkService networkService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkService = networkService;
  
  @override
  Future<List<Card>> getCards() async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final cards = await _remoteDataSource.getCards();
        await _localDataSource.saveCards(cards);
        return cards;
      } catch (e) {
        
        final localCards = await _localDataSource.getCards();
        if (localCards != null) {
          return localCards;
        }
        throw Exception('Falha ao obter os cartões');
      }
    } else {
      
      final localCards = await _localDataSource.getCards();
      if (localCards != null) {
        return localCards;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<Card?> getCardById(String id) async {
    
    final localCard = await _localDataSource.getCardById(id);
    if (localCard != null) {
      return localCard;
    }
    
    
    final hasInternet = await _networkService.hasInternetConnection;
    if (hasInternet) {
      try {
        final card = await _remoteDataSource.getCardById(id);
        if (card != null) {
          await _localDataSource.saveCard(card);
        }
        return card;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  @override
  Future<CardStatement> getCardStatement(String cardId, {DateTime? startDate, DateTime? endDate}) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (hasInternet) {
      try {
        final statement = await _remoteDataSource.getCardStatement(
          cardId,
          startDate: startDate,
          endDate: endDate,
        );
        await _localDataSource.saveCardStatement(statement);
        return statement;
      } catch (e) {
        
        final localStatement = await _localDataSource.getCardStatement(cardId);
        if (localStatement != null) {
          return localStatement;
        }
        throw Exception('Falha ao obter o extrato do cartão');
      }
    } else {
      
      final localStatement = await _localDataSource.getCardStatement(cardId);
      if (localStatement != null) {
        return localStatement;
      }
      throw Exception('Sem conexão com a internet e nenhum dado em cache');
    }
  }
  
  @override
  Future<CardTransaction?> getTransactionById(String id) async {
    
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
  Future<Card> blockCard(String cardId) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final card = await _remoteDataSource.blockCard(cardId);
    await _localDataSource.saveCard(card);
    return card;
  }
  
  @override
  Future<Card> unblockCard(String cardId) async {
    final hasInternet = await _networkService.hasInternetConnection;
    
    if (!hasInternet) {
      throw Exception('Sem conexão com a internet');
    }
    
    final card = await _remoteDataSource.unblockCard(cardId);
    await _localDataSource.saveCard(card);
    return card;
  }
}
