import '../entities/account_summary.dart';
import '../entities/transaction_summary.dart';
import '../entities/quick_action.dart';


abstract class DashboardRepository {
  
  Future<AccountSummary> getAccountSummary();
  
  
  Future<TransactionSummary> getTransactionSummary();
  
  
  Future<List<QuickAction>> getQuickActions();
  
  
  Future<Transaction?> getTransactionById(String id);
}
