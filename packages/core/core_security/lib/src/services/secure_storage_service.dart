import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:core_interfaces/core_interfaces.dart';

/// Serviço de armazenamento seguro para dados sensíveis
///
/// Usa flutter_secure_storage que:
/// - Android: EncryptedSharedPreferences
/// - iOS: Keychain
/// - Linux/Windows: libsecret/Windows Credential Manager
class SecureStorageServiceImpl implements StorageService {
  final FlutterSecureStorage _storage;

  SecureStorageServiceImpl()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(
        key: key,
        value: value,
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );
    } catch (e) {
      throw StorageException(
        message: 'Failed to write secure data',
        originalError: e,
      );
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw StorageException(
        message: 'Failed to read secure data',
        originalError: e,
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw StorageException(
        message: 'Failed to delete secure data',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageException(
        message: 'Failed to clear secure storage',
        originalError: e,
      );
    }
  }

  /// Verifica se uma chave existe no armazenamento
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      return false;
    }
  }

  /// Salva token de acesso
  Future<void> saveAccessToken(String token) async {
    await write('access_token', token);
  }

  /// Recupera token de acesso
  Future<String?> getAccessToken() async {
    return await read('access_token');
  }

  /// Remove token de acesso
  Future<void> clearAccessToken() async {
    await delete('access_token');
  }

  /// Salva refresh token
  Future<void> saveRefreshToken(String token) async {
    await write('refresh_token', token);
  }

  /// Recupera refresh token
  Future<String?> getRefreshToken() async {
    return await read('refresh_token');
  }

  /// Remove refresh token
  Future<void> clearRefreshToken() async {
    await delete('refresh_token');
  }

  /// Salva credenciais de autenticação
  Future<void> saveAuthCredentials({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      write('user_id', userId),
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      write('auth_timestamp', DateTime.now().toIso8601String()),
    ]);
  }

  /// Limpa todas as credenciais de autenticação
  Future<void> clearAuthCredentials() async {
    await Future.wait([
      delete('user_id'),
      clearAccessToken(),
      clearRefreshToken(),
      delete('auth_timestamp'),
    ]);
  }

  /// Verifica se token ainda é válido (não expirou por tempo)
  Future<bool> isTokenValid({Duration maxAge = const Duration(hours: 24)}) async {
    final timestamp = await read('auth_timestamp');
    if (timestamp == null) return false;

    try {
      final savedTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(savedTime);

      return difference < maxAge;
    } catch (e) {
      return false;
    }
  }
}
