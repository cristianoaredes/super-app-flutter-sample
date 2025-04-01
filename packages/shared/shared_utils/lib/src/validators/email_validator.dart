
class EmailValidator {
  
  static bool isValid(String email) {
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    return emailRegex.hasMatch(email);
  }
  
  
  static bool isValidStrict(String email) {
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$',
    );
    
    return emailRegex.hasMatch(email);
  }
  
  
  static String? getErrorMessage(String email) {
    if (email.isEmpty) {
      return 'O e-mail é obrigatório';
    }
    
    if (!email.contains('@')) {
      return 'O e-mail deve conter o caractere @';
    }
    
    if (!email.contains('.')) {
      return 'O e-mail deve conter pelo menos um ponto';
    }
    
    if (!isValid(email)) {
      return 'O e-mail informado é inválido';
    }
    
    return null;
  }
}
