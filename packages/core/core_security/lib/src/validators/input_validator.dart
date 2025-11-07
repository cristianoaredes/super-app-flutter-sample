import 'dart:convert';

/// Validador de entrada para proteger contra ataques
///
/// Fornece validação e sanitização de dados de entrada
class InputValidator {
  // Regex patterns
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final _phoneRegex = RegExp(
    r'^\(?[1-9]{2}\)? ?(?:[2-8]|9[1-9])[0-9]{3}\-?[0-9]{4}$',
  );

  /// Lista de senhas comuns (top 100)
  static const _commonPasswords = [
    '12345678',
    'password',
    'qwerty123',
    'abc123456',
    '11111111',
    '00000000',
    '123456789',
    'password1',
    'qwertyuiop',
    'admin123',
  ];

  /// Valida e sanitiza email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email é obrigatório';
    }

    // Remove espaços
    value = value.trim();

    // Verifica comprimento máximo (RFC 5321)
    if (value.length > 254) {
      return 'Email muito longo (máximo 254 caracteres)';
    }

    // Valida formato
    if (!_emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }

    // Verifica parte local (antes do @)
    final parts = value.split('@');
    if (parts[0].length > 64) {
      return 'Parte local do email muito longa';
    }

    return null;
  }

  /// Valida senha com requisitos de segurança
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Senha é obrigatória';
    }

    // Comprimento mínimo
    if (value.length < 8) {
      return 'Senha deve ter no mínimo 8 caracteres';
    }

    // Comprimento máximo
    if (value.length > 128) {
      return 'Senha muito longa (máximo 128 caracteres)';
    }

    // Pelo menos uma letra maiúscula
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Senha deve conter pelo menos uma letra maiúscula';
    }

    // Pelo menos uma letra minúscula
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Senha deve conter pelo menos uma letra minúscula';
    }

    // Pelo menos um número
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Senha deve conter pelo menos um número';
    }

    // Pelo menos um caractere especial
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Senha deve conter pelo menos um caractere especial';
    }

    // Verifica senhas comuns
    if (_commonPasswords.contains(value.toLowerCase())) {
      return 'Esta senha é muito comum. Escolha outra.';
    }

    // Verifica sequências simples
    if (_hasSequentialChars(value)) {
      return 'Senha não pode conter sequências simples (ex: 123, abc)';
    }

    return null;
  }

  /// Valida CPF brasileiro
  static String? validateCPF(String? value) {
    if (value == null || value.isEmpty) {
      return 'CPF é obrigatório';
    }

    // Remove caracteres não numéricos
    final cpf = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cpf.length != 11) {
      return 'CPF deve ter 11 dígitos';
    }

    // Verifica se todos os dígitos são iguais
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) {
      return 'CPF inválido';
    }

    // Valida dígitos verificadores
    if (!_validateCPFDigits(cpf)) {
      return 'CPF inválido';
    }

    return null;
  }

  /// Valida telefone brasileiro
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Telefone é obrigatório';
    }

    // Remove caracteres não numéricos
    final phone = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Verifica comprimento (10 ou 11 dígitos)
    if (phone.length != 10 && phone.length != 11) {
      return 'Telefone inválido';
    }

    // Verifica formato
    if (!_phoneRegex.hasMatch(value)) {
      return 'Formato de telefone inválido';
    }

    return null;
  }

  /// Valida valor monetário
  static String? validateAmount(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return 'Valor é obrigatório';
    }

    // Remove caracteres não numéricos exceto vírgula e ponto
    final cleanValue = value.replaceAll(RegExp(r'[^0-9.,]'), '');

    // Converte para double
    final amount = double.tryParse(cleanValue.replaceAll(',', '.'));

    if (amount == null) {
      return 'Valor inválido';
    }

    if (amount <= 0) {
      return 'Valor deve ser maior que zero';
    }

    if (min != null && amount < min) {
      return 'Valor mínimo: R\$ ${min.toStringAsFixed(2)}';
    }

    if (max != null && amount > max) {
      return 'Valor máximo: R\$ ${max.toStringAsFixed(2)}';
    }

    return null;
  }

  /// Sanitiza string para prevenir SQL injection
  static String sanitizeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '')
        .replaceAll('xp_', '')
        .replaceAll('sp_', '');
  }

  /// Sanitiza HTML para prevenir XSS
  static String sanitizeHtml(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;')
        .replaceAll('&', '&amp;');
  }

  /// Sanitiza string para uso em URLs
  static String sanitizeUrl(String input) {
    return Uri.encodeComponent(input);
  }

  /// Valida e sanitiza nome
  static String? validateName(String? value, {int maxLength = 100}) {
    if (value == null || value.isEmpty) {
      return 'Nome é obrigatório';
    }

    final name = value.trim();

    if (name.length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }

    if (name.length > maxLength) {
      return 'Nome muito longo (máximo $maxLength caracteres)';
    }

    // Verifica se contém apenas letras, espaços e acentos
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s'.-]+$").hasMatch(name)) {
      return 'Nome contém caracteres inválidos';
    }

    return null;
  }

  /// Remove caracteres perigosos de string
  static String removeDangerousChars(String input) {
    return input
        .replaceAll(RegExp(r'[<>{}]'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''); // Remove caracteres de controle
  }

  /// Valida comprimento de string
  static String? validateLength(
    String? value, {
    required int min,
    required int max,
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Campo'} é obrigatório';
    }

    if (value.length < min) {
      return '${fieldName ?? 'Campo'} deve ter no mínimo $min caracteres';
    }

    if (value.length > max) {
      return '${fieldName ?? 'Campo'} deve ter no máximo $max caracteres';
    }

    return null;
  }

  // Helpers privados

  static bool _validateCPFDigits(String cpf) {
    // Primeiro dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;

    // Segundo dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;

    return cpf[9] == digit1.toString() && cpf[10] == digit2.toString();
  }

  static bool _hasSequentialChars(String password) {
    // Verifica sequências numéricas (123, 234, etc)
    for (int i = 0; i < password.length - 2; i++) {
      final current = password.codeUnitAt(i);
      final next1 = password.codeUnitAt(i + 1);
      final next2 = password.codeUnitAt(i + 2);

      if (next1 == current + 1 && next2 == current + 2) {
        return true;
      }
    }

    return false;
  }
}
