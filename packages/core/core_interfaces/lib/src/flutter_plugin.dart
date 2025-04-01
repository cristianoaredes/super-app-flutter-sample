import 'package:flutter/foundation.dart';


abstract class FlutterPlugin {
  
  String get id;

  
  Set<TargetPlatform> get supportedPlatforms;

  
  Future<void> initialize(PluginConfig config);

  
  Future<bool> get isAvailable;

  
  Map<Type, Object> get services;
}


class PluginConfig {
  final Map<String, dynamic> settings;

  PluginConfig({required this.settings});
}
