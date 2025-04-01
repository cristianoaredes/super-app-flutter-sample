import 'package:core_interfaces/core_interfaces.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../domain/usecases/get_payments_usecase.dart';
import '../../domain/usecases/make_payment_usecase.dart';
import 'payments_state.dart';

class PaymentsCubit extends HydratedCubit<PaymentsState> {
  final PaymentRepository _repository;
  final AnalyticsService _analyticsService;
  final GetPaymentsUseCase _getPaymentsUseCase;
  final MakePaymentUseCase _makePaymentUseCase;
  
  PaymentsCubit({
    required PaymentRepository repository,
    required AnalyticsService analyticsService,
  })  : _repository = repository,
        _analyticsService = analyticsService,
        _getPaymentsUseCase = GetPaymentsUseCase(repository),
        _makePaymentUseCase = MakePaymentUseCase(repository),
        super(const PaymentsState());
  
  Future<void> fetchPayments() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    
    try {
      final payments = await _getPaymentsUseCase.execute();
      emit(state.copyWith(
        payments: payments,
        isLoading: false,
      ));
      _analyticsService.trackEvent('payments_loaded', {
        'count': payments.length,
      });
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
      _analyticsService.trackError('payments_load_failed', e.toString());
    }
  }
  
  Future<void> makePayment(Payment payment) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    
    try {
      await _makePaymentUseCase.execute(payment);
      await fetchPayments(); 
      _analyticsService.trackEvent('payment_made', {
        'amount': payment.amount,
        'recipient': payment.recipient,
      });
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
      _analyticsService.trackError('payment_failed', e.toString());
    }
  }
  
  Future<void> cancelPayment(String id) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    
    try {
      final success = await _repository.cancelPayment(id);
      if (success) {
        await fetchPayments(); 
        _analyticsService.trackEvent('payment_cancelled', {
          'payment_id': id,
        });
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Falha ao cancelar o pagamento',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
      _analyticsService.trackError('payment_cancel_failed', e.toString());
    }
  }
  
  @override
  PaymentsState? fromJson(Map<String, dynamic> json) =>
      PaymentsState.fromJson(json);
  
  @override
  Map<String, dynamic>? toJson(PaymentsState state) => state.toJson();
}
