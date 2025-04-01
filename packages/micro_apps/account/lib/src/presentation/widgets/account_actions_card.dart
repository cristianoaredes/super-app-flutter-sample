import 'package:flutter/material.dart';


class AccountActionsCard extends StatelessWidget {
  final VoidCallback onTransferTap;
  final VoidCallback onStatementTap;
  
  const AccountActionsCard({
    super.key,
    required this.onTransferTap,
    required this.onStatementTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  'Transferir',
                  Icons.send,
                  onTransferTap,
                ),
                _buildActionButton(
                  context,
                  'Extrato',
                  Icons.receipt_long,
                  onStatementTap,
                ),
                _buildActionButton(
                  context,
                  'Pix',
                  Icons.bolt,
                  () {
                    
                  },
                ),
                _buildActionButton(
                  context,
                  'Cartões',
                  Icons.credit_card,
                  () {
                    
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: onTap,
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
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
