import 'package:core_interfaces/core_interfaces.dart';

import '../models/account_model.dart';
import '../models/account_balance_model.dart';
import '../models/account_statement_model.dart';
import '../models/transaction_model.dart';


abstract class AccountRemoteDataSource {
  
  Future<AccountModel> getAccount();

  
  Future<AccountBalanceModel> getAccountBalance();

  
  Future<AccountStatementModel> getAccountStatement({
    DateTime? startDate,
    DateTime? endDate,
  });

  
  Future<TransactionModel?> getTransactionById(String id);

  
  Future<TransactionModel> transferMoney({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  });
}


class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  final ApiClient _apiClient;

  AccountRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<AccountModel> getAccount() async {
    final response = await _apiClient.get('/account');

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter os dados da conta');
    }

    return AccountModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AccountBalanceModel> getAccountBalance() async {
    final response = await _apiClient.get('/account/balance');

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter o saldo da conta');
    }

    return AccountBalanceModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AccountStatementModel> getAccountStatement({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};

    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }

    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    final response = await _apiClient.get(
      '/account/statement',
      queryParams: queryParams,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao obter o extrato da conta');
    }

    return AccountStatementModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final response = await _apiClient.get('/transactions/$id');

    if (response.statusCode != 200) {
      return null;
    }

    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<TransactionModel> transferMoney({
    required String destinationAccount,
    required String destinationAgency,
    required String destinationBank,
    required String destinationName,
    required String destinationDocument,
    required double amount,
    String? description,
  }) async {
    final response = await _apiClient.post(
      '/account/transfer',
      body: {
        'destination_account': destinationAccount,
        'destination_agency': destinationAgency,
        'destination_bank': destinationBank,
        'destination_name': destinationName,
        'destination_document': destinationDocument,
        'amount': amount,
        'description': description,
      },
    );

    if (response.statusCode != 201) {
      throw Exception('Falha ao realizar a transferência');
    }

    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }
}
