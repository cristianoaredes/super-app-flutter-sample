import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthMockDataSource implements AuthRemoteDataSource {
  AuthMockDataSource();

  @override
  Future<UserModel> loginWithEmailAndPassword(
      String email, String password) async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.loginWithEmailAndPassword');
      print('Email: $email, Password: $password');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (email == 'user@example.com' && password == 'password') {
      return UserModel(
        id: 'mock-user-id',
        name: 'Test User',
        email: email,
        photoUrl: 'https://via.placeholder.com/150',
        createdAt: DateTime.now(),
      );
    } else {
      throw Exception('Invalid credentials');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.loginWithGoogle');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return UserModel(
      id: 'mock-google-user-id',
      name: 'Google User',
      email: 'google@example.com',
      photoUrl: 'https://via.placeholder.com/150',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserModel> loginWithApple() async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.loginWithApple');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return UserModel(
      id: 'mock-apple-user-id',
      name: 'Apple User',
      email: 'apple@example.com',
      photoUrl: 'https://via.placeholder.com/150',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.register');
      print('Name: $name, Email: $email, Password: $password');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return UserModel(
      id: 'mock-new-user-id',
      name: name,
      email: email,
      photoUrl: 'https://via.placeholder.com/150',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.sendPasswordResetEmail');
      print('Email: $email');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return;
  }

  @override
  Future<String?> refreshToken() async {
    if (kDebugMode) {
      print('🌐 AuthMockDataSource.refreshToken');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return 'mock-refreshed-token-${DateTime.now().millisecondsSinceEpoch}';
  }
}
