















class BlocRegistry {
  final Map<Type, dynamic> _blocs = {};

  
  void register<T>(T bloc) {
    _blocs[bloc.runtimeType] = bloc;
  }

  
  void registerWithType<T>(Type type, T bloc) {
    _blocs[type] = bloc;
  }

  
  T? get<T>() {
    for (final entry in _blocs.entries) {
      if (entry.value is T) {
        return entry.value as T;
      }
    }
    return null;
  }

  
  bool contains<T>() {
    for (final entry in _blocs.entries) {
      if (entry.value is T) {
        return true;
      }
    }
    return false;
  }

  
  void remove<T>() {
    final keysToRemove = <Type>[];
    for (final entry in _blocs.entries) {
      if (entry.value is T) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _blocs.remove(key);
    }
  }

  
  void removeByType(Type type) {
    _blocs.remove(type);
  }

  
  void clear() {
    _blocs.clear();
  }

  
  Map<Type, dynamic> get blocs => Map.unmodifiable(_blocs);
}
