# GitHub Copilot Instructions for Premium Bank Flutter Super App

## Project Overview

Premium Bank is a modular banking super app built with Flutter, implementing a scalable and modern architecture for financial applications. The project uses a micro-frontend architecture pattern with independent micro apps that are initialized on-demand.

## Architecture

### Core Concepts

- **Super App Pattern**: Main orchestrator that manages micro apps and provides shared functionalities
- **Micro Apps**: Independent modules implementing specific features (auth, dashboard, cards, pix, payments, account, splash)
- **Core Packages**: Shared services and interfaces used across micro apps
- **Shared Packages**: Common utilities and design system components

### Project Structure

```
/
├── packages/
│   ├── core/                    # Core services
│   │   ├── core_analytics/      # Analytics service
│   │   ├── core_communication/  # Inter-micro app communication
│   │   ├── core_feature_flags/  # Feature flags
│   │   ├── core_interfaces/     # Shared interfaces
│   │   ├── core_logging/        # Logging service
│   │   ├── core_navigation/     # Navigation utilities
│   │   ├── core_network/        # Network service
│   │   └── core_storage/        # Storage service
│   │
│   ├── micro_apps/              # Independent micro apps
│   │   ├── account/             # Account management
│   │   ├── auth/                # Authentication
│   │   ├── cards/               # Card management
│   │   ├── dashboard/           # Main dashboard
│   │   ├── payments/            # Payment processing
│   │   ├── pix/                 # PIX transfers (Brazilian instant payment)
│   │   └── splash/              # Splash screen
│   │
│   └── shared/                  # Shared components
│       ├── design_system/       # UI components and theme
│       └── shared_utils/        # Common utilities
│
└── super_app/                   # Main application
    └── lib/core/                # Super app core
        ├── config/              # App configuration
        ├── di/                  # Dependency injection setup
        ├── interceptors/        # HTTP interceptors
        ├── router/              # Route configuration
        ├── services/            # App-level services
        ├── theme/               # Theme configuration
        └── widgets/             # Shared widgets
```

## Technology Stack

- **Flutter**: 3.29.2
- **Dart**: 3.7.2
- **State Management**: BLoC/Cubit (bloc 8.1.6, flutter_bloc, hydrated_bloc 9.1.5)
- **Dependency Injection**: get_it 7.7.0
- **Navigation**: go_router 12.1.3
- **Code Generation**: freezed 2.5.8, json_serializable 6.8.0
- **Storage**: shared_preferences 2.2.3, path_provider 2.1.4
- **Networking**: http 1.2.2, dio 5.3.3
- **Monorepo Management**: Melos 3.1.1

## Development Workflow

### Setup

1. **Install dependencies using Melos**:
   ```bash
   dart pub global activate melos
   melos bootstrap
   ```

2. **Run code generation**:
   ```bash
   melos run build_runner
   ```

3. **Run the app**:
   ```bash
   cd super_app
   flutter run
   ```

### Common Commands

- **Analyze code**: `melos run analyze`
- **Run tests**: `melos run test`
- **Generate code**: `melos run build_runner`
- **Format code**: `melos exec -- dart format .`

### Testing

- Test credentials: Email: `user@example.com`, Password: `password`
- Always run tests before submitting code: `melos run test`
- Tests should follow the existing test structure in each package

## Coding Standards

### Architecture Patterns

1. **Clean Architecture**: Each micro app follows clean architecture with:
   - **Presentation Layer**: UI components, BLoC/Cubit state management
   - **Domain Layer**: Use cases, entities, repository interfaces
   - **Data Layer**: Repository implementations, data sources, models

2. **Dependency Injection**:
   - Use `get_it` for DI
   - Register services in `super_app/lib/core/di/`
   - Each micro app registers its own dependencies when initialized
   - Use lazy singletons for micro apps to support on-demand initialization

3. **State Management**:
   - Use BLoC for complex state management
   - Use Cubit for simpler state management
   - Always check if BLoC/Cubit is closed before emitting new states
   - Implement proper lifecycle management to prevent memory leaks

### Code Style

1. **Naming Conventions**:
   - Use `snake_case` for file names
   - Use `PascalCase` for class names
   - Use `camelCase` for variables and functions
   - Prefix private members with underscore `_`

2. **File Organization**:
   - Group files by feature within each micro app
   - Use `lib/src/` for internal implementation
   - Export public APIs through main library file
   - Keep presentation, domain, and data layers separate

3. **Code Generation**:
   - Use `freezed` for immutable data classes
   - Use `json_serializable` for JSON serialization
   - Run build_runner after modifying generated code annotations
   - Commit generated files to version control

### Best Practices

1. **Micro App Development**:
   - Keep micro apps independent and isolated
   - Use core packages for shared functionality
   - Communicate between micro apps through core_communication
   - Each micro app should be self-contained with its own routes

2. **Navigation**:
   - Define routes in each micro app
   - Use go_router for navigation
   - Implement route middleware for micro app initialization
   - Handle deep linking appropriately

3. **Error Handling**:
   - Use try-catch blocks for error-prone operations
   - Provide meaningful error messages
   - Log errors using core_logging
   - Handle network errors gracefully

4. **Performance**:
   - Lazy-load micro apps on demand
   - Dispose resources properly (BLoCs, controllers, listeners)
   - Use const constructors where possible
   - Optimize images and assets

5. **Security**:
   - Never commit sensitive data or credentials
   - Use environment variables for API keys
   - Implement proper authentication and authorization
   - Validate user input

## Common Tasks

### Adding a New Micro App

1. Create a new package in `packages/micro_apps/`
2. Follow the clean architecture structure
3. Register the micro app in `super_app/lib/core/di/`
4. Define routes in the micro app
5. Add routes to `super_app/lib/core/router/`
6. Update melos.yaml if needed

### Adding a New Feature to Existing Micro App

1. Create use case in domain layer
2. Implement repository in data layer
3. Create BLoC/Cubit in presentation layer
4. Build UI components
5. Add routes if needed
6. Write tests for all layers

### Updating Dependencies

1. Update version in relevant `pubspec.yaml`
2. Run `melos bootstrap` to update all packages
3. Run `melos run build_runner` if code generation is affected
4. Run `melos run test` to ensure nothing broke
5. Test the app manually

## Important Notes

- This is a Work In Progress (WIP) project
- Language: Code comments can be in Portuguese (pt-BR) or English
- Platform Support: Android and iOS
- The project uses Melos for monorepo management
- All micro apps should be independently testable
- Follow the existing patterns and conventions in the codebase

## Troubleshooting

### Common Issues

1. **"Cannot emit new states after calling close"**:
   - Check if BLoC/Cubit lifecycle is managed properly
   - Ensure proper disposal in widget lifecycle
   - Use the middleware system for micro app initialization

2. **Build runner conflicts**:
   - Run with `--delete-conflicting-outputs` flag
   - Clean build files: `melos exec -- flutter clean`

3. **Dependency issues**:
   - Run `melos clean` and `melos bootstrap`
   - Check for version conflicts in pubspec.yaml files

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [BLoC Library](https://bloclibrary.dev)
- [Melos Documentation](https://melos.invertase.dev)
- [Go Router Documentation](https://pub.dev/packages/go_router)
