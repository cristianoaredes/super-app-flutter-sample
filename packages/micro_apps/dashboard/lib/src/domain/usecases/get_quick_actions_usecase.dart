import '../entities/quick_action.dart';
import '../repositories/dashboard_repository.dart';


class GetQuickActionsUseCase {
  final DashboardRepository _repository;
  
  GetQuickActionsUseCase({required DashboardRepository repository})
      : _repository = repository;
  
  
  Future<List<QuickAction>> execute() {
    return _repository.getQuickActions();
  }
}
