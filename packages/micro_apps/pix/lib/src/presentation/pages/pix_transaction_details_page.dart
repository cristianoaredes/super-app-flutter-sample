import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/pix_transaction.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class PixTransactionDetailsPage extends StatefulWidget {
  final String transactionId;
  
  const PixTransactionDetailsPage({
    super.key,
    required this.transactionId,
  });

  @override
  State<PixTransactionDetailsPage> createState() => _PixTransactionDetailsPageState();
}

class _PixTransactionDetailsPageState extends State<PixTransactionDetailsPage> {
  @override
  void initState() {
    super.initState();
    context.read<PixBloc>().add(LoadPixTransactionEvent(id: widget.transactionId));
  }
  
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para a área de transferência'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Transação'),
      ),
      body: BlocBuilder<PixBloc, PixState>(
        builder: (context, state) {
          if (state is PixTransactionLoadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (state is PixTransactionLoadedState) {
            return _buildTransactionDetails(context, state.transaction);
          }
          
          if (state is PixTransactionErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64.0,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Erro ao carregar a transação',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () {
                      context.read<PixBloc>().add(
                        LoadPixTransactionEvent(id: widget.transactionId),
                      );
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }
  
  Widget _buildTransactionDetails(BuildContext context, PixTransaction transaction) {
    final isIncoming = transaction.isIncoming;
    final statusColor = _getStatusColor(transaction.status);
    final typeColor = isIncoming ? Colors.green : Colors.red;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isIncoming ? 'Pix Recebido' : 'Pix Enviado',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Text(
                          _getStatusText(transaction.status),
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    transaction.amount.toBRL,
                    style: TextStyle(
                      fontSize: 28.0,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    transaction.date.toBRDateTime,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalhes da Transação',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoRow('Descrição', transaction.description),
                  const Divider(),
                  _buildInfoRow('ID da Transação', transaction.id),
                  if (transaction.endToEndId != null) ...[
                    const Divider(),
                    _buildInfoRow('ID End-to-End', transaction.endToEndId!),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncoming ? 'Remetente' : 'Sua Conta',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoRow('Nome', transaction.sender.name),
                  const Divider(),
                  _buildInfoRow('CPF/CNPJ', transaction.sender.document),
                  const Divider(),
                  _buildInfoRow('Banco', transaction.sender.bank),
                  if (transaction.sender.agency != null) ...[
                    const Divider(),
                    _buildInfoRow('Agência', transaction.sender.agency!),
                  ],
                  if (transaction.sender.account != null) ...[
                    const Divider(),
                    _buildInfoRow('Conta', transaction.sender.account!),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isIncoming ? 'Sua Conta' : 'Destinatário',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  _buildInfoRow('Nome', transaction.receiver.name),
                  const Divider(),
                  _buildInfoRow('CPF/CNPJ', transaction.receiver.document),
                  const Divider(),
                  _buildInfoRow('Banco', transaction.receiver.bank),
                  if (transaction.receiver.agency != null) ...[
                    const Divider(),
                    _buildInfoRow('Agência', transaction.receiver.agency!),
                  ],
                  if (transaction.receiver.account != null) ...[
                    const Divider(),
                    _buildInfoRow('Conta', transaction.receiver.account!),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          
          Card(
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ações',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        context,
                        'Compartilhar',
                        Icons.share,
                        () {
                          
                        },
                      ),
                      _buildActionButton(
                        context,
                        'Comprovante',
                        Icons.receipt,
                        () {
                          
                        },
                      ),
                      _buildActionButton(
                        context,
                        'Copiar ID',
                        Icons.copy,
                        () => _copyToClipboard(transaction.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16.0,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Icon(
                icon,
                size: 32.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Color _getStatusColor(PixTransactionStatus status) {
    switch (status) {
      case PixTransactionStatus.pending:
        return Colors.orange;
      case PixTransactionStatus.completed:
        return Colors.green;
      case PixTransactionStatus.failed:
        return Colors.red;
      case PixTransactionStatus.returned:
        return Colors.blue;
    }
  }
  
  String _getStatusText(PixTransactionStatus status) {
    switch (status) {
      case PixTransactionStatus.pending:
        return 'Pendente';
      case PixTransactionStatus.completed:
        return 'Concluído';
      case PixTransactionStatus.failed:
        return 'Falhou';
      case PixTransactionStatus.returned:
        return 'Devolvido';
    }
  }
}
