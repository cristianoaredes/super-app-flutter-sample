import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment.dart';
import '../cubits/payments_cubit.dart';
import '../cubits/payments_state.dart';

class PaymentDetailPage extends StatefulWidget {
  final String id;

  const PaymentDetailPage({
    Key? key,
    required this.id,
  }) : super(key: key);

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
      ),
      body: BlocBuilder<PaymentsCubit, PaymentsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final payment = state.payments.firstWhere(
            (p) => p.id == widget.id,
            orElse: () => Payment(
              id: '',
              amount: 0,
              recipient: '',
              description: '',
              date: DateTime.now(),
              status: PaymentStatus.pending,
            ),
          );

          if (payment.id.isEmpty) {
            return const Center(
              child: Text('Payment not found'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(payment),
                const SizedBox(height: 24),
                if (payment.status == PaymentStatus.pending ||
                    payment.status == PaymentStatus.processing)
                  ElevatedButton(
                    onPressed: () => _cancelPayment(payment.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Cancel Payment'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(Payment payment) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment to ${payment.recipient}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow('Amount:', currencyFormat.format(payment.amount)),
            _buildInfoRow('Date:', dateFormat.format(payment.date)),
            _buildInfoRow('Description:', payment.description),
            _buildInfoRow('Status:', _getStatusText(payment.status)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _cancelPayment(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment'),
        content: const Text('Are you sure you want to cancel this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<PaymentsCubit>().cancelPayment(id);
              Navigator.of(context).pop(); 
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
