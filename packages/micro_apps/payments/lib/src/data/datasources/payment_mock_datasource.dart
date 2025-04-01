import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import 'payment_remote_data_source.dart';

class PaymentMockDataSource implements PaymentRemoteDataSource {
  final List<PaymentModel> _mockPayments = [
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

  PaymentMockDataSource();

  @override
  Future<List<PaymentModel>> getPayments() async {
    if (kDebugMode) {
      print('🌐 [MOCK] PaymentMockDataSource.getPayments');
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_mockPayments);
  }

  @override
  Future<PaymentModel?> getPaymentById(String id) async {
    if (kDebugMode) {
      print('🌐 [MOCK] PaymentMockDataSource.getPaymentById: $id');
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return _mockPayments.firstWhere(
      (payment) => payment.id == id,
      orElse: () => throw Exception('Payment not found'),
    );
  }

  @override
  Future<PaymentModel> makePayment(PaymentModel payment) async {
    if (kDebugMode) {
      print('🌐 [MOCK] PaymentMockDataSource.makePayment');
      print('Payment: ${payment.toJson()}');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final newPayment = payment.copyWith(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      status: 'paid',
      date: DateTime.now(),
    );

    _mockPayments.add(newPayment);
    return newPayment;
  }

  @override
  Future<bool> cancelPayment(String id) async {
    if (kDebugMode) {
      print('🌐 [MOCK] PaymentMockDataSource.cancelPayment');
      print('Payment ID: $id');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final paymentIndex = _mockPayments.indexWhere((p) => p.id == id);
    if (paymentIndex == -1) {
      throw Exception('Payment not found');
    }

    _mockPayments[paymentIndex] = _mockPayments[paymentIndex].copyWith(
      status: 'cancelled',
    );

    return true;
  }
}
