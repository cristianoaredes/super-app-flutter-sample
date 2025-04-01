import 'package:core_interfaces/core_interfaces.dart';
import 'package:dio/dio.dart';

import 'api_client_impl.dart';
import 'connectivity/connectivity_service.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';


class NetworkServiceImpl implements NetworkService, CoreLibrary {
  final Dio _dio = Dio();
  final ConnectivityService _connectivityService = ConnectivityServiceImpl();
  final LoggingService? _loggingService;

  NetworkServiceImpl({LoggingService? loggingService})
      : _loggingService = loggingService;

  @override
  String get id => 'core_network';

  @override
  Future<void> initialize(CoreLibraryDependencies dependencies) async {
    
    _dio.interceptors.add(LoggingInterceptor(
      loggingService: _loggingService,
    ));
    _dio.interceptors.add(ErrorInterceptor());

    
    await _connectivityService.initialize();

    _loggingService?.info('NetworkService initialized', tag: 'NetworkService');
  }

  @override
  ApiClient createClient({
    required String baseUrl,
    AuthService? authService,
    bool enableCaching = false,
    Duration cacheDuration = const Duration(minutes: 5),
  }) {
    final clientDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    
    clientDio.interceptors.add(LoggingInterceptor(
      loggingService: _loggingService,
    ));
    clientDio.interceptors.add(ErrorInterceptor());

    
    if (authService != null) {
      clientDio.interceptors
          .add(AuthInterceptor(authService: authService, dio: clientDio));
    }

    
    if (enableCaching) {
      clientDio.interceptors.add(CacheInterceptor(
        defaultDuration: cacheDuration,
      ));
    }

    return ApiClientImpl(dio: clientDio);
  }

  @override
  Future<bool> get hasInternetConnection =>
      _connectivityService.hasInternetConnection;

  @override
  Map<Type, Object> get services => {
        NetworkService: this,
      };

  @override
  List<BlocProvider> get globalBlocs => [];

  @override
  Future<void> dispose() async {
    _dio.close();
    await _connectivityService.dispose();
    _loggingService?.info('NetworkService disposed', tag: 'NetworkService');
  }
}
