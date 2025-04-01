import 'package:cards/cards.dart';

import '../entities/get_card_statement_params.dart';

class GetCardStatementUseCase {
  final CardsRepository _repository;

  GetCardStatementUseCase({required CardsRepository repository})
      : _repository = repository;

  Future<CardStatement> execute(GetCardStatementParams params) async {
    return await _repository.getCardStatement(
      params.cardId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }

  Future<CardTransaction?> getTransactionById(String id) {
    return _repository.getTransactionById(id);
  }
}
