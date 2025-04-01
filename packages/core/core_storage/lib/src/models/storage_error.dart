import 'package:equatable/equatable.dart';


class StorageError extends Equatable {
  final String code;
  final String message;
  final dynamic originalError;
  
  const StorageError({
    required this.code,
    required this.message,
    this.originalError,
  });
  
  @override
  List<Object?> get props => [code, message];
  
  @override
  String toString() => 'StorageError(code: $code, message: $message)';
  
  
  factory StorageError.keyNotFound(String key) {
    return StorageError(
      code: 'key_not_found',
      message: 'A chave "$key" não foi encontrada no armazenamento.',
    );
  }
  
  
  factory StorageError.invalidType(String key, Type expectedType, Type actualType) {
    return StorageError(
      code: 'invalid_type',
      message: 'Tipo inválido para a chave "$key". Esperado: $expectedType, Atual: $actualType.',
    );
  }
  
  
  factory StorageError.serializationFailed(String key, dynamic error) {
    return StorageError(
      code: 'serialization_failed',
      message: 'Falha ao serializar o valor para a chave "$key".',
      originalError: error,
    );
  }
  
  
  factory StorageError.deserializationFailed(String key, dynamic error) {
    return StorageError(
      code: 'deserialization_failed',
      message: 'Falha ao desserializar o valor para a chave "$key".',
      originalError: error,
    );
  }
  
  
  factory StorageError.storageAccessFailed(String operation, dynamic error) {
    return StorageError(
      code: 'storage_access_failed',
      message: 'Falha ao acessar o armazenamento durante a operação "$operation".',
      originalError: error,
    );
  }
  
  
  factory StorageError.initializationFailed(dynamic error) {
    return StorageError(
      code: 'initialization_failed',
      message: 'Falha ao inicializar o serviço de armazenamento.',
      originalError: error,
    );
  }
}
