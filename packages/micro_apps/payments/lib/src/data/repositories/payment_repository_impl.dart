import 'package:core_interfaces/core_interfaces.dart';

import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../models/payment_model.dart';
import '../datasources/payment_remote_data_source.dart';


class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;
  final AuthService _authService;

  PaymentRepositoryImpl({
    required PaymentRemoteDataSource remoteDataSource,
    required AuthService authService,
  })  : _remoteDataSource = remoteDataSource,
        _authService = authService;

  @override
  Future<List<Payment>> getPayments() async {
    if (!await _isAuthenticated()) {
      throw Exception('User not authenticated');
    }

    final paymentModels = await _remoteDataSource.getPayments();
    return paymentModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Payment?> getPaymentById(String id) async {
    if (!await _isAuthenticated()) {
      throw Exception('User not authenticated');
    }

    final paymentModel = await _remoteDataSource.getPaymentById(id);
    return paymentModel?.toEntity();
  }

  @override
  Future<Payment> makePayment(Payment payment) async {
    if (!await _isAuthenticated()) {
      throw Exception('User not authenticated');
    }

    final paymentModel = PaymentModel.fromEntity(payment);
    final resultModel = await _remoteDataSource.makePayment(paymentModel);
    return resultModel.toEntity();
  }

  @override
  Future<bool> cancelPayment(String id) async {
    if (!await _isAuthenticated()) {
      throw Exception('User not authenticated');
    }

    return await _remoteDataSource.cancelPayment(id);
  }

  Future<bool> _isAuthenticated() async {
    return _authService.isAuthenticated;
  }
}
