import 'package:flutter/material.dart' hide Card;
import 'package:shared_utils/shared_utils.dart';

import '../../domain/entities/card.dart';
import 'card_details_header.dart';

class CardDetailsContent extends StatelessWidget {
  final Card card;
  final VoidCallback onBlockCard;
  final VoidCallback onUnblockCard;
  final void Function(DateTime startDate, DateTime endDate) onLoadStatement;

  const CardDetailsContent({
    Key? key,
    required this.card,
    required this.onBlockCard,
    required this.onUnblockCard,
    required this.onLoadStatement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        CardDetailsHeader(card: card),
        const SizedBox(height: 24.0),
        Material(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informações do Cartão',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildInfoRow('Número', card.maskedNumber),
                const Divider(),
                _buildInfoRow('Titular', card.holderName),
                const Divider(),
                _buildInfoRow('Validade', card.expirationDate.toBR),
                const Divider(),
                _buildInfoRow('Tipo', card.type),
                const Divider(),
                _buildInfoRow('Bandeira', card.brand),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Material(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Limites',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                _buildFinancialRow(
                  'Limite Total',
                  card.limit.toBRL,
                  Colors.blue,
                ),
                const Divider(),
                _buildFinancialRow(
                  'Limite Disponível',
                  card.availableLimit.toBRL,
                  Colors.green,
                ),
                const Divider(),
                _buildFinancialRow(
                  'Limite Utilizado',
                  (card.limit - card.availableLimit).toBRL,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        Material(
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
                      'Extrato',
                      Icons.receipt_long,
                      () => _showDateRangePicker(context),
                    ),
                    _buildActionButton(
                      context,
                      card.isBlocked ? 'Desbloquear' : 'Bloquear',
                      card.isBlocked ? Icons.lock_open : Icons.lock,
                      card.isBlocked ? onUnblockCard : onBlockCard,
                      color: card.isBlocked ? Colors.green : Colors.red,
                    ),
                    _buildActionButton(
                      context,
                      'Configurações',
                      Icons.settings,
                      () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color valueColor) {
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
          Text(
            value,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: valueColor,
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
    VoidCallback onPressed, {
    Color? color,
  }) {
    return Column(
      children: [
        Material(
          color: color != null
              ? color.withOpacity(0.1)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showDateRangePicker(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final pickedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDateRange != null) {
      onLoadStatement(pickedDateRange.start, pickedDateRange.end);
    }
  }
}
