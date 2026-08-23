import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/core/services/auth_service_impl.dart';

void main() {
  test('establishSession marks the host AuthService authenticated', () {
    final auth = AuthServiceImpl();
    expect(auth.isAuthenticated, isFalse);

    auth.establishSession(userId: 'u1', accessToken: 'session_u1');

    expect(auth.isAuthenticated, isTrue);
    expect(auth.currentUserId, 'u1');
  });
}
