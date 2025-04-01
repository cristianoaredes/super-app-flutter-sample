import '../entities/card.dart';
import '../repositories/cards_repository.dart';


class BlockCardUseCase {
  final CardsRepository _repository;
  
  BlockCardUseCase({required CardsRepository repository})
      : _repository = repository;
  
  
  Future<Card> execute(String cardId) {
    return _repository.blockCard(cardId);
  }
}
