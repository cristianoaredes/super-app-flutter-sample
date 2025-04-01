
class DocumentFormatter {
  
  static String formatCPF(String cpf) {
    
    final numericCPF = cpf.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericCPF.length != 11) {
      return cpf;
    }
    
    return '${numericCPF.substring(0, 3)}.${numericCPF.substring(3, 6)}.${numericCPF.substring(6, 9)}-${numericCPF.substring(9)}';
  }
  
  
  static String formatCNPJ(String cnpj) {
    
    final numericCNPJ = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericCNPJ.length != 14) {
      return cnpj;
    }
    
    return '${numericCNPJ.substring(0, 2)}.${numericCNPJ.substring(2, 5)}.${numericCNPJ.substring(5, 8)}/${numericCNPJ.substring(8, 12)}-${numericCNPJ.substring(12)}';
  }
  
  
  static String formatDocument(String document) {
    
    final numericDocument = document.replaceAll(RegExp(r'[^\d]'), '');
    
    if (numericDocument.length == 11) {
      return formatCPF(numericDocument);
    } else if (numericDocument.length == 14) {
      return formatCNPJ(numericDocument);
    }
    
    return document;
  }
  
  
  static String unformatDocument(String document) {
    return document.replaceAll(RegExp(r'[^\d]'), '');
  }
  
  
  static String maskDocument(String document) {
    final unformatted = unformatDocument(document);
    
    if (unformatted.length == 11) {
      
      return '${unformatted.substring(0, 3)}.${unformatted.substring(3, 6)}.${unformatted.substring(6, 9)}-**';
    } else if (unformatted.length == 14) {
      
      return '${unformatted.substring(0, 2)}.${unformatted.substring(2, 5)}.${unformatted.substring(5, 8)}/****-**';
    }
    
    return document;
  }
}
