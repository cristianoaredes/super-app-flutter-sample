import '../entities/transaction_summary.dart';
import '../repositories/dashboard_repository.dart';


class GetTransactionSummaryUseCase {
  final DashboardRepository _repository;
  
  GetTransactionSummaryUseCase({required DashboardRepository repository})
      : _repository = repository;
  
  
  Future<TransactionSummary> execute() {
    return _repository.getTransactionSummary();
  }
  
  
  Future<Transaction?> getTransactionById(String id) {
    return _repository.getTransactionById(id);
  }
}
