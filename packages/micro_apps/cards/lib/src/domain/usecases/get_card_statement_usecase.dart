import '../entities/card_statement.dart';
import '../entities/card_transaction.dart';
import '../repositories/cards_repository.dart';


class GetCardStatementUseCase {
  final CardsRepository _repository;
  
  GetCardStatementUseCase({required CardsRepository repository})
      : _repository = repository;
  
  
  Future<CardStatement> execute(String cardId, {DateTime? startDate, DateTime? endDate}) {
    return _repository.getCardStatement(cardId, startDate: startDate, endDate: endDate);
  }
  
  
  Future<CardTransaction?> getTransactionById(String id) {
    return _repository.getTransactionById(id);
  }
}
