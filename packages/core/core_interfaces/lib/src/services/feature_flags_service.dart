
abstract class FeatureFlagsService {
  
  bool isFeatureEnabled(String featureKey);
  
  
  Map<String, bool> getAllFeatureFlags();
  
  
  void setFeatureFlag(String featureKey, bool isEnabled);
  
  
  void setFeatureFlags(Map<String, bool> featureFlags);
  
  
  void resetToDefaults();
}
