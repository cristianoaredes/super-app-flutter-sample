# Guia de Segurança - Premium Bank Super App

Este documento descreve as práticas de segurança implementadas no Premium Bank Super App e diretrizes para desenvolvimento seguro.

## Índice

1. [Visão Geral](#visão-geral)
2. [Armazenamento Seguro](#armazenamento-seguro)
3. [Comunicação Segura](#comunicação-segura)
4. [Autenticação e Autorização](#autenticação-e-autorização)
5. [Validação de Dados](#validação-de-dados)
6. [Proteção contra Ataques](#proteção-contra-ataques)
7. [Logs e Monitoramento](#logs-e-monitoramento)
8. [Obfuscação de Código](#obfuscação-de-código)
9. [Testes de Segurança](#testes-de-segurança)
10. [Checklist de Segurança](#checklist-de-segurança)

---

## Visão Geral

### Princípios de Segurança

1. **Defense in Depth**: Múltiplas camadas de segurança
2. **Least Privilege**: Acesso mínimo necessário
3. **Security by Design**: Segurança desde o início
4. **Zero Trust**: Nunca confie, sempre valide
5. **Privacy by Default**: Privacidade como padrão

### Classificação de Dados

| Classificação | Exemplos | Proteção |
|---------------|----------|----------|
| **Crítico** | Senhas, tokens, chaves privadas | Criptografia forte, nunca em logs |
| **Sensível** | CPF, dados bancários, biométricos | Criptografia, acesso restrito |
| **Interno** | Nomes, emails, telefones | Criptografia em repouso |
| **Público** | Nome do app, versão | Sem restrições |

---

## Armazenamento Seguro

### Flutter Secure Storage

Use `flutter_secure_storage` para dados sensíveis:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Salva token de acesso de forma segura
  Future<void> saveAccessToken(String token) async {
    await _storage.write(
      key: 'access_token',
      value: token,
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }

  /// Recupera token de acesso
  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  /// Remove token (logout)
  Future<void> clearAccessToken() async {
    await _storage.delete(key: 'access_token');
  }

  /// Limpa todos os dados seguros
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
```

### ❌ O que NÃO fazer

```dart
// ❌ NUNCA use SharedPreferences para dados sensíveis
final prefs = await SharedPreferences.getInstance();
prefs.setString('password', password); // INSEGURO!

// ❌ NUNCA armazene senhas em texto plano
final password = 'user_password_123'; // INSEGURO!

// ❌ NUNCA commite tokens/secrets no código
const apiKey = 'abc123xyz'; // INSEGURO!
```

### ✅ O que fazer

```dart
// ✅ Use flutter_secure_storage
await secureStorage.write(key: 'token', value: token);

// ✅ Use variáveis de ambiente
const apiKey = String.fromEnvironment('API_KEY');

// ✅ Use obfuscação para chaves de API (último recurso)
final key = _obfuscatedApiKey();
```

### Exemplo Completo

```dart
class SecureAuthStorage {
  final SecureStorageService _storage;
  final EncryptionService _encryption;

  SecureAuthStorage({
    required SecureStorageService storage,
    required EncryptionService encryption,
  })  : _storage = storage,
        _encryption = encryption;

  /// Salva credenciais de forma segura
  Future<void> saveCredentials({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    // Criptografa dados sensíveis
    final encryptedToken = await _encryption.encrypt(accessToken);
    final encryptedRefresh = await _encryption.encrypt(refreshToken);

    await Future.wait([
      _storage.write('user_id', userId),
      _storage.write('access_token', encryptedToken),
      _storage.write('refresh_token', encryptedRefresh),
      _storage.write(
        'token_timestamp',
        DateTime.now().toIso8601String(),
      ),
    ]);
  }

  /// Valida se token ainda é válido
  Future<bool> isTokenValid() async {
    final timestamp = await _storage.read('token_timestamp');
    if (timestamp == null) return false;

    final savedTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(savedTime);

    // Token expira em 24 horas
    return difference.inHours < 24;
  }

  /// Limpa credenciais (logout)
  Future<void> clearCredentials() async {
    await _storage.deleteAll();
  }
}
```

---

## Comunicação Segura

### Certificate Pinning

Implementação de SSL pinning para prevenir ataques man-in-the-middle:

```dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';

class SecureNetworkService {
  late final Dio _dio;

  SecureNetworkService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.premiumbank.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupCertificatePinning();
    _setupInterceptors();
  }

  void _setupCertificatePinning() {
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();

      // Callback de certificado
      client.badCertificateCallback = (cert, host, port) {
        // SHA-256 fingerprints dos certificados válidos
        final validFingerprints = [
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99',
          // Backup certificate
          '11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00',
        ];

        final certFingerprint = _getCertificateFingerprint(cert);

        if (!validFingerprints.contains(certFingerprint)) {
          _logSecurityViolation(
            'Certificate pinning failed',
            {
              'expected': validFingerprints,
              'received': certFingerprint,
              'host': host,
            },
          );
          return false;
        }

        return true;
      };

      return client;
    };
  }

  String _getCertificateFingerprint(X509Certificate cert) {
    // Implementação de fingerprint SHA-256
    final der = cert.der;
    final hash = sha256.convert(der);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Adiciona token de autenticação
          final token = await _getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Adiciona request ID para tracking
          options.headers['X-Request-ID'] = _generateRequestId();

          return handler.next(options);
        },
        onError: (error, handler) {
          _handleNetworkError(error);
          return handler.next(error);
        },
      ),
    );
  }
}
```

### TLS/SSL Best Practices

```dart
class NetworkSecurityConfig {
  /// Configuração de segurança de rede para Android
  static const String androidNetworkConfig = '''
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Produção: Apenas HTTPS -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="@raw/premium_bank_cert" />
        </trust-anchors>
    </base-config>

    <!-- Domain específico com pinning -->
    <domain-config>
        <domain includeSubdomains="true">api.premiumbank.com</domain>
        <pin-set expiration="2025-12-31">
            <pin digest="SHA-256">base64EncodedFingerprint==</pin>
            <pin digest="SHA-256">backupFingerprintBase64==</pin>
        </pin-set>
    </domain-config>

    <!-- Debug apenas em modo de desenvolvimento -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>
</network-security-config>
''';

  /// Configuração para iOS (Info.plist)
  static const String iosNetworkConfig = '''
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Bloqueia HTTP não seguro -->
    <key>NSAllowsArbitraryLoads</key>
    <false/>

    <!-- Configuração por domínio -->
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.premiumbank.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.3</string>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <true/>
            <!-- Certificate Pinning -->
            <key>NSPinnedDomains</key>
            <array>
                <string>api.premiumbank.com</string>
            </array>
        </dict>
    </dict>
</dict>
''';
}
```

---

## Autenticação e Autorização

### Autenticação Biométrica

```dart
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _storage;

  BiometricAuthService(this._storage);

  /// Verifica se biometria está disponível
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Lista tipos de biometria disponíveis
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Autentica usando biometria
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (e) {
      _logAuthenticationError(e);
      return false;
    }
  }

  /// Habilita biometria para o usuário
  Future<void> enableBiometric() async {
    final authenticated = await authenticate(
      reason: 'Habilitar autenticação biométrica',
    );

    if (authenticated) {
      await _storage.write('biometric_enabled', 'true');
    }
  }

  /// Desabilita biometria
  Future<void> disableBiometric() async {
    await _storage.delete('biometric_enabled');
  }

  /// Verifica se biometria está habilitada
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read('biometric_enabled');
    return value == 'true';
  }
}
```

### JWT Token Management

```dart
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenManager {
  final SecureStorageService _storage;
  final NetworkService _networkService;

  TokenManager({
    required SecureStorageService storage,
    required NetworkService networkService,
  })  : _storage = storage,
        _networkService = networkService;

  /// Salva tokens de autenticação
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write('access_token', accessToken),
      _storage.write('refresh_token', refreshToken),
    ]);
  }

  /// Obtém token de acesso válido
  Future<String?> getValidAccessToken() async {
    final token = await _storage.read('access_token');
    if (token == null) return null;

    // Verifica se token expirou
    if (JwtDecoder.isExpired(token)) {
      // Tenta renovar
      return await _refreshAccessToken();
    }

    return token;
  }

  /// Renova token de acesso
  Future<String?> _refreshAccessToken() async {
    try {
      final refreshToken = await _storage.read('refresh_token');
      if (refreshToken == null) return null;

      // Verifica se refresh token expirou
      if (JwtDecoder.isExpired(refreshToken)) {
        await clearTokens();
        throw SessionExpiredException();
      }

      // Solicita novo access token
      final response = await _networkService.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String?;

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );

      return newAccessToken;
    } catch (e) {
      await clearTokens();
      rethrow;
    }
  }

  /// Limpa tokens
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete('access_token'),
      _storage.delete('refresh_token'),
    ]);
  }

  /// Decodifica payload do token
  Map<String, dynamic> decodeToken(String token) {
    return JwtDecoder.decode(token);
  }

  /// Obtém tempo restante do token
  Duration? getTokenRemainingTime(String token) {
    try {
      final expirationDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      final remaining = expirationDate.difference(now);

      return remaining.isNegative ? null : remaining;
    } catch (e) {
      return null;
    }
  }
}
```

---

## Validação de Dados

### Input Sanitization

```dart
class InputValidator {
  /// Valida e sanitiza email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email é obrigatório';
    }

    // Remove espaços
    value = value.trim();

    // Regex RFC 5322 simplificado
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Email inválido';
    }

    // Verifica comprimento máximo
    if (value.length > 254) {
      return 'Email muito longo';
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
      return 'Senha muito longa';
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
    if (_isCommonPassword(value)) {
      return 'Esta senha é muito comum. Escolha outra.';
    }

    return null;
  }

  /// Valida CPF
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

  /// Sanitiza string para SQL (previne SQL injection)
  static String sanitizeSql(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll(';', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');
  }

  /// Sanitiza HTML (previne XSS)
  static String sanitizeHtml(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  /// Valida valor monetário
  static String? validateAmount(String? value) {
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

    if (amount > 999999999.99) {
      return 'Valor muito alto';
    }

    return null;
  }

  static bool _isCommonPassword(String password) {
    const commonPasswords = [
      '12345678',
      'password',
      'qwerty123',
      'abc123456',
      '11111111',
    ];

    return commonPasswords.contains(password.toLowerCase());
  }

  static bool _validateCPFDigits(String cpf) {
    // Implementação completa de validação de CPF
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(cpf[i]) * (10 - i);
    }
    int digit1 = 11 - (sum % 11);
    if (digit1 >= 10) digit1 = 0;

    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(cpf[i]) * (11 - i);
    }
    int digit2 = 11 - (sum % 11);
    if (digit2 >= 10) digit2 = 0;

    return cpf[9] == digit1.toString() && cpf[10] == digit2.toString();
  }
}
```

---

## Proteção contra Ataques

### Rate Limiting

```dart
class RateLimiter {
  final Map<String, List<DateTime>> _requestTimestamps = {};
  final Duration _timeWindow;
  final int _maxRequests;

  RateLimiter({
    required Duration timeWindow,
    required int maxRequests,
  })  : _timeWindow = timeWindow,
        _maxRequests = maxRequests;

  /// Verifica se pode fazer requisição
  bool canMakeRequest(String userId) {
    final now = DateTime.now();
    final timestamps = _requestTimestamps[userId] ?? [];

    // Remove timestamps antigos
    timestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _timeWindow,
    );

    if (timestamps.length >= _maxRequests) {
      return false;
    }

    timestamps.add(now);
    _requestTimestamps[userId] = timestamps;

    return true;
  }

  /// Obtém tempo até próxima requisição disponível
  Duration? getWaitTime(String userId) {
    final timestamps = _requestTimestamps[userId];
    if (timestamps == null || timestamps.isEmpty) {
      return null;
    }

    final oldestTimestamp = timestamps.first;
    final elapsed = DateTime.now().difference(oldestTimestamp);
    final remaining = _timeWindow - elapsed;

    return remaining.isNegative ? null : remaining;
  }

  /// Limpa histórico de um usuário
  void reset(String userId) {
    _requestTimestamps.remove(userId);
  }
}
```

### Anti-Tampering

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class IntegrityChecker {
  /// Verifica integridade de dados usando HMAC
  static String generateHmac(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString();
  }

  /// Valida integridade dos dados
  static bool verifyHmac(
    String data,
    String signature,
    String secret,
  ) {
    final expectedSignature = generateHmac(data, secret);
    return expectedSignature == signature;
  }

  /// Detecta se app foi adulterado (root/jailbreak)
  static Future<bool> isDeviceCompromised() async {
    // Verifica root (Android)
    final isRooted = await _checkRoot();

    // Verifica jailbreak (iOS)
    final isJailbroken = await _checkJailbreak();

    return isRooted || isJailbroken;
  }

  static Future<bool> _checkRoot() async {
    // Implementação de detecção de root
    // Verifica arquivos/caminhos conhecidos de root
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
    ];

    for (final path in rootPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    return false;
  }

  static Future<bool> _checkJailbreak() async {
    // Implementação de detecção de jailbreak
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
    ];

    for (final path in jailbreakPaths) {
      if (await File(path).exists()) {
        return true;
      }
    }

    return false;
  }
}
```

---

## Logs e Monitoramento

### Secure Logging

```dart
class SecureLogger {
  /// Tipos de dados sensíveis que nunca devem ser logados
  static const _sensitiveKeys = [
    'password',
    'token',
    'secret',
    'apikey',
    'authorization',
    'credit_card',
    'cpf',
    'ssn',
  ];

  /// Loga informação de forma segura
  static void info(String message, {Map<String, dynamic>? data}) {
    final sanitizedData = _sanitizeData(data);
    _log('INFO', message, sanitizedData);
  }

  /// Loga erro de forma segura
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    final sanitizedData = _sanitizeData(data);
    _log('ERROR', message, sanitizedData, error: error, stackTrace: stackTrace);
  }

  /// Loga warning de segurança
  static void securityWarning(String message, Map<String, dynamic> details) {
    final sanitizedDetails = _sanitizeData(details);
    _log('SECURITY', message, sanitizedDetails);

    // Envia para sistema de monitoramento
    _sendToSecurityMonitoring(message, sanitizedDetails);
  }

  /// Remove dados sensíveis dos logs
  static Map<String, dynamic>? _sanitizeData(Map<String, dynamic>? data) {
    if (data == null) return null;

    final sanitized = Map<String, dynamic>.from(data);

    for (final key in sanitized.keys.toList()) {
      if (_isSensitiveKey(key)) {
        sanitized[key] = '***REDACTED***';
      } else if (sanitized[key] is Map) {
        sanitized[key] = _sanitizeData(sanitized[key] as Map<String, dynamic>);
      }
    }

    return sanitized;
  }

  static bool _isSensitiveKey(String key) {
    final lowerKey = key.toLowerCase();
    return _sensitiveKeys.any((sensitive) => lowerKey.contains(sensitive));
  }

  static void _log(
    String level,
    String message,
    Map<String, dynamic>? data, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Implementação de log
    // Em produção, envia para serviço de logging (Firebase, Sentry, etc)
    print('[$level] $message ${data != null ? jsonEncode(data) : ''}');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('Stack: $stackTrace');
  }

  static void _sendToSecurityMonitoring(
    String message,
    Map<String, dynamic> details,
  ) {
    // Envia evento de segurança para monitoramento
    // Integração com SIEM ou serviço de segurança
  }
}
```

---

## Obfuscação de Código

### Build Configuration

```bash
# Build Android com obfuscação
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Build iOS com obfuscação
flutter build ios --release --obfuscate --split-debug-info=build/ios/symbols

# Build para todas as plataformas
melos run build:release --obfuscate
```

### ProGuard Rules (Android)

```proguard
# android/app/proguard-rules.pro

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve annotations
-keepattributes *Annotation*

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Dio
-keep class com.google.gson.** { *; }
-keepattributes Signature

# Models (ajuste conforme necessário)
-keep class com.premiumbank.models.** { *; }

# Impede remoção de métodos usados via reflection
-keepclassmembers class * {
    @retrofit2.http.* <methods>;
}
```

---

## Testes de Segurança

### Security Test Checklist

```dart
// test/security/security_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security Tests', () {
    group('Storage Security', () {
      test('should not store sensitive data in SharedPreferences', () {
        // Verificar que dados sensíveis não usam SharedPreferences
      });

      test('should encrypt data before storing', () {
        // Verificar criptografia de dados
      });

      test('should clear sensitive data on logout', () {
        // Verificar limpeza de dados
      });
    });

    group('Network Security', () {
      test('should use HTTPS for all API calls', () {
        // Verificar uso de HTTPS
      });

      test('should validate SSL certificates', () {
        // Verificar validação de certificados
      });

      test('should include authentication headers', () {
        // Verificar headers de autenticação
      });
    });

    group('Input Validation', () {
      test('should sanitize user input', () {
        // Verificar sanitização
      });

      test('should validate email format', () {
        // Verificar validação de email
      });

      test('should enforce password requirements', () {
        // Verificar requisitos de senha
      });
    });

    group('Authentication', () {
      test('should expire tokens after timeout', () {
        // Verificar expiração de tokens
      });

      test('should refresh tokens automatically', () {
        // Verificar refresh de tokens
      });

      test('should clear tokens on logout', () {
        // Verificar limpeza de tokens
      });
    });
  });
}
```

---

## Checklist de Segurança

### Pré-Release

- [ ] **Armazenamento**
  - [ ] Dados sensíveis em flutter_secure_storage
  - [ ] Nenhum dado sensível em SharedPreferences
  - [ ] Nenhuma senha ou token hardcoded
  - [ ] Limpeza de dados no logout

- [ ] **Rede**
  - [ ] Certificate pinning configurado
  - [ ] Apenas HTTPS
  - [ ] Timeout configurado
  - [ ] Retry logic com backoff

- [ ] **Autenticação**
  - [ ] Token refresh implementado
  - [ ] Biometria opcional
  - [ ] Session timeout
  - [ ] Logout limpa todos os dados

- [ ] **Validação**
  - [ ] Input sanitization
  - [ ] Validação client-side e server-side
  - [ ] Proteção contra SQL injection
  - [ ] Proteção contra XSS

- [ ] **Código**
  - [ ] Obfuscação habilitada
  - [ ] ProGuard configurado
  - [ ] Debug info separado
  - [ ] Nenhum console.log em produção

- [ ] **Logs**
  - [ ] Dados sensíveis não logados
  - [ ] Logs sanitizados
  - [ ] Monitoramento de segurança

- [ ] **Testes**
  - [ ] Security tests passando
  - [ ] Penetration test realizado
  - [ ] Code review de segurança

---

## Recursos Adicionais

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Dart Security Guidelines](https://dart.dev/guides/security)

---

**Segurança é responsabilidade de todos!** 🔒

Sempre considere segurança desde o início do desenvolvimento, não como uma correção posterior.
