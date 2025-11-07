# ⚠️ Guia de Tratamento de Erros - Premium Bank

**Versão:** 1.0
**Data:** 2025-11-07
**Status:** Draft

---

## 🎯 Objetivo

Estabelecer uma política clara, consistente e robusta para tratamento de erros em todo o projeto Premium Bank Flutter Super App.

**Princípios Fundamentais:**
- Erros NUNCA devem ser ignorados silenciosamente
- Todos os erros devem ser logados apropriadamente
- Erros devem ser comunicados de forma user-friendly
- O app NUNCA deve crashar sem tentativa de recuperação

---

## 📋 Índice

1. [Hierarquia de Exceções](#hierarquia-de-exceções)
2. [Regras de Ouro](#regras-de-ouro)
3. [Tratamento por Camada](#tratamento-por-camada)
4. [Logging](#logging)
5. [UI/UX de Erros](#uiux-de-erros)
6. [Exemplos Práticos](#exemplos-práticos)
7. [Anti-Patterns](#anti-patterns)

---

## 🏗️ Hierarquia de Exceções

### Estrutura de Classes

```
Exception (Dart)
    │
    └── AppException (Base)
            │
            ├── NetworkException
            │       ├── NoInternetException
            │       ├── TimeoutException
            │       └── ServerException
            │
            ├── StorageException
            │       ├── ReadException
            │       └── WriteException
            │
            ├── AuthException
            │       ├── InvalidCredentialsException
            │       ├── TokenExpiredException
            │       └── UnauthorizedException
            │
            ├── BusinessException
            │       ├── ValidationException
            │       ├── InsufficientFundsException
            │       └── DuplicateTransactionException
            │
            ├── MicroAppException
            │       ├── InitializationException
            │       ├── InvalidStateException
            │       └── DisposedException
            │
            └── UnexpectedException
```

### Implementação Base

```dart
// packages/core/core_interfaces/lib/src/exceptions/app_exception.dart

/// Exceção base para todas as exceções customizadas do app
///
/// Todas as exceções devem herdar desta classe para garantir
/// tratamento consistente.
abstract class AppException implements Exception {
  /// Mensagem user-friendly do erro
  final String message;

  /// Código único do erro (para tracking e analytics)
  final String? code;

  /// Erro original (se houver)
  final dynamic originalError;

  /// Stack trace do erro
  final StackTrace? stackTrace;

  /// Timestamp de quando o erro ocorreu
  final DateTime timestamp;

  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  /// Retorna mensagem formatada para exibir ao usuário
  String get userMessage => message;

  /// Retorna mensagem técnica para logs
  String get technicalMessage {
    final buffer = StringBuffer();
    buffer.writeln('[$code] $message');
    if (originalError != null) {
      buffer.writeln('Original error: $originalError');
    }
    if (stackTrace != null) {
      buffer.writeln('Stack trace: $stackTrace');
    }
    return buffer.toString();
  }

  /// Converte para Map para analytics
  Map<String, dynamic> toAnalyticsMap() => {
    'error_code': code,
    'error_message': message,
    'timestamp': timestamp.toIso8601String(),
    'has_original_error': originalError != null,
  };

  @override
  String toString() => 'AppException{code: $code, message: $message}';
}
```

### Exceções Específicas

```dart
// Network Exceptions
class NetworkException extends AppException {
  NetworkException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code ?? 'network_error',
    originalError: originalError,
    stackTrace: stackTrace,
  );
}

class NoInternetException extends NetworkException {
  NoInternetException()
      : super(
    message: 'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
    code: 'no_internet',
  );
}

class TimeoutException extends NetworkException {
  TimeoutException()
      : super(
    message: 'A conexão expirou. Por favor, tente novamente.',
    code: 'timeout',
  );
}

// Auth Exceptions
class AuthException extends AppException {
  AuthException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code ?? 'auth_error',
    originalError: originalError,
    stackTrace: stackTrace,
  );
}

class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException()
      : super(
    message: 'Email ou senha inválidos.',
    code: 'invalid_credentials',
  );
}

// Business Exceptions
class BusinessException extends AppException {
  BusinessException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code ?? 'business_error',
    originalError: originalError,
    stackTrace: stackTrace,
  );
}

class ValidationException extends BusinessException {
  final Map<String, String> fieldErrors;

  ValidationException({
    required String message,
    required this.fieldErrors,
  }) : super(
    message: message,
    code: 'validation_error',
  );

  @override
  String get userMessage {
    final buffer = StringBuffer(message);
    if (fieldErrors.isNotEmpty) {
      buffer.write(':\n');
      fieldErrors.forEach((field, error) {
        buffer.writeln('• $field: $error');
      });
    }
    return buffer.toString();
  }
}

// MicroApp Exceptions
class MicroAppException extends AppException {
  final String microAppId;

  MicroAppException({
    required this.microAppId,
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
    message: message,
    code: code ?? 'micro_app_error',
    originalError: originalError,
    stackTrace: stackTrace,
  );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
    ...super.toAnalyticsMap(),
    'micro_app_id': microAppId,
  };
}

class InitializationException extends MicroAppException {
  InitializationException({
    required String microAppId,
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
    microAppId: microAppId,
    message: message ?? 'Falha ao inicializar módulo $microAppId',
    code: 'initialization_failed',
    originalError: originalError,
    stackTrace: stackTrace,
  );
}
```

---

## 🎯 Regras de Ouro

### 1. NUNCA Ignore Exceções

```dart
// ❌ ERRADO
try {
  await somethingRisky();
} catch (e) {
  // Ignorado silenciosamente
}

// ❌ ERRADO
try {
  await somethingRisky();
} catch (e) {
  debugPrint('Erro: $e'); // Apenas debug print
}

// ✅ CORRETO
try {
  await somethingRisky();
} catch (e, stackTrace) {
  loggingService.error(
    'Erro ao executar operação arriscada',
    error: e,
    stackTrace: stackTrace,
  );

  // Decidir: re-lançar, recuperar, ou notificar usuário
  rethrow; // ou throw CustomException(...)
}
```

### 2. Use LoggingService, Não debugPrint

```dart
// ❌ ERRADO
debugPrint('Erro: $e');
print('Erro: $e');

// ✅ CORRETO
loggingService.error('Erro ao carregar dados', error: e, stackTrace: stackTrace);
loggingService.warning('Tentativa de reinicialização');
loggingService.info('Operação concluída com sucesso');
```

### 3. Use Exceções Tipadas

```dart
// ❌ ERRADO
throw Exception('Erro de validação');
throw 'Erro';

// ✅ CORRETO
throw ValidationException(
  message: 'Dados inválidos',
  fieldErrors: {'email': 'Email inválido'},
);
```

### 4. Capture StackTrace

```dart
// ❌ ERRADO
} catch (e) {
  loggingService.error('Erro: $e');
}

// ✅ CORRETO
} catch (e, stackTrace) {
  loggingService.error(
    'Erro ao processar',
    error: e,
    stackTrace: stackTrace,
  );
}
```

### 5. Enriqueça Exceções

```dart
// ❌ ERRADO
} catch (e) {
  rethrow;
}

// ✅ CORRETO
} catch (e, stackTrace) {
  throw MicroAppException(
    microAppId: id,
    message: 'Falha ao inicializar $name',
    originalError: e,
    stackTrace: stackTrace,
  );
}
```

---

## 🏢 Tratamento por Camada

### Domain Layer (Use Cases)

**Responsabilidade:** Lançar exceções de negócio

```dart
class TransferMoneyUseCase {
  final TransactionsRepository repository;
  final LoggingService loggingService;

  Future<Transaction> execute({
    required String fromAccount,
    required String toAccount,
    required double amount,
  }) async {
    // Validações de negócio
    if (amount <= 0) {
      throw ValidationException(
        message: 'Valor da transferência deve ser positivo',
        fieldErrors: {'amount': 'Valor inválido'},
      );
    }

    try {
      // Verificar saldo
      final balance = await repository.getBalance(fromAccount);

      if (balance < amount) {
        throw BusinessException(
          message: 'Saldo insuficiente para realizar a transferência',
          code: 'insufficient_funds',
        );
      }

      // Executar transferência
      final transaction = await repository.transfer(
        from: fromAccount,
        to: toAccount,
        amount: amount,
      );

      loggingService.info('Transferência realizada com sucesso: ${transaction.id}');

      return transaction;
    } on NetworkException {
      // Re-lança exceções de rede
      rethrow;
    } catch (e, stackTrace) {
      loggingService.error(
        'Erro ao executar transferência',
        error: e,
        stackTrace: stackTrace,
      );

      throw BusinessException(
        message: 'Não foi possível completar a transferência',
        code: 'transfer_failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
```

### Data Layer (Repositories)

**Responsabilidade:** Traduzir exceções técnicas em exceções de domínio

```dart
class TransactionsRepositoryImpl implements TransactionsRepository {
  final ApiClient apiClient;
  final LoggingService loggingService;

  @override
  Future<List<Transaction>> getTransactions() async {
    try {
      final response = await apiClient.get('/transactions');

      return (response.data as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } on DioException catch (e, stackTrace) {
      loggingService.error(
        'Erro ao buscar transações da API',
        error: e,
        stackTrace: stackTrace,
      );

      // Traduzir DioException para exceção de domínio
      if (e.type == DioExceptionType.connectionTimeout) {
        throw TimeoutException();
      } else if (e.type == DioExceptionType.connectionError) {
        throw NoInternetException();
      } else if (e.response?.statusCode == 401) {
        throw AuthException(
          message: 'Sessão expirada. Faça login novamente.',
          code: 'session_expired',
        );
      } else {
        throw NetworkException(
          message: 'Erro ao carregar transações',
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    } on FormatException catch (e, stackTrace) {
      loggingService.error(
        'Erro ao parsear resposta da API',
        error: e,
        stackTrace: stackTrace,
      );

      throw NetworkException(
        message: 'Resposta inválida do servidor',
        code: 'invalid_response',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
```

### Presentation Layer (BLoC)

**Responsabilidade:** Capturar exceções e atualizar UI

```dart
class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final GetTransactionsUseCase getTransactionsUseCase;
  final AnalyticsService analyticsService;
  final LoggingService loggingService;

  TransactionsBloc({
    required this.getTransactionsUseCase,
    required this.analyticsService,
    required this.loggingService,
  }) : super(const TransactionsInitial()) {
    on<LoadTransactionsEvent>(_onLoadTransactions);
  }

  Future<void> _onLoadTransactions(
    LoadTransactionsEvent event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(const TransactionsLoading());

    try {
      final transactions = await getTransactionsUseCase.execute();

      analyticsService.trackEvent('transactions_loaded', {
        'count': transactions.length,
      });

      emit(TransactionsLoaded(transactions: transactions));
    } on NoInternetException catch (e) {
      loggingService.warning('Sem internet ao carregar transações');

      analyticsService.trackError('no_internet', e.message);

      emit(TransactionsError(
        message: e.userMessage,
        canRetry: true,
        errorType: ErrorType.network,
      ));
    } on TimeoutException catch (e) {
      loggingService.warning('Timeout ao carregar transações');

      analyticsService.trackError('timeout', e.message);

      emit(TransactionsError(
        message: e.userMessage,
        canRetry: true,
        errorType: ErrorType.network,
      ));
    } on AuthException catch (e, stackTrace) {
      loggingService.error(
        'Erro de autenticação',
        error: e,
        stackTrace: stackTrace,
      );

      analyticsService.trackError('auth_error', e.code ?? 'unknown');

      emit(TransactionsError(
        message: e.userMessage,
        canRetry: false,
        errorType: ErrorType.auth,
        action: ErrorAction.logout, // Força logout
      ));
    } on AppException catch (e, stackTrace) {
      loggingService.error(
        'Erro ao carregar transações',
        error: e,
        stackTrace: stackTrace,
      );

      analyticsService.trackError('load_transactions_failed', e.code ?? 'unknown');

      emit(TransactionsError(
        message: e.userMessage,
        canRetry: true,
        errorType: ErrorType.business,
      ));
    } catch (e, stackTrace) {
      // Captura exceções inesperadas
      loggingService.error(
        'Erro inesperado ao carregar transações',
        error: e,
        stackTrace: stackTrace,
      );

      analyticsService.trackError('unexpected_error', e.toString());

      emit(const TransactionsError(
        message: 'Ocorreu um erro inesperado. Por favor, tente novamente.',
        canRetry: true,
        errorType: ErrorType.unknown,
      ));
    }
  }
}
```

---

## 📝 Logging

### Níveis de Log

```dart
enum LogLevel {
  debug,   // Informações de debug (desenvolvimento)
  info,    // Informações gerais
  warning, // Avisos (algo estranho mas não crítico)
  error,   // Erros (algo deu errado)
  fatal,   // Erros críticos (app pode crashar)
}
```

### Quando Usar Cada Nível

| Nível | Quando Usar | Exemplo |
|-------|-------------|---------|
| **debug** | Desenvolvimento, debugging | `loggingService.debug('Response: $data')` |
| **info** | Operações bem-sucedidas | `loggingService.info('User logged in successfully')` |
| **warning** | Situações atípicas não críticas | `loggingService.warning('Cache miss, fetching from network')` |
| **error** | Erros recuperáveis | `loggingService.error('Failed to load data', error: e)` |
| **fatal** | Erros irrecuperáveis | `loggingService.fatal('Database corruption detected')` |

### Formato de Log

```dart
// ✅ BOM: Contexto + detalhes + erro + stack trace
loggingService.error(
  'Falha ao inicializar micro app payments',
  error: e,
  stackTrace: stackTrace,
  metadata: {
    'micro_app_id': 'payments',
    'user_id': currentUserId,
    'timestamp': DateTime.now().toIso8601String(),
  },
);

// ❌ RUIM: Apenas mensagem genérica
loggingService.error('Erro');
```

---

## 🎨 UI/UX de Erros

### Estados de Erro

```dart
enum ErrorType {
  network,      // Problemas de rede
  auth,         // Problemas de autenticação
  business,     // Regras de negócio
  validation,   // Validação de entrada
  unknown,      // Erro desconhecido
}

enum ErrorAction {
  none,         // Sem ação especial
  retry,        // Permitir retry
  logout,       // Forçar logout
  goHome,       // Voltar para home
  contact,      // Contatar suporte
}

class ErrorState {
  final String message;
  final ErrorType type;
  final ErrorAction action;
  final bool canRetry;

  const ErrorState({
    required this.message,
    required this.type,
    this.action = ErrorAction.none,
    this.canRetry = false,
  });
}
```

### Widgets de Erro

```dart
// packages/shared/design_system/lib/src/widgets/error_display.dart
class ErrorDisplay extends StatelessWidget {
  final ErrorState errorState;
  final VoidCallback? onRetry;

  const ErrorDisplay({
    Key? key,
    required this.errorState,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone baseado no tipo
            _buildIcon(),
            const SizedBox(height: 16),

            // Mensagem
            Text(
              errorState.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Ações
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (errorState.type) {
      case ErrorType.network:
        icon = Icons.wifi_off;
        color = Colors.orange;
        break;
      case ErrorType.auth:
        icon = Icons.lock_outline;
        color = Colors.red;
        break;
      case ErrorType.business:
      case ErrorType.validation:
        icon = Icons.warning_amber_rounded;
        color = Colors.amber;
        break;
      case ErrorType.unknown:
      default:
        icon = Icons.error_outline;
        color = Colors.red;
    }

    return Icon(icon, size: 64, color: color);
  }

  Widget _buildActions(BuildContext context) {
    final actions = <Widget>[];

    if (errorState.canRetry && onRetry != null) {
      actions.add(
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar Novamente'),
        ),
      );
    }

    if (errorState.action == ErrorAction.goHome) {
      actions.add(
        OutlinedButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Voltar ao Início'),
        ),
      );
    }

    if (errorState.action == ErrorAction.contact) {
      actions.add(
        TextButton(
          onPressed: () {
            // Abrir suporte
          },
          child: const Text('Contatar Suporte'),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}
```

---

## 💡 Exemplos Práticos

### Exemplo Completo: Login Flow

```dart
// Use Case
class LoginUseCase {
  Future<User> execute(String email, String password) async {
    // Validação
    if (!_isValidEmail(email)) {
      throw ValidationException(
        message: 'Email inválido',
        fieldErrors: {'email': 'Formato de email inválido'},
      );
    }

    try {
      return await authRepository.login(email, password);
    } on NetworkException {
      rethrow;
    } catch (e, stackTrace) {
      throw AuthException(
        message: 'Falha no login',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    try {
      final user = await loginUseCase.execute(event.email, event.password);

      analyticsService.trackEvent('login_success', {'user_id': user.id});
      emit(AuthAuthenticated(user: user));
    } on ValidationException catch (e) {
      emit(AuthError(
        message: e.userMessage,
        type: ErrorType.validation,
        fieldErrors: e.fieldErrors,
      ));
    } on InvalidCredentialsException catch (e) {
      analyticsService.trackEvent('login_failed', {'reason': 'invalid_credentials'});
      emit(AuthError(
        message: e.userMessage,
        type: ErrorType.auth,
        canRetry: true,
      ));
    } on NoInternetException catch (e) {
      emit(AuthError(
        message: e.userMessage,
        type: ErrorType.network,
        canRetry: true,
      ));
    } on AppException catch (e, stackTrace) {
      loggingService.error('Login failed', error: e, stackTrace: stackTrace);
      analyticsService.trackError('login_error', e.code ?? 'unknown');
      emit(AuthError(
        message: e.userMessage,
        type: ErrorType.business,
      ));
    } catch (e, stackTrace) {
      loggingService.error('Unexpected login error', error: e, stackTrace: stackTrace);
      emit(const AuthError(
        message: 'Erro inesperado. Tente novamente.',
        type: ErrorType.unknown,
        canRetry: true,
      ));
    }
  }
}

// UI
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthError) {
      return ErrorDisplay(
        errorState: ErrorState(
          message: state.message,
          type: state.type,
          canRetry: state.canRetry,
        ),
        onRetry: state.canRetry
            ? () => context.read<AuthBloc>().add(RetryLoginEvent())
            : null,
      );
    }

    return LoginForm();
  },
)
```

---

## ❌ Anti-Patterns

### 1. Swallowing Exceptions

```dart
// ❌ NUNCA FAZER
try {
  await riskyOperation();
} catch (e) {
  // Silenciosamente ignorado
}
```

### 2. Generic Exceptions

```dart
// ❌ RUIM
throw Exception('Algo deu errado');

// ✅ BOM
throw BusinessException(
  message: 'Saldo insuficiente',
  code: 'insufficient_funds',
);
```

### 3. Logging Sem Contexto

```dart
// ❌ RUIM
loggingService.error('Erro');

// ✅ BOM
loggingService.error(
  'Falha ao processar pagamento',
  error: e,
  stackTrace: stackTrace,
  metadata: {'payment_id': paymentId},
);
```

### 4. Usar debugPrint

```dart
// ❌ NUNCA
debugPrint('Erro: $e');
print('Erro: $e');

// ✅ SEMPRE
loggingService.error('Operação falhou', error: e);
```

---

## ✅ Checklist de Code Review

Ao revisar código, verificar:

- [ ] Todas as exceções são capturadas
- [ ] Stack trace está sendo capturado
- [ ] Exceções são tipadas (não genéricas)
- [ ] Logging usa LoggingService
- [ ] Analytics tracking para erros importantes
- [ ] Mensagens user-friendly
- [ ] Não há `debugPrint` ou `print`
- [ ] Try-catch não está vazio
- [ ] Erros são tratados apropriadamente por camada

---

**Última Atualização:** 2025-11-07
**Mantenedor:** Tech Lead
**Revisão:** Trimestral
