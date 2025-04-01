# Super App - Módulo Principal

Este é o módulo principal (Super App) do projeto **super-app-flutter-sample**, responsável por orquestrar os micro apps e fornecer funcionalidades compartilhadas.

## Funcionalidades Principais

- **Orquestração de Micro Apps**: Inicialização e roteamento entre micro apps
- **Injeção de Dependências**: Registro e acesso centralizado a serviços
- **Middleware de Rotas**: Inicialização automática de micro apps sob demanda
- **Gestão de Temas**: Configuração visual do aplicativo
- **Manipulação de Erros**: Tratamento centralizado de exceções

## Estrutura do Diretório

```
super_app/
├── lib/
│   ├── core/                  # Funcionalidades essenciais
│   │   ├── config/            # Configurações do aplicativo
│   │   ├── di/                # Injeção de dependências
│   │   ├── router/            # Roteamento entre micro apps
│   │   ├── services/          # Serviços compartilhados
│   │   ├── theme/             # Temas do aplicativo
│   │   └── widgets/           # Widgets compartilhados
│   │
│   └── main.dart             # Ponto de entrada principal
│
└── test/                     # Testes do módulo super app
```

## Como Funciona o Middleware de Rotas

Um componente chave deste módulo é o middleware de inicialização de micro apps, que:

```dart
// Trecho do middleware que inicializa micro apps sob demanda
FutureOr<String?> redirect(BuildContext context, GoRouterState state) async {
  final path = state.matchedLocation;
  final microAppName = _getMicroAppNameForRoute(path);
  
  if (microAppName != null) {
    // Verifica se o micro app já está inicializado e em estado válido
    final microApp = _getIt<MicroApp>(instanceName: microAppName);
    
    if (!microApp.isInitialized) {
      // Inicializa o micro app se necessário
      await microApp.initialize(_dependencies);
    } else {
      try {
        // Verifica se o micro app está em um estado válido
        microApp.build(context);
      } catch (e) {
        // Reinicializa o micro app se estiver em estado inválido
        await _reinitializeMicroApp(microApp, microAppName);
        return '/dashboard';  // Redireciona para dashboard durante reinicialização
      }
    }
  }
  
  return null;  // Continue para a rota original
}
```

## Gerenciamento de Dependências

O super app registra os serviços core e os micro apps através do GetIt:

```dart
// Registro de serviços core
void _registerCoreServices() {
  sl.registerLazySingleton<NetworkService>(
    () => NetworkServiceImpl(),
  );

  sl.registerLazySingleton<StorageService>(
    () => StorageServiceImpl(),
  );
  
  // Outros serviços...
}

// Registro de micro apps
void _registerMicroApps() {
  sl.registerLazySingleton<MicroApp>(
    () => PaymentsMicroApp(),
    instanceName: 'payments',
  );
  
  sl.registerLazySingleton<MicroApp>(
    () => PixMicroApp(),
    instanceName: 'pix',
  );
  
  // Outros micro apps...
}
```

## Micro Apps Gerenciados

O Super App orquestra os seguintes micro apps:

- **Account**: Gerenciamento de conta e extratos
- **Auth**: Autenticação e gestão de sessão
- **Cards**: Gerenciamento de cartões
- **Dashboard**: Visão geral e resumo
- **Payments**: Pagamentos diversos
- **Pix**: Transferências Pix
- **Splash**: Tela inicial e carregamento

## Serviços Core Utilizados

O Super App integra os seguintes serviços core:

- **Analytics**: Rastreamento de eventos e métricas
- **Communication**: Comunicação entre micro apps
- **Feature Flags**: Ativação/desativação de funcionalidades
- **Logging**: Registro centralizado de logs
- **Network**: Requisições HTTP e cache
- **Storage**: Persistência local de dados

## Como Executar

Para executar o Super App:

1. Certifique-se de que todas as dependências estão instaladas:
   ```bash
   flutter pub get
   ```

2. Execute o aplicativo:
   ```bash
   flutter run
   ```

## Testes

Para executar os testes do Super App:

```bash
flutter test
```

## Resolução de Problemas Comuns

### Erro de "Cannot emit new states after calling close"

Este erro ocorre quando um Bloc/Cubit tenta emitir estados após ser fechado. Para evitar:

1. Sempre verifique se um Bloc/Cubit está em estado válido antes de utilizá-lo
2. Implemente tratamento de exceções ao acessar Blocs/Cubits
3. Utilize o middleware de rotas para reinicializar micro apps quando necessário

## Relacionamento com o Projeto Principal

Este módulo é parte do projeto `super-app-flutter-sample`. Para mais informações sobre a arquitetura global, consulte o README principal na raiz do projeto.

## Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes.
