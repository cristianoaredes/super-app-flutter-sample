import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import 'micro_app.dart';
import 'micro_app_dependencies.dart';
import 'bloc_registry.dart';
import 'exceptions/app_exceptions.dart';
import 'services/logging_service.dart';

/// Classe base abstrata que implementa padrões comuns para todos os micro apps.
///
/// Todos os micro apps devem estender esta classe ao invés de implementar
/// [MicroApp] diretamente. Esta classe fornece implementação padrão para
/// gerenciamento de ciclo de vida, validações e health checks.
///
/// ## Implementação Básica
///
/// ```dart
/// class MyMicroApp extends BaseMicroApp {
///   MyBloc? _myBloc;
///
///   MyMicroApp({GetIt? getIt}) : super(getIt: getIt);
///
///   @override
///   String get id => 'my_module';
///
///   @override
///   String get name => 'My Module';
///
///   MyBloc get myBloc {
///     ensureInitialized();
///     return _myBloc!;
///   }
///
///   @override
///   Future<void> onInitialize(MicroAppDependencies dependencies) async {
///     MyModuleInjector.register(getIt, dependencies);
///     _myBloc = getIt<MyBloc>();
///   }
///
///   @override
///   Future<void> onDispose() async {
///     await _myBloc?.close();
///     _myBloc = null;
///   }
///
///   @override
///   Map<String, GoRouteBuilder> get routes => {
///     '/my-route': (context, state) {
///       ensureInitialized();
///       return BlocProvider.value(
///         value: myBloc,
///         child: const MyPage(),
///       );
///     },
///   };
/// }
/// ```
///
/// ## Ciclo de Vida
///
/// 1. Construtor chamado (micro app criado como lazy singleton)
/// 2. [initialize] chamado quando micro app é necessário
/// 3. [onInitialize] executado (implementação customizada)
/// 4. [registerBlocs] chamado para registrar BLoCs no registry global
/// 5. Uso normal do micro app
/// 6. [dispose] chamado quando não mais necessário
/// 7. [onDispose] executado (limpeza customizada)
///
/// Veja também:
/// - [MicroApp] interface base
/// - [MicroAppDependencies] para dependências injetadas
abstract class BaseMicroApp implements MicroApp {
  /// GetIt instance para dependency injection
  final GetIt getIt;

  /// Flag indicando se o micro app foi inicializado
  bool _initialized = false;

  /// Dependências injetadas durante a inicialização
  MicroAppDependencies? _dependencies;

  /// Construtor padrão
  ///
  /// [getIt] instância opcional do GetIt. Se não fornecido, usa GetIt.instance.
  BaseMicroApp({GetIt? getIt}) : getIt = getIt ?? GetIt.instance;

  @override
  bool get isInitialized => _initialized;

  /// Retorna as dependências armazenadas
  ///
  /// Throws [InvalidStateException] se o micro app não foi inicializado.
  @protected
  MicroAppDependencies get dependencies {
    if (_dependencies == null) {
      throw InvalidStateException(
        message: 'MicroApp $name não foi inicializado. '
            'Chame initialize() primeiro.',
      );
    }
    return _dependencies!;
  }

  @override
  Future<void> initialize(MicroAppDependencies dependencies) async {
    if (_initialized) {
      dependencies.loggingService?.warning(
        'MicroApp $name já foi inicializado. Ignorando nova inicialização.',
        tag: 'BaseMicroApp',
      );
      return;
    }

    _dependencies = dependencies;

    try {
      dependencies.loggingService?.info(
        'Inicializando micro app $name...',
        tag: 'BaseMicroApp',
      );

      // Hook para inicialização customizada de cada micro app
      await onInitialize(dependencies);

      _initialized = true;

      dependencies.loggingService?.info(
        'MicroApp $name inicializado com sucesso',
        tag: 'BaseMicroApp',
      );
    } catch (e, stackTrace) {
      dependencies.loggingService?.error(
        'Erro ao inicializar MicroApp $name',
        error: e,
        stackTrace: stackTrace,
        tag: 'BaseMicroApp',
      );

      // Lança exceção customizada
      throw InitializationException(
        microAppId: id,
        message: 'Falha ao inicializar micro app $name',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Hook para inicialização customizada.
  ///
  /// Subclasses devem implementar este método para:
  /// - Registrar dependências específicas no DI container
  /// - Criar instâncias de BLoCs/Cubits
  /// - Configurar services necessários
  ///
  /// [dependencies] contém todos os services core necessários.
  ///
  /// Throws [InitializationException] se a inicialização falhar.
  @protected
  Future<void> onInitialize(MicroAppDependencies dependencies);

  @override
  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }

    try {
      _dependencies?.loggingService?.info(
        'Fazendo dispose do micro app $name...',
        tag: 'BaseMicroApp',
      );

      await onDispose();

      _initialized = false;
      _dependencies = null;

      // Nota: não setamos loggingService como null aqui
      // pois já perdemos a referência com _dependencies = null
    } catch (e, stackTrace) {
      _dependencies?.loggingService?.error(
        'Erro ao fazer dispose do MicroApp $name',
        error: e,
        stackTrace: stackTrace,
        tag: 'BaseMicroApp',
      );
      rethrow;
    }
  }

  /// Hook para dispose customizado.
  ///
  /// Subclasses devem implementar este método para:
  /// - Fechar todos os BLoCs/Cubits
  /// - Cancelar subscriptions
  /// - Limpar caches
  /// - Liberar recursos
  ///
  /// Após [dispose], o micro app pode ser reinicializado.
  @protected
  Future<void> onDispose();

  @override
  Future<bool> isHealthy() async {
    if (!_initialized) {
      return false;
    }

    try {
      // Hook para verificações de saúde customizadas
      return await checkHealth();
    } catch (e, stackTrace) {
      _dependencies?.loggingService?.error(
        'Health check falhou para MicroApp $name',
        error: e,
        stackTrace: stackTrace,
        tag: 'BaseMicroApp',
      );
      return false;
    }
  }

  /// Hook para verificações de saúde customizadas.
  ///
  /// Subclasses podem sobrescrever este método para implementar
  /// verificações específicas, como:
  /// - Verificar se BLoCs estão em estado válido
  /// - Verificar se dependências críticas estão disponíveis
  /// - Verificar se conexões estão ativas
  ///
  /// Por padrão, retorna true se estiver inicializado.
  ///
  /// Returns `true` se o micro app está saudável, `false` caso contrário.
  @protected
  Future<bool> checkHealth() async => true;

  /// Garante que o micro app está inicializado.
  ///
  /// Throws [InvalidStateException] se não estiver inicializado.
  ///
  /// Use este método no início de getters, métodos e rotas que
  /// dependem do micro app estar inicializado.
  @protected
  void ensureInitialized() {
    if (!_initialized) {
      throw InvalidStateException(
        message: '$name MicroApp não foi inicializado. '
            'Chame initialize() primeiro.',
      );
    }
  }
}
