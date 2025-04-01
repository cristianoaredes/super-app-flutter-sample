import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../atoms/spacing.dart';

enum BankTextFieldType {
  text,
  email,
  password,
  number,
  phone,
  search,
}

class BankTextField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final BankTextFieldType type;
  final bool isRequired;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final Widget? prefix;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  const BankTextField({
    Key? key,
    required this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.type = BankTextFieldType.text,
    this.isRequired = false,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.prefix,
    this.suffix,
    this.inputFormatters,
  }) : super(key: key);

  @override
  State<BankTextField> createState() => _BankTextFieldState();
}

class _BankTextFieldState extends State<BankTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    
    TextInputType keyboardType;
    List<TextInputFormatter> formatters = widget.inputFormatters ?? [];

    switch (widget.type) {
      case BankTextFieldType.email:
        keyboardType = TextInputType.emailAddress;
        break;
      case BankTextFieldType.password:
        keyboardType = TextInputType.visiblePassword;
        break;
      case BankTextFieldType.number:
        keyboardType = TextInputType.number;
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;
      case BankTextFieldType.phone:
        keyboardType = TextInputType.phone;
        formatters.add(FilteringTextInputFormatter.digitsOnly);
        break;
      case BankTextFieldType.search:
        keyboardType = TextInputType.text;
        break;
      case BankTextFieldType.text:
      default:
        keyboardType = TextInputType.text;
        break;
    }

    
    final String labelText = widget.isRequired 
        ? '${widget.label} *' 
        : widget.label;

    
    Widget? suffixIcon;
    if (widget.type == BankTextFieldType.password) {
      suffixIcon = IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    } else if (widget.suffix != null) {
      suffixIcon = widget.suffix;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: widget.type == BankTextFieldType.password && _obscureText,
          keyboardType: keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          enabled: widget.enabled,
          inputFormatters: formatters,
          style: textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: widget.placeholder,
            errorText: widget.errorText,
            prefixIcon: widget.prefix,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: widget.enabled 
                ? colorScheme.surface 
                : colorScheme.surfaceVariant.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.outline,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.outline,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.error,
                width: 1.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: colorScheme.error,
                width: 2.0,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: BankSpacing.md,
              vertical: BankSpacing.sm,
            ),
          ),
        ),
        if (widget.helperText != null && widget.errorText == null) ...[
          SizedBox(height: BankSpacing.xxs),
          Text(
            widget.helperText!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
