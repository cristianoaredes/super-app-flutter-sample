import '../formatters/date_formatter.dart';


extension DateTimeExtensions on DateTime {
  
  String get toBR => DateFormatter.formatBR(this);
  
  
  String get toUS => DateFormatter.formatUS(this);
  
  
  String get toISO => DateFormatter.formatISO(this);
  
  
  String get toBRDateTime => DateFormatter.formatBRDateTime(this);
  
  
  String get toUSDateTime => DateFormatter.formatUSDateTime(this);
  
  
  String get toISODateTime => DateFormatter.formatISODateTime(this);
  
  
  String get toRelative => DateFormatter.getRelativeTime(this);
  
  
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }
  
  
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }
  
  
  bool get isWeekend => weekday == DateTime.saturday || weekday == DateTime.sunday;
  
  
  bool get isWeekday => !isWeekend;
  
  
  DateTime get startOfDay => DateTime(year, month, day);
  
  
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);
  
  
  DateTime get startOfWeek {
    final daysToSubtract = (weekday - DateTime.monday) % 7;
    return DateTime(year, month, day - daysToSubtract);
  }
  
  
  DateTime get endOfWeek {
    final daysToAdd = (DateTime.sunday - weekday) % 7;
    return DateTime(year, month, day + daysToAdd, 23, 59, 59, 999);
  }
  
  
  DateTime get startOfMonth => DateTime(year, month, 1);
  
  
  DateTime get endOfMonth {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, lastDay, 23, 59, 59, 999);
  }
  
  
  DateTime get startOfYear => DateTime(year, 1, 1);
  
  
  DateTime get endOfYear => DateTime(year, 12, 31, 23, 59, 59, 999);
  
  
  DateTime addDays(int days) => add(Duration(days: days));
  
  
  DateTime addWeeks(int weeks) => add(Duration(days: weeks * 7));
  
  
  DateTime addMonths(int months) {
    final newMonth = month + months;
    final newYear = year + (newMonth - 1) ~/ 12;
    final normalizedMonth = ((newMonth - 1) % 12) + 1;
    
    var newDay = day;
    final lastDayOfMonth = DateTime(newYear, normalizedMonth + 1, 0).day;
    if (newDay > lastDayOfMonth) {
      newDay = lastDayOfMonth;
    }
    
    return DateTime(newYear, normalizedMonth, newDay, hour, minute, second, millisecond, microsecond);
  }
  
  
  DateTime addYears(int years) => DateTime(year + years, month, day, hour, minute, second, millisecond, microsecond);
  
  
  bool isBetween(DateTime start, DateTime end) => isAfter(start) && isBefore(end);
}
