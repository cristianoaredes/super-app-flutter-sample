import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';


class AnalyticsError extends Equatable {
  final String id;
  final String name;
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? userId;

  AnalyticsError({
    String? id,
    required this.name,
    required this.message,
    this.stackTrace,
    DateTime? timestamp,
    this.userId,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [id, name, message, timestamp, userId];

  @override
  String toString() =>
      'AnalyticsError(id: $id, name: $name, message: $message, timestamp: $timestamp, userId: $userId)';

  
  AnalyticsError copyWith({
    String? id,
    String? name,
    String? message,
    StackTrace? stackTrace,
    DateTime? timestamp,
    String? userId,
  }) {
    return AnalyticsError(
      id: id ?? this.id,
      name: name ?? this.name,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'message': message,
      'stackTrace': stackTrace?.toString(),
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  
  factory AnalyticsError.fromJson(Map<String, dynamic> json) {
    final stackTraceString = json['stackTrace'] as String?;

    return AnalyticsError(
      id: json['id'] as String,
      name: json['name'] as String,
      message: json['message'] as String,
      stackTrace: stackTraceString != null
          ? StackTrace.fromString(stackTraceString)
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
    );
  }
}
