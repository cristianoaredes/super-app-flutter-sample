import 'package:equatable/equatable.dart';


class AnalyticsUser extends Equatable {
  final String id;
  final Map<String, dynamic> properties;

  const AnalyticsUser({
    required this.id,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? const {};

  @override
  List<Object?> get props => [id, properties];

  @override
  String toString() => 'AnalyticsUser(id: $id, properties: $properties)';

  
  AnalyticsUser copyWith({
    String? id,
    Map<String, dynamic>? properties,
  }) {
    return AnalyticsUser(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  
  AnalyticsUser addProperties(Map<String, dynamic> newProperties) {
    return copyWith(
      properties: {
        ...properties,
        ...newProperties,
      },
    );
  }

  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'properties': properties,
    };
  }

  
  factory AnalyticsUser.fromJson(Map<String, dynamic> json) {
    return AnalyticsUser(
      id: json['id'] as String,
      properties: json['properties'] as Map<String, dynamic>? ?? {},
    );
  }
}
