import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/payment.dart';
import '../cubits/payments_cubit.dart';
import '../cubits/payments_state.dart';
import '../widgets/payment_list_item.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({Key? key}) : super(key: key);

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with AutomaticKeepAliveClientMixin {
  bool _hasAttemptedFetch = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasAttemptedFetch) {
      _fetchPaymentsSafely();
      _hasAttemptedFetch = true;
    }
  }

  void _fetchPaymentsSafely() {
    try {
      if (mounted) {
        final cubit = context.read<PaymentsCubit>();

        // Verificar se o estado atual é válido (não está fechado)
        // Se o estado for válido, o valor será acessível
        cubit.state;

        // Se chegou aqui, o cubit está em um estado válido
        cubit.fetchPayments();
      }
    } catch (e) {
      debugPrint('Erro ao carregar pagamentos: $e');
      // Não propagamos o erro para evitar crash da UI
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: BlocBuilder<PaymentsCubit, PaymentsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchPaymentsSafely,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          if (state.payments.isEmpty) {
            return const Center(
              child: Text('No payments found'),
            );
          }

          return RefreshIndicator(
            onRefresh: () {
              _fetchPaymentsSafely();
              // Retornar um Future completo para o RefreshIndicator
              return Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              itemCount: state.payments.length,
              itemBuilder: (context, index) {
                final payment = state.payments[index];
                return PaymentListItem(
                  payment: payment,
                  onTap: () => _navigateToPaymentDetail(payment),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewPaymentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToPaymentDetail(Payment payment) {}

  void _showNewPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Payment'),
        content: const Text('Feature under development'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
