import '../entities/card.dart';
import '../repositories/cards_repository.dart';


class GetCardsUseCase {
  final CardsRepository _repository;
  
  GetCardsUseCase({required CardsRepository repository})
      : _repository = repository;
  
  
  Future<List<Card>> execute() {
    return _repository.getCards();
  }
  
  
  Future<Card?> getCardById(String id) {
    return _repository.getCardById(id);
  }
}
