
class PasswordValidator {
  
  static bool isValid(String password) {
    return password.length >= 6;
  }
  
  
  static bool isValidStrong(String password) {
    
    if (password.length < 8) {
      return false;
    }
    
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return false;
    }
    
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return false;
    }
    
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return false;
    }
    
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return false;
    }
    
    return true;
  }
  
  
  static int getStrength(String password) {
    int strength = 0;
    
    
    if (password.length >= 8) {
      strength += 25;
    } else if (password.length >= 6) {
      strength += 10;
    }
    
    
    if (password.contains(RegExp(r'[A-Z]'))) {
      strength += 20;
    }
    
    
    if (password.contains(RegExp(r'[a-z]'))) {
      strength += 20;
    }
    
    
    if (password.contains(RegExp(r'[0-9]'))) {
      strength += 20;
    }
    
    
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      strength += 20;
    }
    
    
    return strength > 100 ? 100 : strength;
  }
  
  
  static String? getErrorMessage(String password) {
    if (password.isEmpty) {
      return 'A senha é obrigatória';
    }
    
    if (password.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    
    return null;
  }
  
  
  static String? getStrongErrorMessage(String password) {
    if (password.isEmpty) {
      return 'A senha é obrigatória';
    }
    
    if (password.length < 8) {
      return 'A senha deve ter pelo menos 8 caracteres';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'A senha deve conter pelo menos uma letra maiúscula';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'A senha deve conter pelo menos uma letra minúscula';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'A senha deve conter pelo menos um número';
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'A senha deve conter pelo menos um caractere especial';
    }
    
    return null;
  }
}
