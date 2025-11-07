# Core Security Package

Pacote de segurança do Premium Bank Super App contendo serviços, validadores e configurações de segurança.

## Funcionalidades

### 🔐 Secure Storage

Armazenamento seguro de dados sensíveis usando:
- **Android**: EncryptedSharedPreferences
- **iOS**: Keychain
- **Linux/Windows**: libsecret/Credential Manager

```dart
import 'package:core_security/core_security.dart';

// Instanciar serviço
final storage = SecureStorageServiceImpl();

// Salvar token
await storage.saveAccessToken('eyJhbGc...');

// Recuperar token
final token = await storage.getAccessToken();

// Limpar credenciais
await storage.clearAuthCredentials();
```

### ✅ Input Validation

Validação e sanitização de entrada de dados:

```dart
import 'package:core_security/core_security.dart';

// Validar email
final emailError = InputValidator.validateEmail('user@example.com');
if (emailError != null) {
  print('Email inválido: $emailError');
}

// Validar senha
final passwordError = InputValidator.validatePassword('MyP@ssw0rd');

// Validar CPF
final cpfError = InputValidator.validateCPF('123.456.789-00');

// Sanitizar HTML (prevenir XSS)
final safeHtml = InputValidator.sanitizeHtml('<script>alert("xss")</script>');

// Sanitizar SQL (prevenir SQL injection)
final safeSql = InputValidator.sanitizeSql("'; DROP TABLE users--");
```

### ⚙️ Security Configuration

Configurações centralizadas de segurança:

```dart
import 'package:core_security/core_security.dart';

// Acessar configurações
print('Session timeout: ${SecurityConfig.sessionTimeout}');
print('Max login attempts: ${SecurityConfig.maxLoginAttempts}');
print('SSL Fingerprints: ${SecurityConfig.sslCertificateFingerprints}');

// Verificar ambiente
if (SecurityConfig.isProduction) {
  print('Running in production mode');
}
```

## Instalação

Adicione ao `pubspec.yaml`:

```yaml
dependencies:
  core_security:
    path: ../core/core_security
```

## Uso

### Secure Storage Service

```dart
class AuthService {
  final SecureStorageServiceImpl _storage;

  AuthService(this._storage);

  Future<void> login(String email, String password) async {
    // ... faz autenticação ...

    // Salva tokens de forma segura
    await _storage.saveAuthCredentials(
      userId: user.id,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
  }

  Future<void> logout() async {
    // Limpa todos os dados sensíveis
    await _storage.clearAuthCredentials();
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.getAccessToken();
    return token != null && await _storage.isTokenValid();
  }
}
```

### Input Validators em Formulários

```dart
class LoginForm extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Email'),
            validator: InputValidator.validateEmail,
          ),
          TextFormField(
            decoration: InputDecoration(labelText: 'Senha'),
            obscureText: true,
            validator: InputValidator.validatePassword,
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Formulário válido
              }
            },
            child: Text('Login'),
          ),
        ],
      ),
    );
  }
}
```

### Validação Customizada

```dart
class PaymentForm extends StatelessWidget {
  String? _validatePaymentAmount(String? value) {
    // Validação básica
    final error = InputValidator.validateAmount(value);
    if (error != null) return error;

    // Validação customizada com limites
    return InputValidator.validateAmount(
      value,
      min: 10.0,  // Mínimo R$ 10,00
      max: 10000.0,  // Máximo R$ 10.000,00
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      decoration: InputDecoration(labelText: 'Valor'),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: _validatePaymentAmount,
    );
  }
}
```

## Validadores Disponíveis

| Validador | Descrição | Uso |
|-----------|-----------|-----|
| `validateEmail` | Valida formato de email | Login, cadastro |
| `validatePassword` | Valida senha forte | Cadastro, alteração de senha |
| `validateCPF` | Valida CPF brasileiro | Cadastro, KYC |
| `validatePhone` | Valida telefone brasileiro | Cadastro, contato |
| `validateAmount` | Valida valor monetário | Pagamentos, transferências |
| `validateName` | Valida nome de pessoa | Cadastro |
| `validateLength` | Valida comprimento de string | Campos gerais |
| `sanitizeHtml` | Remove tags HTML | Prevenir XSS |
| `sanitizeSql` | Remove comandos SQL | Prevenir SQL injection |
| `removeDangerousChars` | Remove caracteres perigosos | Sanitização geral |

## Configurações de Segurança

### Requisitos de Senha

```dart
SecurityConfig.passwordMinLength = 8
SecurityConfig.passwordMaxLength = 128
SecurityConfig.passwordRequireUppercase = true
SecurityConfig.passwordRequireLowercase = true
SecurityConfig.passwordRequireNumber = true
SecurityConfig.passwordRequireSpecialChar = true
```

### Timeouts e Limites

```dart
SecurityConfig.sessionTimeout = Duration(minutes: 15)
SecurityConfig.accessTokenExpiration = Duration(hours: 1)
SecurityConfig.refreshTokenExpiration = Duration(days: 30)
SecurityConfig.maxLoginAttempts = 5
SecurityConfig.loginBlockDuration = Duration(minutes: 30)
```

### Certificate Pinning

```dart
SecurityConfig.sslCertificateFingerprints = [
  'AAAA...', // Certificado principal
  'BBBB...', // Certificado backup
]
```

## Boas Práticas

### ✅ DO

- Use `SecureStorageServiceImpl` para todos os dados sensíveis
- Sempre valide entrada do usuário antes de processar
- Sanitize dados antes de exibir ou armazenar
- Use certificado pinning em produção
- Limpe credenciais no logout
- Implemente rate limiting
- Use timeouts adequados

### ❌ DON'T

- Nunca use SharedPreferences para tokens ou senhas
- Nunca armazene senhas em texto plano
- Nunca commite tokens/secrets no código
- Nunca confie em dados do cliente sem validação
- Nunca logue dados sensíveis
- Nunca desabilite SSL em produção

## Testes

```bash
# Rodar testes
cd packages/core/core_security
flutter test

# Com cobertura
flutter test --coverage
```

## Documentação Adicional

- [SECURITY.md](../../../docs/security/SECURITY.md) - Guia completo de segurança
- [ProGuard Rules](../../../super_app/android/app/proguard-rules.pro) - Regras de obfuscação
- [Network Security Config](../../../super_app/android/app/src/main/res/xml/network_security_config.xml) - Configuração Android

## Dependências

- `flutter_secure_storage`: ^9.0.0 - Armazenamento seguro
- `crypto`: ^3.0.3 - Funções criptográficas
- `encrypt`: ^5.0.3 - Criptografia de dados
- `jwt_decoder`: ^2.0.1 - Decodificação de JWT
- `local_auth`: ^2.1.8 - Autenticação biométrica

## Licença

Proprietary - Premium Bank © 2024
