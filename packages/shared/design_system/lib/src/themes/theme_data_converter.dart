import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';


class ThemeDataConverter implements JsonConverter<ThemeData, Map<String, dynamic>> {
  const ThemeDataConverter();

  @override
  ThemeData fromJson(Map<String, dynamic> json) {
    
    
    final brightness = json['brightness'] == 'dark' 
        ? Brightness.dark 
        : Brightness.light;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Color(json['primaryColor'] as int),
      brightness: brightness,
    );
    
    return ThemeData(
      useMaterial3: json['useMaterial3'] as bool? ?? true,
      colorScheme: colorScheme,
      brightness: brightness,
    );
  }

  @override
  Map<String, dynamic> toJson(ThemeData theme) {
    
    return {
      'brightness': theme.brightness.toString().split('.').last,
      'primaryColor': theme.colorScheme.primary.value,
      'useMaterial3': theme.useMaterial3,
    };
  }
}
