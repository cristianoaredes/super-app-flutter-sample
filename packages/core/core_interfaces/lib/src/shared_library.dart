import 'package:flutter/material.dart';


abstract class SharedLibrary {
  
  String get id;

  
  List<ThemeExtension<dynamic>> get themeExtensions;

  
  void registerComponents(ComponentRegistry registry);
}


class ComponentRegistry {
  final Map<String, WidgetBuilder> _components = {};

  
  void register(String id, WidgetBuilder builder) {
    _components[id] = builder;
  }

  
  WidgetBuilder? get(String id) => _components[id];

  
  bool contains(String id) => _components.containsKey(id);

  
  Map<String, WidgetBuilder> get components => Map.unmodifiable(_components);
}
