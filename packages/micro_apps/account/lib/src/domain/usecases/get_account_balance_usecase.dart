import '../entities/account_balance.dart';
import '../repositories/account_repository.dart';


class GetAccountBalanceUseCase {
  final AccountRepository _repository;
  
  GetAccountBalanceUseCase({required AccountRepository repository})
      : _repository = repository;
  
  
  Future<AccountBalance> execute() {
    return _repository.getAccountBalance();
  }
}
