import '../entities/account.dart';
import '../entities/account_balance.dart';
import '../entities/account_statement.dart';
import '../entities/transaction.dart';


abstract class AccountRepository {
  
  Future<Account> getAccount();
  
  
  Future<AccountBalance> getAccountBalance();
  
  
  Future<AccountStatement> getAccountStatement({
    DateTime? startDate,
    DateTime? endDate,
  });
  
  
  Future<Transaction?> getTransactionById(String id);
  
  
  Future<Transaction> transferMoney({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  });
}
