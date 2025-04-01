import 'package:core_interfaces/core_interfaces.dart' hide AppConfig;

class AppConfig {
  final String apiBaseUrl;
  final String appName;
  final String appVersion;
  final String buildNumber;
  final Environment environment;
  final Map<String, dynamic> additionalConfig;

  AppConfig({
    required this.apiBaseUrl,
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    required this.environment,
    this.additionalConfig = const {},
  });

  factory AppConfig.development() {
    return AppConfig(
      apiBaseUrl: 'https://api.dev.example.com/v1',
      appName: 'Banco Digital (Dev)',
      appVersion: '1.0.0',
      buildNumber: '1',
      environment: Environment.development,
      additionalConfig: {
        'enable_logs': true,
        'mock_data': true,
      },
    );
  }

  factory AppConfig.staging() {
    return AppConfig(
      apiBaseUrl: 'https://api.staging.example.com/v1',
      appName: 'Banco Digital (Staging)',
      appVersion: '1.0.0',
      buildNumber: '1',
      environment: Environment.staging,
      additionalConfig: {
        'enable_logs': true,
        'mock_data': false,
      },
    );
  }

  factory AppConfig.production() {
    return AppConfig(
      apiBaseUrl: 'https://api.example.com/v1',
      appName: 'Banco Digital',
      appVersion: '1.0.0',
      buildNumber: '1',
      environment: Environment.production,
      additionalConfig: {
        'enable_logs': false,
        'mock_data': false,
      },
    );
  }

  T? getValue<T>(String key) => additionalConfig[key] as T?;
}
