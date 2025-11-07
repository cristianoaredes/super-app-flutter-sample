/// Exceção base para todas as exceções customizadas do app
///
/// Todas as exceções devem herdar desta classe para garantir
/// tratamento consistente.
///
/// ## Uso
///
/// ```dart
/// throw BusinessException(
///   message: 'Saldo insuficiente',
///   code: 'insufficient_funds',
/// );
/// ```
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

// ============================================================================
// NETWORK EXCEPTIONS
// ============================================================================

/// Exceção relacionada a problemas de rede
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

/// Exceção quando não há conexão com a internet
class NoInternetException extends NetworkException {
  NoInternetException()
      : super(
          message:
              'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
          code: 'no_internet',
        );
}

/// Exceção quando a conexão expira
class TimeoutException extends NetworkException {
  TimeoutException()
      : super(
          message: 'A conexão expirou. Por favor, tente novamente.',
          code: 'timeout',
        );
}

/// Exceção quando há erro no servidor
class ServerException extends NetworkException {
  final int? statusCode;

  ServerException({
    String? message,
    this.statusCode,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Erro no servidor. Tente novamente mais tarde.',
          code: 'server_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'status_code': statusCode,
      };
}

// ============================================================================
// STORAGE EXCEPTIONS
// ============================================================================

/// Exceção relacionada a problemas de armazenamento
class StorageException extends AppException {
  StorageException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'storage_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exceção ao ler dados do armazenamento
class ReadException extends StorageException {
  ReadException({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Erro ao ler dados do armazenamento',
          code: 'storage_read_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exceção ao escrever dados no armazenamento
class WriteException extends StorageException {
  WriteException({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Erro ao salvar dados no armazenamento',
          code: 'storage_write_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

// ============================================================================
// AUTH EXCEPTIONS
// ============================================================================

/// Exceção relacionada a problemas de autenticação
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

/// Exceção quando credenciais são inválidas
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException()
      : super(
          message: 'Email ou senha inválidos.',
          code: 'invalid_credentials',
        );
}

/// Exceção quando token expirou
class TokenExpiredException extends AuthException {
  TokenExpiredException()
      : super(
          message: 'Sessão expirada. Faça login novamente.',
          code: 'token_expired',
        );
}

/// Exceção quando usuário não tem autorização
class UnauthorizedException extends AuthException {
  UnauthorizedException({String? message})
      : super(
          message: message ??
              'Você não tem permissão para acessar este recurso.',
          code: 'unauthorized',
        );
}

// ============================================================================
// BUSINESS EXCEPTIONS
// ============================================================================

/// Exceção relacionada a regras de negócio
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

/// Exceção de validação de dados
class ValidationException extends BusinessException {
  /// Mapa de erros por campo
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

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'field_count': fieldErrors.length,
        'fields': fieldErrors.keys.toList(),
      };
}

/// Exceção quando saldo é insuficiente
class InsufficientFundsException extends BusinessException {
  final double currentBalance;
  final double requiredAmount;

  InsufficientFundsException({
    required this.currentBalance,
    required this.requiredAmount,
  }) : super(
          message: 'Saldo insuficiente para realizar esta operação.',
          code: 'insufficient_funds',
        );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'current_balance': currentBalance,
        'required_amount': requiredAmount,
        'difference': requiredAmount - currentBalance,
      };
}

/// Exceção para transação duplicada
class DuplicateTransactionException extends BusinessException {
  final String transactionId;

  DuplicateTransactionException({
    required this.transactionId,
  }) : super(
          message: 'Esta transação já foi processada.',
          code: 'duplicate_transaction',
        );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'transaction_id': transactionId,
      };
}

// ============================================================================
// MICRO APP EXCEPTIONS
// ============================================================================

/// Exceção relacionada a micro apps
class MicroAppException extends AppException {
  /// ID do micro app que gerou a exceção
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

/// Exceção de inicialização de micro app
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

/// Exceção de estado inválido
class InvalidStateException extends AppException {
  InvalidStateException({
    required String message,
    String? code,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: code ?? 'invalid_state',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}

/// Exceção quando micro app foi disposed
class DisposedException extends MicroAppException {
  DisposedException({
    required String microAppId,
  }) : super(
          microAppId: microAppId,
          message: 'Micro app $microAppId foi descartado e não está mais disponível.',
          code: 'disposed',
        );
}

// ============================================================================
// ROUTE EXCEPTIONS
// ============================================================================

/// Exceção base para problemas com parâmetros de rota
abstract class RouteParamException extends AppException {
  RouteParamException({
    required String message,
    required String code,
  }) : super(
          message: message,
          code: code,
        );
}

/// Exceção quando parâmetro obrigatório está ausente
class RouteParamMissingException extends RouteParamException {
  final String paramName;

  RouteParamMissingException({
    required this.paramName,
  }) : super(
          message: 'Parâmetro obrigatório "$paramName" não encontrado na rota',
          code: 'route_param_missing',
        );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'param_name': paramName,
      };
}

/// Exceção quando parâmetro tem formato inválido
class RouteParamInvalidException extends RouteParamException {
  final String paramName;
  final String receivedValue;
  final String expectedFormat;

  RouteParamInvalidException({
    required this.paramName,
    required this.receivedValue,
    required this.expectedFormat,
  }) : super(
          message:
              'Parâmetro "$paramName" tem formato inválido. Esperado: $expectedFormat, Recebido: $receivedValue',
          code: 'route_param_invalid',
        );

  @override
  Map<String, dynamic> toAnalyticsMap() => {
        ...super.toAnalyticsMap(),
        'param_name': paramName,
        'received_value': receivedValue,
        'expected_format': expectedFormat,
      };
}

// ============================================================================
// UNEXPECTED EXCEPTION
// ============================================================================

/// Exceção para erros inesperados
class UnexpectedException extends AppException {
  UnexpectedException({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) : super(
          message: message ?? 'Ocorreu um erro inesperado. Por favor, tente novamente.',
          code: 'unexpected_error',
          originalError: originalError,
          stackTrace: stackTrace,
        );
}
