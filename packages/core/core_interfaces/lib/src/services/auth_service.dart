abstract class AuthService {
  bool get isAuthenticated;

  Future<String?> get accessToken;

  Future<bool> login(String username, String password);

  Future<void> logout();

  Future<bool> refreshToken();

  String? get currentUserId;

  /// Marks the process as authenticated after a successful login use case.
  /// Does not re-validate credentials.
  void establishSession({required String userId, String? accessToken});
}
