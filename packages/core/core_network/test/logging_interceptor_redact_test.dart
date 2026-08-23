import 'package:core_network/src/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts Authorization and Cookie headers', () {
    final redacted = LoggingInterceptor.redactHeaders({
      'Authorization': 'Bearer secret-token',
      'Cookie': 'sid=abc',
      'Accept': 'application/json',
    });

    expect(redacted['Authorization'], '<redacted>');
    expect(redacted['Cookie'], '<redacted>');
    expect(redacted['Accept'], 'application/json');
  });
}
