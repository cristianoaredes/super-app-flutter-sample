
abstract class SecureStorageService {
  
  Future<void> setSecureValue(String key, String value);

  
  Future<String?> getSecureValue(String key);

  
  Future<void> removeSecureValue(String key);

  
  Future<void> clearSecureStorage();

  
  Future<bool> containsSecureKey(String key);

  
  Future<void> setSecureObject<T>(String key, T value);

  
  Future<T?> getSecureObject<T>(
      String key, T Function(Map<String, dynamic>) fromJson);
}


abstract class StorageService {
  
  Future<void> initialize();

  
  Future<bool> setValue<T>(String key, T value);

  
  Future<T?> getValue<T>(String key);

  
  Future<bool> removeValue(String key);

  
  Future<bool> clear();

  
  Future<bool> containsKey(String key);

  
  Future<String> getApplicationDocumentsDirectory();

  
  SecureStorageService get secureStorage;
}
