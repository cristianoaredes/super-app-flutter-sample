# 🟢 TODO - Melhorias Gerais (BACKLOG)

**Fases:** 3-4 - Documentação, Segurança e Performance
**Prazo:** 3 semanas
**Status:** 🟢 Backlog

> 💡 **NOTA:** Estas são melhorias que aumentam qualidade, segurança e performance,
> mas não são bloqueantes. Devem ser implementadas após issues críticos e médios.

---

## IMP-001: Ativar Lint Rules Adicionais

### 📍 Descrição
O projeto usa apenas `flutter_lints` básico. Ativar rules adicionais melhora consistência e qualidade.

### 🎯 Objetivo
Configurar lint rules mais rigorosas para garantir código de alta qualidade.

### ✅ Solução Proposta

Atualizar `/super_app/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Estilo e Formatação
    prefer_single_quotes: true
    require_trailing_commas: true
    lines_longer_than_80_chars: true

    # const e Imutabilidade
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true

    # Segurança de Tipos
    avoid_dynamic_calls: true
    avoid_type_to_string: true

    # Imports
    always_use_package_imports: true
    avoid_relative_lib_imports: true

    # Nomenclatura
    camel_case_types: true
    constant_identifier_names: true
    file_names: true

    # Práticas Recomendadas
    avoid_print: true
    avoid_empty_else: true
    avoid_returning_null_for_future: true
    cancel_subscriptions: true
    close_sinks: true
    prefer_final_fields: true
    prefer_final_in_for_each: true
    prefer_final_locals: true

    # Documentação
    public_member_api_docs: false  # Ativar após MED-004

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

  errors:
    missing_required_param: error
    missing_return: error
    must_be_immutable: error
```

### ⏱️ Estimativa: **2-4 horas**

---

## IMP-002: Configurar Pre-commit Hooks

### 📍 Descrição
Adicionar hooks que executam antes de commits para garantir qualidade.

### ✅ Solução Proposta

Criar `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "🔍 Running pre-commit checks..."

# 1. Format check
echo "📝 Checking formatting..."
if ! melos run format:check; then
    echo "❌ Code is not formatted. Run 'melos run format' first."
    exit 1
fi

# 2. Analyze
echo "🔎 Running analysis..."
if ! melos run analyze; then
    echo "❌ Analysis failed. Fix issues first."
    exit 1
fi

# 3. Tests
echo "🧪 Running tests..."
if ! melos run test; then
    echo "❌ Tests failed. Fix tests first."
    exit 1
fi

echo "✅ All checks passed!"
exit 0
```

Adicionar scripts ao `melos.yaml`:

```yaml
scripts:
  format:
    run: dart format lib test
    description: Format all Dart files

  format:check:
    run: dart format --output=none --set-exit-if-changed lib test
    description: Check if files are formatted

  analyze:
    run: flutter analyze
    description: Analyze all packages

  test:
    run: flutter test --coverage
    description: Run all tests with coverage
```

### ⏱️ Estimativa: **2-3 horas**

---

## IMP-003: Implementar Certificado Pinning

### 📍 Descrição
Adicionar certificate pinning para prevenir man-in-the-middle attacks.

### ✅ Solução Proposta

Adicionar dependência:
```yaml
dependencies:
  dio_http_certificate_pinning: ^1.0.0
```

Implementar em NetworkService:

```dart
class NetworkServiceImpl implements NetworkService {
  Future<void> initialize(CoreLibraryDependencies dependencies) async {
    final dio = Dio();

    // Configurar certificate pinning
    dio.interceptors.add(
      CertificatePinningInterceptor(
        allowedSHAFingerprints: [
          // Fingerprints dos certificados da sua API
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD',
        ],
      ),
    );
  }
}
```

### ⏱️ Estimativa: **6-8 horas**

---

## IMP-004: Adicionar Ofuscação de Código

### 📍 Descrição
Ativar ofuscação para builds de release no Android e iOS.

### ✅ Solução Proposta

#### Android

`android/app/build.gradle`:
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release

        // Ativar ofuscação
        minifyEnabled true
        shrinkResources true

        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

Criar `android/app/proguard-rules.pro`:
```proguard
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Dio
-keep class com.squareup.okhttp3.** { *; }

# Adicionar rules específicas do app
```

#### iOS

`ios/Runner.xcodeproj/project.pbxproj`:
```xml
GCC_SYMBOLS_PRIVATE_EXTERN = YES;
```

### ⏱️ Estimativa: **4-6 horas**

---

## IMP-005: Implementar Lazy Loading de Imagens

### 📍 Descrição
Usar `cached_network_image` para carregar e cachear imagens eficientemente.

### ✅ Solução Proposta

Adicionar dependência:
```yaml
dependencies:
  cached_network_image: ^3.3.0
```

Criar widget wrapper:

```dart
// packages/shared/design_system/lib/src/widgets/app_image.dart
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error),
      // Cache por 7 dias
      cacheManager: CacheManager(
        Config(
          'customCacheKey',
          stalePeriod: const Duration(days: 7),
        ),
      ),
    );
  }
}
```

### ⏱️ Estimativa: **4-6 horas**

---

## IMP-006: Implementar Paginação em Listas

### 📍 Descrição
Adicionar paginação em listas grandes (transações, pagamentos, etc.).

### ✅ Solução Proposta

Criar mixin reutilizável:

```dart
// packages/shared/shared_utils/lib/src/pagination/pagination_mixin.dart
mixin PaginationMixin<T> {
  final int pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;

  Future<void> loadInitial() async {
    _items.clear();
    _currentPage = 1;
    _hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    try {
      final newItems = await fetchPage(_currentPage, pageSize);

      _items.addAll(newItems);
      _hasMore = newItems.length == pageSize;
      _currentPage++;
    } finally {
      _isLoading = false;
    }
  }

  /// Implementar em subclasses
  Future<List<T>> fetchPage(int page, int pageSize);
}
```

Usar em BLoCs:

```dart
class TransactionsCubit extends Cubit<TransactionsState> with PaginationMixin<Transaction> {
  final TransactionsRepository repository;

  TransactionsCubit({required this.repository}) : super(TransactionsInitial());

  @override
  Future<List<Transaction>> fetchPage(int page, int pageSize) {
    return repository.getTransactions(page: page, pageSize: pageSize);
  }

  void loadTransactions() async {
    emit(TransactionsLoading());
    await loadInitial();
    emit(TransactionsLoaded(items: items));
  }

  void loadMoreTransactions() async {
    await loadMore();
    emit(TransactionsLoaded(items: items, hasMore: hasMore));
  }
}
```

### ⏱️ Estimativa: **8-10 horas**

---

## IMP-007: Criar Guia de Contribuição

### 📍 Descrição
Criar `CONTRIBUTING.md` com guidelines para contribuidores.

### ✅ Solução Proposta

Criar arquivo `/CONTRIBUTING.md`:

```markdown
# Guia de Contribuição

## Setup do Ambiente

1. Clone o repositório
2. Execute `melos bootstrap`
3. Execute `melos run build_runner`

## Workflow

1. Criar branch: `git checkout -b feature/minha-feature`
2. Fazer alterações
3. Executar testes: `melos run test`
4. Executar análise: `melos run analyze`
5. Commitar: `git commit -m "feat: descrição"`
6. Push: `git push origin feature/minha-feature`
7. Abrir Pull Request

## Padrões de Código

- Seguir guias em `/docs/guides/`
- 100% das APIs públicas documentadas
- Cobertura de testes ≥ 80% para código novo
- Zero warnings de análise

## Commits

Usar [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` nova funcionalidade
- `fix:` correção de bug
- `docs:` apenas documentação
- `test:` adição de testes
- `refactor:` refatoração de código

## Pull Requests

- Descrever mudanças claramente
- Linkar issues relacionados
- Adicionar screenshots se UI
- Aguardar aprovação de 1 revisor
```

### ⏱️ Estimativa: **4-6 horas**

---

## IMP-008: Adicionar Error Boundary Widgets

### 📍 Descrição
Implementar error boundaries para capturar erros de widget tree gracefully.

### ✅ Solução Proposta

```dart
// super_app/lib/core/widgets/error_boundary.dart
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();

    // Capturar erros síncronos
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace!) ??
          _DefaultErrorWidget(error: _error!, stackTrace: _stackTrace!);
    }

    return widget.child;
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const _DefaultErrorWidget({
    required this.error,
    required this.stackTrace,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Erro')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Algo deu errado', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Usar em rotas:

```dart
MaterialApp.router(
  builder: (context, child) {
    return ErrorBoundary(child: child ?? const SizedBox());
  },
  routerConfig: router,
);
```

### ⏱️ Estimativa: **4-6 horas**

---

## IMP-009: Configurar Firebase Performance Monitoring

### 📍 Descrição
Monitorar performance do app em produção com Firebase.

### ✅ Solução Proposta

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_performance: ^0.9.3
```

```dart
// super_app/lib/core/services/performance_monitor.dart
class PerformanceMonitor {
  final FirebasePerformance _performance = FirebasePerformance.instance;

  Future<void> initialize() async {
    await _performance.setPerformanceCollectionEnabled(true);
  }

  Future<T> trackOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) async {
    final trace = _performance.newTrace(name);

    if (attributes != null) {
      attributes.forEach((key, value) {
        trace.putAttribute(key, value);
      });
    }

    await trace.start();

    try {
      return await operation();
    } finally {
      await trace.stop();
    }
  }
}
```

### ⏱️ Estimativa: **6-8 horas**

---

## IMP-010: Implementar Feature Toggles com Remote Config

### 📍 Descrição
Usar Firebase Remote Config para feature flags dinâmicos.

### ✅ Solução Proposta

```dart
class FeatureFlagsServiceImpl implements FeatureFlagService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  @override
  Future<void> initialize(CoreLibraryDependencies dependencies) async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );

    // Valores padrão
    await _remoteConfig.setDefaults({
      'enable_pix': true,
      'enable_new_dashboard': false,
      'min_app_version': '1.0.0',
    });

    await _remoteConfig.fetchAndActivate();
  }

  @override
  bool isFeatureEnabled(String featureName) {
    return _remoteConfig.getBool(featureName);
  }

  @override
  T? getFeatureValue<T>(String featureName) {
    if (T == String) {
      return _remoteConfig.getString(featureName) as T?;
    } else if (T == int) {
      return _remoteConfig.getInt(featureName) as T?;
    } else if (T == bool) {
      return _remoteConfig.getBool(featureName) as T?;
    }
    return null;
  }
}
```

### ⏱️ Estimativa: **8-10 horas**

---

## 📊 Resumo de Melhorias

| ID | Melhoria | Esforço | Fase | Prioridade |
|----|----------|---------|------|-----------|
| IMP-001 | Lint Rules | 2-4h | 3 | Alta |
| IMP-002 | Pre-commit Hooks | 2-3h | 3 | Alta |
| IMP-003 | Certificate Pinning | 6-8h | 4 | Média |
| IMP-004 | Ofuscação | 4-6h | 4 | Média |
| IMP-005 | Lazy Loading Imagens | 4-6h | 4 | Média |
| IMP-006 | Paginação | 8-10h | 4 | Alta |
| IMP-007 | Guia Contribuição | 4-6h | 3 | Baixa |
| IMP-008 | Error Boundaries | 4-6h | 3 | Média |
| IMP-009 | Performance Monitoring | 6-8h | 4 | Baixa |
| IMP-010 | Remote Config | 8-10h | 4 | Baixa |

**Total Estimado Fase 3:** ~20 horas
**Total Estimado Fase 4:** ~40 horas

---

**Última Atualização:** 2025-11-07
**Status:** Aguardando aprovação para backlog
