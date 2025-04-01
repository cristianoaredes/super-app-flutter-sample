import 'package:equatable/equatable.dart';


class ApiError extends Equatable {
  final String code;
  final String message;
  final int statusCode;
  final dynamic originalError;
  final dynamic responseData;

  const ApiError({
    required this.code,
    required this.message,
    required this.statusCode,
    this.originalError,
    this.responseData,
  });

  @override
  List<Object?> get props => [code, message, statusCode];

  @override
  String toString() =>
      'ApiError(code: $code, message: $message, statusCode: $statusCode)';

  
  bool get isConnectionError =>
      code == 'no_internet' || code == 'timeout' || code == 'connection_error';

  
  bool get isAuthError => code == 'unauthorized' || statusCode == 401;

  
  bool get isPermissionError => code == 'forbidden' || statusCode == 403;

  
  bool get isValidationError => code == 'validation_error' || statusCode == 422;

  
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  
  String get userFriendlyMessage {
    if (isConnectionError) {
      return 'Could not connect to the server. Check your internet connection and try again.';
    }

    if (isAuthError) {
      return 'Your session has expired. Please log in again.';
    }

    if (isPermissionError) {
      return 'You do not have permission to access this resource.';
    }

    if (isValidationError) {
      return 'Check the provided data and try again.';
    }

    if (isServerError) {
      return 'A server error occurred. Please try again later.';
    }

    return message;
  }
}
