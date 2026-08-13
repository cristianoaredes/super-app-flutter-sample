import 'package:flutter_test/flutter_test.dart';
import 'package:super_app/core/router/route_middleware.dart';

void main() {
  test('host keeps a public splash route', () {
    expect(isPublicAppRoute('/'), isTrue);
  });
}
