import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';


class AnalyticsEvent extends Equatable {
  final String id;
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  final String? userId;

  AnalyticsEvent({
    String? id,
    required this.name,
    Map<String, dynamic>? parameters,
    DateTime? timestamp,
    this.userId,
  })  : id = id ?? const Uuid().v4(),
        parameters = parameters ?? {},
        timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [id, name, parameters, timestamp, userId];

  @override
  String toString() =>
      'AnalyticsEvent(id: $id, name: $name, parameters: $parameters, timestamp: $timestamp, userId: $userId)';

  
  AnalyticsEvent copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? parameters,
    DateTime? timestamp,
    String? userId,
  }) {
    return AnalyticsEvent(
      id: id ?? this.id,
      name: name ?? this.name,
      parameters: parameters ?? this.parameters,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'parameters': parameters,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      parameters: json['parameters'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
      userId: json['userId'] as String?,
    );
  }
}
