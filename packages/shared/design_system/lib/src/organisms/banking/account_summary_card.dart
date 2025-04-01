import 'package:flutter/material.dart';
import '../../atoms/spacing.dart';
import '../../molecules/banking/amount_display.dart';

class AccountSummaryCard extends StatefulWidget {
  final double balance;
  final double? income;
  final double? expenses;
  final bool showDetails;
  final bool showActions;
  final VoidCallback? onTransferTap;
  final VoidCallback? onPaymentTap;
  final VoidCallback? onDepositTap;
  final VoidCallback? onSeeAllTap;
  
  const AccountSummaryCard({
    Key? key,
    required this.balance,
    this.income,
    this.expenses,
    this.showDetails = true,
    this.showActions = true,
    this.onTransferTap,
    this.onPaymentTap,
    this.onDepositTap,
    this.onSeeAllTap,
  }) : super(key: key);

  @override
  State<AccountSummaryCard> createState() => _AccountSummaryCardState();
}

class _AccountSummaryCardState extends State<AccountSummaryCard> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      margin: EdgeInsets.all(BankSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(BankSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo Disponível',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _hideBalance ? Icons.visibility_off : Icons.visibility,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _hideBalance = !_hideBalance;
                    });
                  },
                ),
              ],
            ),
            
            
            Padding(
              padding: EdgeInsets.symmetric(vertical: BankSpacing.sm),
              child: _hideBalance
                  ? Container(
                      height: 30,
                      width: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : AmountDisplay(
                      amount: widget.balance,
                      type: AmountType.neutral,
                      showSign: false,
                    ),
            ),
            
            
            if (widget.showDetails && widget.income != null && widget.expenses != null) ...[
              const Divider(),
              SizedBox(height: BankSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receitas',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: BankSpacing.xxs),
                        _hideBalance
                            ? Container(
                                height: 20,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : AmountDisplay(
                                amount: widget.income!,
                                type: AmountType.positive,
                                showSign: true,
                                compact: true,
                              ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Despesas',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: BankSpacing.xxs),
                        _hideBalance
                            ? Container(
                                height: 20,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : AmountDisplay(
                                amount: -widget.expenses!,
                                type: AmountType.negative,
                                showSign: false,
                                compact: true,
                              ),
                      ],
                    ),
                  ),
                  if (widget.onSeeAllTap != null)
                    TextButton(
                      onPressed: widget.onSeeAllTap,
                      child: Text('Ver tudo'),
                    ),
                ],
              ),
            ],
            
            
            if (widget.showActions) ...[
              SizedBox(height: BankSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (widget.onTransferTap != null)
                    _buildActionButton(
                      context,
                      'Transferir',
                      Icons.swap_horiz,
                      widget.onTransferTap!,
                    ),
                  if (widget.onPaymentTap != null)
                    _buildActionButton(
                      context,
                      'Pagar',
                      Icons.payment,
                      widget.onPaymentTap!,
                    ),
                  if (widget.onDepositTap != null)
                    _buildActionButton(
                      context,
                      'Depositar',
                      Icons.add,
                      widget.onDepositTap!,
                    ),
                ],
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RawMaterialButton(
          onPressed: onTap,
          elevation: 0,
          fillColor: colorScheme.primaryContainer,
          shape: const CircleBorder(),
          constraints: const BoxConstraints.tightFor(
            width: 56,
            height: 56,
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        SizedBox(height: BankSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
