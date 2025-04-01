import 'package:flutter/material.dart';
import '../../atoms/spacing.dart';
import '../../molecules/buttons/bank_button.dart';

class BankForm extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final String? submitLabel;
  final String? cancelLabel;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  
  const BankForm({
    Key? key,
    required this.children,
    this.title,
    this.subtitle,
    this.submitLabel,
    this.cancelLabel,
    this.onSubmit,
    this.onCancel,
    this.isLoading = false,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: padding ?? EdgeInsets.all(BankSpacing.md),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          
          if (title != null) ...[
            Text(
              title!,
              style: textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              SizedBox(height: BankSpacing.xs),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: BankSpacing.lg),
          ],
          
          
          ...List.generate(children.length * 2 - 1, (index) {
            if (index.isEven) {
              return children[index ~/ 2];
            } else {
              return SizedBox(height: BankSpacing.md);
            }
          }),
          
          
          if (submitLabel != null || cancelLabel != null) ...[
            SizedBox(height: BankSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cancelLabel != null)
                  BankButton(
                    label: cancelLabel!,
                    importance: BankButtonImportance.tertiary,
                    onPressed: isLoading ? null : onCancel,
                  ),
                if (cancelLabel != null && submitLabel != null)
                  SizedBox(width: BankSpacing.sm),
                if (submitLabel != null)
                  BankButton(
                    label: submitLabel!,
                    importance: BankButtonImportance.primary,
                    onPressed: isLoading ? null : onSubmit,
                    isLoading: isLoading,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
