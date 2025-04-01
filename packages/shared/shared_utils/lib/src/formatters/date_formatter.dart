import 'package:intl/intl.dart';


class DateFormatter {
  
  static String formatBR(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(date);
  }
  
  
  static String formatUS(DateTime date) {
    final formatter = DateFormat('MM/dd/yyyy');
    return formatter.format(date);
  }
  
  
  static String formatISO(DateTime date) {
    final formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(date);
  }
  
  
  static String formatBRDateTime(DateTime date) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(date);
  }
  
  
  static String formatUSDateTime(DateTime date) {
    final formatter = DateFormat('MM/dd/yyyy hh:mm a');
    return formatter.format(date);
  }
  
  
  static String formatISODateTime(DateTime date) {
    final formatter = DateFormat('yyyy-MM-ddTHH:mm:ss');
    return formatter.format(date);
  }
  
  
  static String formatCustom(DateTime date, String pattern) {
    final formatter = DateFormat(pattern);
    return formatter.format(date);
  }
  
  
  static DateTime? parse(String value, {String pattern = 'dd/MM/yyyy'}) {
    try {
      final formatter = DateFormat(pattern);
      return formatter.parse(value);
    } catch (e) {
      return null;
    }
  }
  
  
  static String getRelativeTime(DateTime date, {DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    final difference = currentDate.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? 'há 1 ano' : 'há $years anos';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? 'há 1 mês' : 'há $months meses';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'há 1 dia' : 'há ${difference.inDays} dias';
    } else if (difference.inHours > 0) {
      return difference.inHours == 1 ? 'há 1 hora' : 'há ${difference.inHours} horas';
    } else if (difference.inMinutes > 0) {
      return difference.inMinutes == 1 ? 'há 1 minuto' : 'há ${difference.inMinutes} minutos';
    } else {
      return 'agora';
    }
  }
}
