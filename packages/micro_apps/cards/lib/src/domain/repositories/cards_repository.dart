import '../entities/card.dart';
import '../entities/card_statement.dart';
import '../entities/card_transaction.dart';


abstract class CardsRepository {
  
  Future<List<Card>> getCards();
  
  
  Future<Card?> getCardById(String id);
  
  
  Future<CardStatement> getCardStatement(String cardId, {DateTime? startDate, DateTime? endDate});
  
  
  Future<CardTransaction?> getTransactionById(String id);
  
  
  Future<Card> blockCard(String cardId);
  
  
  Future<Card> unblockCard(String cardId);
}
