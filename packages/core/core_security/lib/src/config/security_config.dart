/// Configuração de segurança da aplicação
class SecurityConfig {
  /// Versão mínima do Android suportada
  static const int minAndroidSdkVersion = 21; // Android 5.0

  /// Versão mínima do iOS suportada
  static const String minIOSVersion = '12.0';

  /// Tempo de expiração de sessão (inatividade)
  static const Duration sessionTimeout = Duration(minutes: 15);

  /// Tempo de expiração de token de acesso
  static const Duration accessTokenExpiration = Duration(hours: 1);

  /// Tempo de expiração de token de refresh
  static const Duration refreshTokenExpiration = Duration(days: 30);

  /// Número máximo de tentativas de login antes de bloqueio
  static const int maxLoginAttempts = 5;

  /// Tempo de bloqueio após exceder tentativas
  static const Duration loginBlockDuration = Duration(minutes: 30);

  /// Requisitos de senha
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;
  static const bool passwordRequireUppercase = true;
  static const bool passwordRequireLowercase = true;
  static const bool passwordRequireNumber = true;
  static const bool passwordRequireSpecialChar = true;

  /// Rate limiting
  static const int maxRequestsPerMinute = 60;
  static const int maxLoginAttemptsPerMinute = 5;

  /// Configuração de certificados SSL (Certificate Pinning)
  ///
  /// SHA-256 fingerprints dos certificados válidos
  /// Para gerar: openssl x509 -in certificate.crt -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
  static const List<String> sslCertificateFingerprints = [
    // Certificado principal
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    // Certificado backup
    'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  ];

  /// Domínios permitidos para requisições de rede
  static const List<String> allowedDomains = [
    'api.premiumbank.com',
    'auth.premiumbank.com',
    'cdn.premiumbank.com',
  ];

  /// Domínios bloqueados (lista negra)
  static const List<String> blockedDomains = [];

  /// Headers de segurança obrigatórios em todas as requisições
  static const Map<String, String> securityHeaders = {
    'X-Frame-Options': 'DENY',
    'X-Content-Type-Options': 'nosniff',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  };

  /// User Agent customizado
  static const String userAgent = 'PremiumBank/1.0';

  /// Configuração de biometria
  static const bool biometricEnabled = true;
  static const bool biometricOptional = true; // Usuário pode escolher não usar
  static const String biometricPrompt = 'Autentique-se para continuar';

  /// Configuração de logs
  static const bool enableSecurityLogs = true;
  static const bool sanitizeLogs = true; // Remove dados sensíveis dos logs

  /// Chaves sensíveis que nunca devem ser logadas
  static const List<String> sensitiveKeys = [
    'password',
    'token',
    'secret',
    'apikey',
    'api_key',
    'authorization',
    'credit_card',
    'card_number',
    'cvv',
    'cpf',
    'ssn',
    'private_key',
  ];

  /// Configuração de obfuscação
  static const bool enableObfuscation = true; // Em produção
  static const bool keepDebugInfo = false; // Em produção

  /// Detectar dispositivos comprometidos (root/jailbreak)
  static const bool detectRootedDevice = true;
  static const bool blockRootedDevice = false; // Apenas avisa, não bloqueia

  /// Configuração de integridade
  static const bool enableIntegrityChecks = true;
  static const bool validateAppSignature = true;

  /// Timeouts de rede
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Configuração de cache
  static const Duration cacheMaxAge = Duration(hours: 24);
  static const bool cacheEncrypted = true;

  /// Verifica se está em modo de produção
  static bool get isProduction {
    return const bool.fromEnvironment('dart.vm.product');
  }

  /// Verifica se está em modo de desenvolvimento
  static bool get isDevelopment => !isProduction;
}
