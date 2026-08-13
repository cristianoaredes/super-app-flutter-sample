import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/core/router/route_middleware.dart';

void main() {
  test('public routes stay open without a session', () {
    for (final path in kPublicAppRoutes) {
      expect(
        authRedirectForPath(path, isAuthenticated: false),
        isNull,
        reason: path,
      );
    }
  });

  test('business routes redirect to login without a session', () {
    expect(authRedirectForPath('/dashboard', isAuthenticated: false), '/login');
    expect(authRedirectForPath('/pix', isAuthenticated: false), '/login');
    expect(authRedirectForPath('/payments', isAuthenticated: false), '/login');
    expect(authRedirectForPath('/cards', isAuthenticated: false), '/login');
    expect(authRedirectForPath('/account', isAuthenticated: false), '/login');
  });

  test('business routes stay put when authenticated', () {
    expect(authRedirectForPath('/pix/send', isAuthenticated: true), isNull);
  });
}
