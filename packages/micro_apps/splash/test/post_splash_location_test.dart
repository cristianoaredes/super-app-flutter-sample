import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splash/src/presentation/pages/splash_page.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService(this._authenticated);

  final bool _authenticated;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Future<String?> get accessToken async => _authenticated ? 't' : null;

  @override
  String? get currentUserId => _authenticated ? 'u1' : null;

  @override
  void establishSession({required String userId, String? accessToken}) {}

  @override
  Future<bool> login(String username, String password) async => false;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> refreshToken() async => false;
}

void main() {
  test('sends unauthenticated users to login', () {
    expect(postSplashLocation(_FakeAuthService(false)), '/login');
  });

  test('sends authenticated users to dashboard', () {
    expect(postSplashLocation(_FakeAuthService(true)), '/dashboard');
  });
}
