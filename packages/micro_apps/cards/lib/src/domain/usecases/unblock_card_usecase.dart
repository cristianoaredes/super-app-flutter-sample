import '../entities/card.dart';
import '../repositories/cards_repository.dart';


class UnblockCardUseCase {
  final CardsRepository _repository;
  
  UnblockCardUseCase({required CardsRepository repository})
      : _repository = repository;
  
  
  Future<Card> execute(String cardId) {
    return _repository.unblockCard(cardId);
  }
}
