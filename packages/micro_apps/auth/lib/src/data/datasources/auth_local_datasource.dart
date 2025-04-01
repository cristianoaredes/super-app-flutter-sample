import 'dart:convert';

import 'package:core_interfaces/core_interfaces.dart';

import '../models/user_model.dart';


abstract class AuthLocalDataSource {
  
  Future<UserModel?> getUser();

  
  Future<void> saveUser(UserModel user);

  
  Future<void> removeUser();

  
  Future<String?> getAccessToken();

  
  Future<void> saveAccessToken(String token);

  
  Future<void> removeAccessToken();
}


class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService _storageService;

  static const String _userKey = 'user';
  static const String _tokenKey = 'access_token';

  AuthLocalDataSourceImpl({required StorageService storageService})
      : _storageService = storageService;

  @override
  Future<UserModel?> getUser() async {
    final userJson = await _storageService.getValue<String>(_userKey);

    if (userJson == null) {
      return null;
    }

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await _storageService.setValue(_userKey, userJson);
  }

  @override
  Future<void> removeUser() async {
    await _storageService.removeValue(_userKey);
  }

  @override
  Future<String?> getAccessToken() async {
    return _storageService.secureStorage.getSecureValue(_tokenKey);
  }

  @override
  Future<void> saveAccessToken(String token) async {
    await _storageService.secureStorage.setSecureValue(_tokenKey, token);
  }

  @override
  Future<void> removeAccessToken() async {
    await _storageService.secureStorage.removeSecureValue(_tokenKey);
  }
}
