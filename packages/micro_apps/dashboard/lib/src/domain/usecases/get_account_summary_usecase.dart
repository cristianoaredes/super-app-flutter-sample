import '../entities/account_summary.dart';
import '../repositories/dashboard_repository.dart';


class GetAccountSummaryUseCase {
  final DashboardRepository _repository;
  
  GetAccountSummaryUseCase({required DashboardRepository repository})
      : _repository = repository;
  
  
  Future<AccountSummary> execute() {
    return _repository.getAccountSummary();
  }
}
