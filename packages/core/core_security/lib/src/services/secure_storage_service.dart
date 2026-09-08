import 'dart:convert';

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

  /// Adaptador que expõe o MESMO cliente seguro ([_storage]) através da
  /// interface [SecureStorageService] (contrato de core_interfaces), sem
  /// duplicar o cliente nem alterar o `implements` desta classe.
  late final SecureStorageService _secureStorageAdapter =
      _SecureStorageAdapter(_storage);

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
  @override
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

  @override
  Future<void> initialize() async {
    // FlutterSecureStorage não exige setup explícito: o cliente já é
    // construído no construtor desta classe. No-op apenas para satisfazer
    // o contrato de StorageService (TCK-0013/DES-0013).
  }

  @override
  Future<bool> setValue<T>(String key, T value) async {
    try {
      // String vai como veio (evita dupla codificação de tokens/segredos);
      // demais tipos são serializados como JSON. Nada é logado.
      final serialized = value is String ? value : jsonEncode(value);
      await write(key, serialized);
      return true;
    } catch (_) {
      // Falha de serialização/escrita não é logada: o valor pode conter
      // dados sensíveis. Converte para false conforme Future<bool>.
      return false;
    }
  }

  @override
  Future<T?> getValue<T>(String key) async {
    final raw = await read(key);
    if (raw == null) {
      return null;
    }

    // String é o formato nativo do armazenamento seguro (tokens, etc.).
    if (raw is T) {
      return raw as T;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is T) {
        return decoded;
      }
      return null;
    } catch (_) {
      // Conteúdo não é JSON válido para T. Nunca logar o conteúdo.
      return null;
    }
  }

  @override
  Future<bool> removeValue(String key) async {
    try {
      await delete(key);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      await deleteAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> getApplicationDocumentsDirectory() async {
    // Indisponível aqui: core_security não declara path_provider (adicionar
    // dependência está fora do escopo de TCK-0013) e o armazenamento seguro
    // não expõe o filesystem. Mantém o contrato retornando caminho vazio,
    // mesmo fallback usado por StorageServiceImpl (web/erro).
    // TODO(TCK-0013): expor caminhos de documento via serviço dedicado,
    // caso algum consumidor precise a partir daqui.
    return '';
  }

  @override
  SecureStorageService get secureStorage => _secureStorageAdapter;
}

/// Adaptador interno: implementa a interface [SecureStorageService] de
/// core_interfaces delegando ao MESMO cliente [FlutterSecureStorage] da
/// classe pública — sem criar um segundo cliente nem duplicar opções.
class _SecureStorageAdapter implements SecureStorageService {
  _SecureStorageAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> setSecureValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> getSecureValue(String key) async {
    return _storage.read(key: key);
  }

  @override
  Future<void> removeSecureValue(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> clearSecureStorage() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> containsSecureKey(String key) async {
    final value = await _storage.read(key: key);
    return value != null;
  }

  @override
  Future<void> setSecureObject<T>(String key, T value) async {
    await _storage.write(key: key, value: jsonEncode(value));
  }

  @override
  Future<T?> getSecureObject<T>(
      String key, T Function(Map<String, dynamic>) fromJson) async {
    final jsonString = await _storage.read(key: key);
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
