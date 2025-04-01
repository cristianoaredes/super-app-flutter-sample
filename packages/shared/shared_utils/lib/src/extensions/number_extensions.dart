import 'dart:math' as math;

import '../formatters/currency_formatter.dart';


extension NumExtensions on num {
  
  String get toBRL => CurrencyFormatter.formatBRL(toDouble());

  
  String get toUSD => CurrencyFormatter.formatUSD(toDouble());

  
  String get toEUR => CurrencyFormatter.formatEUR(toDouble());

  
  String toFormat({int decimalDigits = 2, String locale = 'pt_BR'}) {
    final formatter = CurrencyFormatter.formatCustom(
      value: toDouble(),
      locale: locale,
      symbol: '',
      decimalDigits: decimalDigits,
    );

    return formatter.trim();
  }

  
  Duration get milliseconds => Duration(milliseconds: toInt());

  
  Duration get seconds => Duration(seconds: toInt());

  
  Duration get minutes => Duration(minutes: toInt());

  
  Duration get hours => Duration(hours: toInt());

  
  Duration get days => Duration(days: toInt());

  
  bool isBetween(num start, num end) => this >= start && this <= end;

  
  num atLeast(num min) => this < min ? min : this;

  
  num atMost(num max) => this > max ? max : this;

  
  num clamp(num min, num max) => this < min ? min : (this > max ? max : this);
}


extension IntExtensions on int {
  
  bool get isEven => this % 2 == 0;

  
  bool get isOdd => this % 2 != 0;

  
  bool get isPrime {
    if (this <= 1) return false;
    if (this <= 3) return true;
    if (this % 2 == 0 || this % 3 == 0) return false;

    int i = 5;
    while (i * i <= this) {
      if (this % i == 0 || this % (i + 2) == 0) return false;
      i += 6;
    }

    return true;
  }

  
  int factorial() {
    if (this < 0)
      throw ArgumentError(
          'Não é possível calcular o fatorial de um número negativo');
    if (this <= 1) return 1;

    int result = 1;
    for (int i = 2; i <= this; i++) {
      result *= i;
    }

    return result;
  }
}


extension DoubleExtensions on double {
  
  double roundTo(int places) {
    final mod = math.pow(10.0, places);
    return (this * mod).round() / mod;
  }

  
  double truncateTo(int places) {
    final mod = math.pow(10.0, places);
    return (this * mod).truncate() / mod;
  }

  
  double pow(double exponent) {
    return _pow(this, exponent);
  }

  
  static double _pow(double x, double exponent) {
    if (exponent == 0) return 1;
    if (exponent < 0) return 1 / _pow(x, -exponent);
    if (exponent.truncate() != exponent) {
      return _exp(exponent * _ln(x));
    }

    double result = 1;
    double base = x;
    int exp = exponent.toInt();

    while (exp > 0) {
      if (exp % 2 == 1) {
        result *= base;
      }
      exp >>= 1;
      base *= base;
    }

    return result;
  }

  
  static double _ln(double x) {
    if (x <= 0)
      throw ArgumentError('Logaritmo natural não definido para x <= 0');

    
    double sum = 0;
    double term = (x - 1) / (x + 1);
    double termSquared = term * term;
    double termPower = term;

    for (int i = 1; i <= 100; i += 2) {
      sum += termPower / i;
      termPower *= termSquared;
    }

    return 2 * sum;
  }

  
  static double _exp(double x) {
    
    double sum = 1;
    double term = 1;

    for (int i = 1; i <= 100; i++) {
      term *= x / i;
      sum += term;

      if (term.abs() < 1e-10) break;
    }

    return sum;
  }
}
