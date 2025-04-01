import '../entities/account_statement.dart';
import '../entities/transaction.dart';
import '../repositories/account_repository.dart';


class GetAccountStatementUseCase {
  final AccountRepository _repository;
  
  GetAccountStatementUseCase({required AccountRepository repository})
      : _repository = repository;
  
  
  Future<AccountStatement> execute({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _repository.getAccountStatement(
      startDate: startDate,
      endDate: endDate,
    );
  }
  
  
  Future<Transaction?> getTransactionById(String id) {
    return _repository.getTransactionById(id);
  }
}
