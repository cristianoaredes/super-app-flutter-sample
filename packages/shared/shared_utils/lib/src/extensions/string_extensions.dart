import '../formatters/document_formatter.dart';
import '../formatters/phone_formatter.dart';
import '../validators/document_validator.dart';
import '../validators/email_validator.dart';
import '../validators/phone_validator.dart';


extension StringExtensions on String {
  
  bool get isEmail => EmailValidator.isValid(this);
  
  
  bool get isCPF => DocumentValidator.isValidCPF(this);
  
  
  bool get isCNPJ => DocumentValidator.isValidCNPJ(this);
  
  
  bool get isDocument => DocumentValidator.isValidDocument(this);
  
  
  bool get isPhone => PhoneValidator.isValidBR(this);
  
  
  String get toCPF => DocumentFormatter.formatCPF(this);
  
  
  String get toCNPJ => DocumentFormatter.formatCNPJ(this);
  
  
  String get toDocument => DocumentFormatter.formatDocument(this);
  
  
  String get toPhone => PhoneFormatter.formatBR(this);
  
  
  String get withoutAccents {
    const accents = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const noAccents = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    
    String result = this;
    for (int i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], noAccents[i]);
    }
    
    return result;
  }
  
  
  String get withoutSpecialChars {
    return replaceAll(RegExp(r'[^\w\s]+'), '');
  }
  
  
  String get numericOnly {
    return replaceAll(RegExp(r'[^\d]+'), '');
  }
  
  
  String get capitalize {
    if (isEmpty) return this;
    
    return split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join(' ');
  }
  
  
  String get capitalizeFirst {
    if (isEmpty) return this;
    
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
  
  
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) {
      return this;
    }
    
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }
  
  
  bool get isAlpha => RegExp(r'^[a-zA-Z]+$').hasMatch(this);
  
  
  bool get isNumeric => RegExp(r'^[0-9]+$').hasMatch(this);
  
  
  bool get isAlphanumeric => RegExp(r'^[a-zA-Z0-9]+$').hasMatch(this);
}
