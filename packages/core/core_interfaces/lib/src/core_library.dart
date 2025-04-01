import 'config/app_config.dart';


abstract class CoreLibrary {
  
  String get id;

  
  Future<void> initialize(CoreLibraryDependencies dependencies);

  
  Map<Type, Object> get services;

  
  List<BlocProvider> get globalBlocs;

  
  Future<void> dispose();
}


class BlocProvider {
  final Type type;
  final Object bloc;

  BlocProvider({required this.type, required this.bloc});
}


class CoreLibraryDependencies {
  final AppConfig config;
  final Map<Type, Object> services;

  CoreLibraryDependencies({
    required this.config,
    required this.services,
  });
}
