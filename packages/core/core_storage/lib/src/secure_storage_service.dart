import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class SecureStorageServiceImpl implements SecureStorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  @override
  Future<void> setSecureValue(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> getSecureValue(String key) async {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> removeSecureValue(String key) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    final value = await _secureStorage.read(key: key);
    return value != null;
  }

  @override
  Future<void> setSecureObject<T>(String key, T value) async {
    final jsonString = jsonEncode(value);
    await setSecureValue(key, jsonString);
  }

  @override
  Future<T?> getSecureObject<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final jsonString = await getSecureValue(key);
    if (jsonString == null) {
      return null;
    }

    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }
}
