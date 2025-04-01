import 'package:core_interfaces/core_interfaces.dart';

import '../models/card_model.dart';
import '../models/card_statement_model.dart';
import '../models/card_transaction_model.dart';


abstract class CardsRemoteDataSource {
  
  Future<List<CardModel>> getCards();

  
  Future<CardModel?> getCardById(String id);

  
  Future<CardStatementModel> getCardStatement(String cardId,
      {DateTime? startDate, DateTime? endDate});

  
  Future<CardTransactionModel?> getTransactionById(String id);

  
  Future<CardModel> blockCard(String cardId);

  
  Future<CardModel> unblockCard(String cardId);
}


class CardsRemoteDataSourceImpl implements CardsRemoteDataSource {
  final ApiClient _apiClient;

  CardsRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<CardModel>> getCards() async {
    final response = await _apiClient.get('/cards');

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter os cartões');
    }

    final cardsJson = response.data as List<dynamic>;
    return cardsJson
        .map((cardJson) => CardModel.fromJson(cardJson as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CardModel?> getCardById(String id) async {
    final response = await _apiClient.get('/cards/$id');

    if (response.statusCode != 200) {
      return null;
    }

    return CardModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CardStatementModel> getCardStatement(String cardId,
      {DateTime? startDate, DateTime? endDate}) async {
    final queryParams = <String, dynamic>{};

    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }

    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    final response = await _apiClient.get(
      '/cards/$cardId/statement',
      queryParams: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter o extrato do cartão');
    }

    return CardStatementModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CardTransactionModel?> getTransactionById(String id) async {
    final response = await _apiClient.get('/transactions/$id');

    if (response.statusCode != 200) {
      return null;
    }

    return CardTransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CardModel> blockCard(String cardId) async {
    final response = await _apiClient.post('/cards/$cardId/block');

    if (response.statusCode != 200) {
      throw Exception('Falha ao bloquear o cartão');
    }

    return CardModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<CardModel> unblockCard(String cardId) async {
    final response = await _apiClient.post('/cards/$cardId/unblock');

    if (response.statusCode != 200) {
      throw Exception('Falha ao desbloquear o cartão');
    }

    return CardModel.fromJson(response.data as Map<String, dynamic>);
  }
}
