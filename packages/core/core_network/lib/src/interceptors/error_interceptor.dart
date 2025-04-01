import 'dart:io';

import 'package:dio/dio.dart';

import '../models/api_error.dart';


class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    
    final apiError = _convertDioErrorToApiError(err);
    
    
    final newError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: apiError,
      message: apiError.message,
      stackTrace: err.stackTrace,
    );
    
    handler.next(newError);
  }
  
  
  ApiError _convertDioErrorToApiError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          code: 'timeout',
          message: 'A conexão expirou. Verifique sua conexão com a internet e tente novamente.',
          statusCode: 408,
          originalError: err,
        );
        
      case DioExceptionType.badCertificate:
        return ApiError(
          code: 'bad_certificate',
          message: 'Certificado SSL inválido. Por favor, tente novamente mais tarde.',
          statusCode: 495,
          originalError: err,
        );
        
      case DioExceptionType.badResponse:
        return _handleBadResponse(err);
        
      case DioExceptionType.cancel:
        return ApiError(
          code: 'cancelled',
          message: 'A requisição foi cancelada.',
          statusCode: 499,
          originalError: err,
        );
        
      case DioExceptionType.connectionError:
        return ApiError(
          code: 'connection_error',
          message: 'Erro de conexão. Verifique sua conexão com a internet e tente novamente.',
          statusCode: 503,
          originalError: err,
        );
        
      case DioExceptionType.unknown:
        if (err.error is SocketException) {
          return ApiError(
            code: 'no_internet',
            message: 'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
            statusCode: 503,
            originalError: err,
          );
        }
        
        return ApiError(
          code: 'unknown',
          message: 'Ocorreu um erro desconhecido. Por favor, tente novamente.',
          statusCode: 500,
          originalError: err,
        );
    }
  }
  
  
  ApiError _handleBadResponse(DioException err) {
    final statusCode = err.response?.statusCode ?? 500;
    final data = err.response?.data;
    
    
    String? errorMessage;
    String? errorCode;
    
    if (data is Map<String, dynamic>) {
      errorMessage = data['message'] as String? ?? 
                    data['error'] as String? ?? 
                    data['error_message'] as String?;
      
      errorCode = data['code'] as String? ?? 
                 data['error_code'] as String?;
    }
    
    switch (statusCode) {
      case 400:
        return ApiError(
          code: errorCode ?? 'bad_request',
          message: errorMessage ?? 'Requisição inválida. Verifique os dados enviados.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 401:
        return ApiError(
          code: errorCode ?? 'unauthorized',
          message: errorMessage ?? 'Não autorizado. Faça login novamente.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 403:
        return ApiError(
          code: errorCode ?? 'forbidden',
          message: errorMessage ?? 'Acesso negado. Você não tem permissão para acessar este recurso.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 404:
        return ApiError(
          code: errorCode ?? 'not_found',
          message: errorMessage ?? 'Recurso não encontrado.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 422:
        return ApiError(
          code: errorCode ?? 'validation_error',
          message: errorMessage ?? 'Erro de validação. Verifique os dados enviados.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 429:
        return ApiError(
          code: errorCode ?? 'too_many_requests',
          message: errorMessage ?? 'Muitas requisições. Tente novamente mais tarde.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      case 500:
      case 501:
      case 502:
      case 503:
      case 504:
        return ApiError(
          code: errorCode ?? 'server_error',
          message: errorMessage ?? 'Erro no servidor. Tente novamente mais tarde.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
        
      default:
        return ApiError(
          code: errorCode ?? 'unknown',
          message: errorMessage ?? 'Ocorreu um erro desconhecido. Por favor, tente novamente.',
          statusCode: statusCode,
          originalError: err,
          responseData: data,
        );
    }
  }
}
