import '../entities/account.dart';
import '../repositories/account_repository.dart';


class GetAccountUseCase {
  final AccountRepository _repository;
  
  GetAccountUseCase({required AccountRepository repository})
      : _repository = repository;
  
  
  Future<Account> execute() {
    return _repository.getAccount();
  }
}
