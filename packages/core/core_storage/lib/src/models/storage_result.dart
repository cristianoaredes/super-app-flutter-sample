import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'storage_error.dart';


@immutable
class StorageResult<T> extends Equatable {
  final T? data;
  final StorageError? error;
  final bool isLoading;
  
  const StorageResult._({
    this.data,
    this.error,
    this.isLoading = false,
  });
  
  
  const StorageResult.success(T data) : this._(data: data);
  
  
  const StorageResult.error(StorageError error) : this._(error: error);
  
  
  const StorageResult.loading() : this._(isLoading: true);
  
  
  bool get isSuccess => data != null && error == null && !isLoading;
  
  
  bool get isError => error != null && !isLoading;
  
  @override
  List<Object?> get props => [data, error, isLoading];
  
  @override
  String toString() {
    if (isLoading) {
      return 'StorageResult.loading()';
    }
    
    if (isSuccess) {
      return 'StorageResult.success(data: $data)';
    }
    
    return 'StorageResult.error(error: $error)';
  }
  
  
  StorageResult<R> map<R>(R Function(T) mapper) {
    if (isLoading) {
      return StorageResult<R>.loading();
    }
    
    if (isSuccess) {
      return StorageResult<R>.success(mapper(data as T));
    }
    
    return StorageResult<R>.error(error!);
  }
  
  
  R when<R>({
    required R Function(T) success,
    required R Function(StorageError) error,
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
