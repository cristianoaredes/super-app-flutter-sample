import '../entities/transaction.dart';
import '../repositories/account_repository.dart';


class TransferMoneyUseCase {
  final AccountRepository _repository;
  
  TransferMoneyUseCase({required AccountRepository repository})
      : _repository = repository;
  
  
  Future<Transaction> execute({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  }) {
    return _repository.transferMoney(
      destinationAccount: destinationAccount,
      destinationAgency: destinationAgency,
      destinationBank: destinationBank,
      destinationName: destinationName,
      destinationDocument: destinationDocument,
      amount: amount,
      description: description,
    );
  }
}
