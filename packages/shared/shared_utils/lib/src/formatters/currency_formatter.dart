import 'package:intl/intl.dart';


class CurrencyFormatter {
  
  static String formatBRL(double value) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    
    return formatter.format(value);
  }
  
  
  static String formatUSD(double value) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'US\$',
      decimalDigits: 2,
    );
    
    return formatter.format(value);
  }
  
  
  static String formatEUR(double value) {
    final formatter = NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
      decimalDigits: 2,
    );
    
    return formatter.format(value);
  }
  
  
  static String formatCustom({
    required double value,
    required String locale,
    required String symbol,
    int decimalDigits = 2,
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    
    return formatter.format(value);
  }
  
  
  static double? parse(String value, {String locale = 'pt_BR'}) {
    try {
      final formatter = NumberFormat.decimalPattern(locale);
      return formatter.parse(value).toDouble();
    } catch (e) {
      return null;
    }
  }
}
