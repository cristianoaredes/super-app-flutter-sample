import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'api_error.dart';


@immutable
class NetworkResult<T> extends Equatable {
  final T? data;
  final ApiError? error;
  final bool isLoading;

  const NetworkResult._({
    this.data,
    this.error,
    this.isLoading = false,
  });

  
  const NetworkResult.success(T data) : this._(data: data);

  
  const NetworkResult.error(ApiError error) : this._(error: error);

  
  const NetworkResult.loading() : this._(isLoading: true);

  
  bool get isSuccess => data != null && error == null && !isLoading;

  
  bool get isError => error != null && !isLoading;

  @override
  List<Object?> get props => [data, error, isLoading];

  @override
  String toString() {
    if (isLoading) {
      return 'NetworkResult.loading()';
    }

    if (isSuccess) {
      return 'NetworkResult.success(data: $data)';
    }

    return 'NetworkResult.error(error: $error)';
  }

  
  NetworkResult<R> map<R>(R Function(T) mapper) {
    if (isLoading) {
      return NetworkResult<R>.loading();
    }

    if (isSuccess) {
      return NetworkResult<R>.success(mapper(data as T));
    }

    return NetworkResult<R>.error(error!);
  }

  
  R when<R>({
    required R Function(T) success,
    required R Function(ApiError) error,
    required R Function() loading,
  }) {
    if (isLoading) {
      return loading();
    }

    if (isSuccess) {
      return success(data as T);
    }

    return error(this.error!);
  }
}
