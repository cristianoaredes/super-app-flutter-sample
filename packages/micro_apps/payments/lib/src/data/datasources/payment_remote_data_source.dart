import 'package:core_interfaces/core_interfaces.dart';

import '../models/payment_model.dart';


abstract class PaymentRemoteDataSource {
  
  Future<List<PaymentModel>> getPayments();

  
  Future<PaymentModel?> getPaymentById(String id);

  
  Future<PaymentModel> makePayment(PaymentModel payment);

  
  Future<bool> cancelPayment(String id);
}


class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final ApiClient _apiClient;

  PaymentRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<PaymentModel>> getPayments() async {
    final response = await _apiClient.get('/payments');

    if (response.isSuccess) {
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get payments: ${response.statusCode}');
    }
  }

  @override
  Future<PaymentModel?> getPaymentById(String id) async {
    final response = await _apiClient.get('/payments/$id');

    if (response.isSuccess) {
      return PaymentModel.fromJson(response.data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to get payment: ${response.statusCode}');
    }
  }

  @override
  Future<PaymentModel> makePayment(PaymentModel payment) async {
    final response = await _apiClient.post(
      '/payments',
      body: payment.toJson(),
    );

    if (response.isSuccess) {
      return PaymentModel.fromJson(response.data);
    } else {
      throw Exception('Failed to make payment: ${response.statusCode}');
    }
  }

  @override
  Future<bool> cancelPayment(String id) async {
    final response = await _apiClient.delete('/payments/$id');

    if (response.isSuccess) {
      return true;
    } else {
      throw Exception('Failed to cancel payment: ${response.statusCode}');
    }
  }
}
