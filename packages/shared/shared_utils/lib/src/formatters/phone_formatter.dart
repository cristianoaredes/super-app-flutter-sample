
class PhoneFormatter {
  
  static String formatBR(String phone) {
    
    final numericPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericPhone.length < 10) {
      return phone;
    }
    
    if (numericPhone.length == 10) {
      
      return '(${numericPhone.substring(0, 2)}) ${numericPhone.substring(2, 6)}-${numericPhone.substring(6)}';
    } else if (numericPhone.length == 11) {
      
      return '(${numericPhone.substring(0, 2)}) ${numericPhone.substring(2, 7)}-${numericPhone.substring(7)}';
    }
    
    return phone;
  }
  
  
  static String formatInternational(String phone) {
    
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!cleanPhone.startsWith('+')) {
      return formatBR(cleanPhone);
    }
    
    final countryCode = cleanPhone.substring(0, 3); 
    final nationalNumber = cleanPhone.substring(3);
    
    return '$countryCode ${formatBR(nationalNumber)}';
  }
  
  
  static String unformatPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }
  
  
  static String maskPhone(String phone) {
    final unformatted = unformatPhone(phone);
    
    if (unformatted.length == 10) {
      
      return '(${unformatted.substring(0, 2)}) ****-${unformatted.substring(6)}';
    } else if (unformatted.length == 11) {
      
      return '(${unformatted.substring(0, 2)}) *****-${unformatted.substring(7)}';
    }
    
    return phone;
  }
}
