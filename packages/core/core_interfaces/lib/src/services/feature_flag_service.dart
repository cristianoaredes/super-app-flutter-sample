
abstract class FeatureFlagService {
  
  Future<bool> isEnabled(String featureKey, {Map<String, dynamic>? attributes});

  
  Future<T?> getValue<T>(String featureKey,
      {T? defaultValue, Map<String, dynamic>? attributes});

  
  void registerListener(String featureKey, FeatureFlagListener listener);

  
  void removeListener(String featureKey, FeatureFlagListener listener);

  
  Future<void> synchronize();

  
  Future<Map<String, dynamic>> getAllFeatureFlags();
}


typedef FeatureFlagListener = void Function(
    String featureKey, dynamic oldValue, dynamic newValue);


class FeatureFlag<T> {
  final String key;
  final T defaultValue;
  final bool enabled;
  final T? value;
  final Map<String, dynamic>? attributes;

  FeatureFlag({
    required this.key,
    required this.defaultValue,
    this.enabled = false,
    this.value,
    this.attributes,
  });

  
  T get resolvedValue => value ?? defaultValue;

  @override
  String toString() =>
      'FeatureFlag(key: $key, enabled: $enabled, value: $value, defaultValue: $defaultValue)';
}
