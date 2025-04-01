import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import 'payment_remote_data_source.dart';


class PaymentMockDataSource implements PaymentRemoteDataSource {
  PaymentMockDataSource();

  @override
  Future<List<PaymentModel>> getPayments() async {
    if (kDebugMode) {
      print('🌐 PaymentMockDataSource.getPayments');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      PaymentModel(
        id: 'pay001',
        description: 'Electricity Bill',
        amount: 150.0,
        recipient: 'Energy Company',
        date: DateTime.now().add(const Duration(days: 5)),
        status: 'pending',
      ),
      PaymentModel(
        id: 'pay002',
        description: 'Internet',
        amount: 99.90,
        recipient: 'Internet Provider',
        date: DateTime.now().add(const Duration(days: 10)),
        status: 'pending',
      ),
      PaymentModel(
        id: 'pay003',
        description: 'Rent',
        amount: 1200.0,
        recipient: 'Real Estate Agency',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'paid',
      ),
    ];
  }

  @override
  Future<PaymentModel?> getPaymentById(String id) async {
    if (kDebugMode) {
      print('🌐 PaymentMockDataSource.getPaymentById: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    final payments = {
      'pay001': PaymentModel(
        id: 'pay001',
        description: 'Electricity Bill',
        amount: 150.0,
        recipient: 'Energy Company',
        date: DateTime.now().add(const Duration(days: 5)),
        status: 'pending',
      ),
      'pay002': PaymentModel(
        id: 'pay002',
        description: 'Internet',
        amount: 99.90,
        recipient: 'Internet Provider',
        date: DateTime.now().add(const Duration(days: 10)),
        status: 'pending',
      ),
      'pay003': PaymentModel(
        id: 'pay003',
        description: 'Rent',
        amount: 1200.0,
        recipient: 'Real Estate Agency',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'paid',
      ),
    };

    return payments[id];
  }

  @override
  Future<PaymentModel> makePayment(PaymentModel payment) async {
    if (kDebugMode) {
      print('🌐 PaymentMockDataSource.makePayment');
      print('Payment: ${payment.toJson()}');
    }

    
    await Future.delayed(const Duration(milliseconds: 500));

    
    return payment.copyWith(
      status: 'paid',
      date: DateTime.now(),
    );
  }

  @override
  Future<bool> cancelPayment(String id) async {
    if (kDebugMode) {
      print('🌐 PaymentMockDataSource.cancelPayment');
      print('Payment ID: $id');
    }

    
    await Future.delayed(const Duration(milliseconds: 300));

    
    return true;
  }
}
