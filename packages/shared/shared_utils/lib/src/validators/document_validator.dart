
class DocumentValidator {
  
  static bool isValidCPF(String cpf) {
    
    final numericCPF = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    
    if (numericCPF.length != 11) {
      return false;
    }
    
    
    if (RegExp(r'^(\d)\1{10}$').hasMatch(numericCPF)) {
      return false;
    }
    
    
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(numericCPF[i]) * (10 - i);
    }
    int remainder = 11 - (sum % 11);
    int firstDigit = remainder >= 10 ? 0 : remainder;
    
    
    if (int.parse(numericCPF[9]) != firstDigit) {
      return false;
    }
    
    
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(numericCPF[i]) * (11 - i);
    }
    remainder = 11 - (sum % 11);
    int secondDigit = remainder >= 10 ? 0 : remainder;
    
    
    return int.parse(numericCPF[10]) == secondDigit;
  }
  
  
  static bool isValidCNPJ(String cnpj) {
    
    final numericCNPJ = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    
    
    if (numericCNPJ.length != 14) {
      return false;
    }
    
    
    if (RegExp(r'^(\d)\1{13}$').hasMatch(numericCNPJ)) {
      return false;
    }
    
    
    int sum = 0;
    int weight = 2;
    for (int i = 11; i >= 0; i--) {
      sum += int.parse(numericCNPJ[i]) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    int remainder = sum % 11;
    int firstDigit = remainder < 2 ? 0 : 11 - remainder;
    
    
    if (int.parse(numericCNPJ[12]) != firstDigit) {
      return false;
    }
    
    
    sum = 0;
    weight = 2;
    for (int i = 12; i >= 0; i--) {
      sum += int.parse(numericCNPJ[i]) * weight;
      weight = weight == 9 ? 2 : weight + 1;
    }
    remainder = sum % 11;
    int secondDigit = remainder < 2 ? 0 : 11 - remainder;
    
    
    return int.parse(numericCNPJ[13]) == secondDigit;
  }
  
  
  static bool isValidDocument(String document) {
    
    final numericDocument = document.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericDocument.length == 11) {
      return isValidCPF(numericDocument);
    } else if (numericDocument.length == 14) {
      return isValidCNPJ(numericDocument);
    }
    
    return false;
  }
}
