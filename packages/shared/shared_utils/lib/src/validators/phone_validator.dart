
class PhoneValidator {
  
  static bool isValidBR(String phone) {
    
    final numericPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    
    if (numericPhone.length < 10 || numericPhone.length > 11) {
      return false;
    }
    
    
    final ddd = int.parse(numericPhone.substring(0, 2));
    if (ddd < 11 || ddd > 99) {
      return false;
    }
    
    
    if (numericPhone.length == 11 && numericPhone[2] != '9') {
      return false;
    }
    
    return true;
  }
  
  
  static bool isValidInternational(String phone) {
    
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    
    if (!cleanPhone.startsWith('+') || cleanPhone.length < 8) {
      return false;
    }
    
    return true;
  }
  
  
  static String? getErrorMessage(String phone) {
    if (phone.isEmpty) {
      return 'O telefone é obrigatório';
    }
    
    
    final numericPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericPhone.length < 10) {
      return 'O telefone deve ter pelo menos 10 dígitos';
    }
    
    if (numericPhone.length > 11) {
      return 'O telefone deve ter no máximo 11 dígitos';
    }
    
    if (!isValidBR(phone)) {
      return 'O telefone informado é inválido';
    }
    
    return null;
  }
}
