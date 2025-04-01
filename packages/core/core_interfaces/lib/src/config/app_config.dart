
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

  
  T? getValue<T>(String key) => additionalConfig[key] as T?;
}


enum Environment {
  development,
  staging,
  production,
}
