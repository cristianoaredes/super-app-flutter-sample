# Guia de Contribuição

Obrigado por considerar contribuir para o Premium Bank Super App! Este documento fornece diretrizes para contribuir com o projeto.

## Índice

1. [Código de Conduta](#código-de-conduta)
2. [Como Contribuir](#como-contribuir)
3. [Padrões de Código](#padrões-de-código)
4. [Commits e Mensagens](#commits-e-mensagens)
5. [Pull Requests](#pull-requests)
6. [Testes](#testes)
7. [Documentação](#documentação)
8. [Code Review](#code-review)

---

## Código de Conduta

### Nossa Promessa

Nós, como membros, contribuidores e líderes, nos comprometemos a fazer da participação em nossa comunidade uma experiência livre de assédio para todos.

### Comportamentos Esperados

- ✅ Usar linguagem acolhedora e inclusiva
- ✅ Respeitar pontos de vista e experiências diferentes
- ✅ Aceitar críticas construtivas com elegância
- ✅ Focar no que é melhor para a comunidade
- ✅ Mostrar empatia com outros membros

### Comportamentos Inaceitáveis

- ❌ Linguagem ou imagens sexualizadas
- ❌ Trolling, comentários insultuosos ou depreciativos
- ❌ Assédio público ou privado
- ❌ Publicar informações privadas de outros sem permissão
- ❌ Conduta que poderia ser considerada inadequada profissionalmente

---

## Como Contribuir

### 1. Encontrando uma Task

- Verifique a lista de [Issues](https://github.com/your-org/super-app-flutter-sample/issues)
- Procure por labels:
  - `good first issue` - Ótimo para iniciantes
  - `help wanted` - Precisamos de ajuda
  - `bug` - Correção de bug
  - `enhancement` - Nova funcionalidade
  - `documentation` - Melhorias em docs

### 2. Reportando Bugs

Ao reportar um bug, inclua:

**Template de Bug Report**:
```markdown
## Descrição
[Descrição clara do bug]

## Passos para Reproduzir
1. Vá para '...'
2. Clique em '...'
3. Role até '...'
4. Veja o erro

## Comportamento Esperado
[O que deveria acontecer]

## Comportamento Atual
[O que realmente acontece]

## Screenshots
[Se aplicável]

## Ambiente
- OS: [e.g. iOS 16, Android 13]
- Flutter version: [e.g. 3.29.2]
- Device: [e.g. iPhone 14, Pixel 6]

## Logs
```
[Cole logs relevantes aqui]
```

## Contexto Adicional
[Qualquer outra informação relevante]
```

### 3. Sugerindo Melhorias

**Template de Feature Request**:
```markdown
## Problema
[Qual problema isso resolve?]

## Solução Proposta
[Descreva a solução que você gostaria de ver]

## Alternativas Consideradas
[Descreva alternativas que você considerou]

## Contexto Adicional
[Screenshots, mockups, referências, etc]
```

### 4. Fazendo Mudanças

#### Setup do Ambiente
```bash
# 1. Fork o repositório
# 2. Clone seu fork
git clone https://github.com/seu-usuario/super-app-flutter-sample.git
cd super-app-flutter-sample

# 3. Adicione o upstream
git remote add upstream https://github.com/your-org/super-app-flutter-sample.git

# 4. Configure o ambiente
melos bootstrap
melos run build_runner

# 5. Crie uma branch
git checkout -b feature/minha-feature
```

#### Durante o Desenvolvimento
```bash
# Mantenha sua branch atualizada
git fetch upstream
git rebase upstream/main

# Rode testes frequentemente
melos run test

# Verifique análise
melos run analyze

# Formate código
dart format .
```

---

## Padrões de Código

### Estilo de Código

Seguimos as [Effective Dart Guidelines](https://dart.dev/guides/language/effective-dart):

#### Nomenclatura

```dart
// Classes: PascalCase
class UserRepository {}
class AuthBloc {}

// Variáveis, funções: camelCase
String userName;
void fetchData() {}

// Constantes: lowerCamelCase
const maxRetries = 3;

// Arquivos: snake_case
auth_repository.dart
user_model.dart

// Enums: PascalCase (valores também)
enum PaymentStatus {
  pending,
  completed,
  failed,
}
```

#### Organização de Imports

```dart
// 1. Dart imports
import 'dart:async';
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Package imports (alfabético)
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 4. Project imports (alfabético)
import 'package:core_interfaces/core_interfaces.dart';
import 'package:shared_utils/shared_utils.dart';

// 5. Relative imports
import '../domain/entities/user.dart';
import 'auth_event.dart';
```

### Clean Code Principles

#### 1. SOLID

```dart
// ✅ Single Responsibility
class UserRepository {
  Future<User> getUser(String id);
}

class UserCache {
  void cacheUser(User user);
}

// ❌ Múltiplas responsabilidades
class UserManager {
  Future<User> getUser(String id);
  void cacheUser(User user);
  void sendAnalytics(String event);
  void showNotification(String message);
}
```

#### 2. DRY (Don't Repeat Yourself)

```dart
// ✅ Função reutilizável
String formatCurrency(double value) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
      .format(value);
}

// Uso
final price1 = formatCurrency(100.50);
final price2 = formatCurrency(200.75);

// ❌ Código duplicado
final price1 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
    .format(100.50);
final price2 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
    .format(200.75);
```

#### 3. Imutabilidade

```dart
// ✅ Classe imutável
class User {
  final String id;
  final String name;

  const User({
    required this.id,
    required this.name,
  });

  User copyWith({
    String? id,
    String? name,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

// ❌ Classe mutável
class User {
  String id;
  String name;
  // Não use!
}
```

### Documentação de Código

Use dartdoc para documentar APIs públicas:

```dart
/// Repositório para gerenciar autenticação de usuários.
///
/// Este repositório abstrai as fontes de dados de autenticação
/// e fornece uma interface limpa para o domain layer.
///
/// Exemplo:
/// ```dart
/// final user = await authRepository.loginWithEmail(
///   'user@example.com',
///   'password123',
/// );
/// ```
abstract class AuthRepository {
  /// Faz login com email e senha.
  ///
  /// Retorna [User] se bem-sucedido.
  ///
  /// Throws:
  /// - [InvalidCredentialsException] se credenciais inválidas
  /// - [NetworkException] se erro de rede
  Future<User> loginWithEmailAndPassword(
    String email,
    String password,
  );

  /// Faz logout do usuário atual.
  ///
  /// Limpa tokens de sessão e cache local.
  Future<void> logout();
}
```

### Tratamento de Erros

Use exceções customizadas:

```dart
// ✅ Exceções tipadas
if (email.isEmpty) {
  throw ValidationException(
    message: 'Email é obrigatório',
    fieldErrors: {'email': 'Campo obrigatório'},
  );
}

try {
  await repository.login(email, password);
} on InvalidCredentialsException {
  // Tratar credenciais inválidas
} on NetworkException {
  // Tratar erro de rede
} catch (e) {
  // Erro genérico
}

// ❌ Exceções genéricas
if (email.isEmpty) {
  throw Exception('Email é obrigatório');
}
```

### Testes

Siga a pirâmide de testes:
- **50%**: Unit tests (lógica de negócio)
- **30%**: Widget tests (UI)
- **15%**: Integration tests (fluxos)
- **5%**: E2E tests (app completo)

```dart
// Exemplo de unit test
group('LoginUseCase', () {
  late LoginUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  test('should return User when login succeeds', () async {
    // Arrange
    final testUser = User(id: '1', name: 'Test', email: 'test@example.com');
    when(mockRepository.loginWithEmailAndPassword(any, any))
        .thenAnswer((_) async => testUser);

    // Act
    final result = await useCase.execute('test@example.com', 'pass123');

    // Assert
    expect(result, equals(testUser));
    verify(mockRepository.loginWithEmailAndPassword(
      'test@example.com',
      'pass123',
    )).called(1);
  });
});
```

---

## Commits e Mensagens

### Conventional Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Types

- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `refactor`: Refatoração de código
- `test`: Adição/modificação de testes
- `docs`: Mudanças em documentação
- `style`: Formatação, missing semi colons, etc
- `chore`: Tarefas de build, configuração, etc
- `perf`: Melhorias de performance
- `ci`: Mudanças em CI/CD

#### Scopes

- `auth`: Auth micro app
- `dashboard`: Dashboard micro app
- `payments`: Payments micro app
- `pix`: Pix micro app
- `core`: Pacotes core
- `shared`: Pacotes shared
- `docs`: Documentação

#### Exemplos

```bash
# Feature simples
feat(auth): add biometric login

# Feature complexa
feat(payments): implement scheduled payments

Add ability to schedule payments for future dates.
Users can now select a date and the payment will be
processed automatically on that date.

Closes #123

# Fix
fix(dashboard): correct balance calculation

The balance was incorrectly showing negative values
due to a rounding error in the currency conversion.

Fixes #456

# Breaking change
feat(auth)!: change login API endpoint

BREAKING CHANGE: Login endpoint changed from /auth/login
to /v2/auth/login. Update all API calls accordingly.

# Refactor
refactor(core): extract base repository class

# Test
test(payments): add unit tests for payment cubit

# Documentation
docs: update architecture documentation

# Chore
chore: update dependencies to latest versions
```

### Commit Guidelines

- ✅ **Atômico**: Um commit = uma mudança lógica
- ✅ **Descritivo**: Explique o "por quê", não o "o quê"
- ✅ **Presente**: Use imperativo ("add" não "added")
- ✅ **Limite de linha**: 72 caracteres na primeira linha
- ❌ **Evite**: "fix stuff", "wip", "update"

---

## Pull Requests

### Antes de Criar

```bash
# 1. Atualize sua branch
git fetch upstream
git rebase upstream/main

# 2. Rode testes
melos run test

# 3. Verifique análise
melos run analyze

# 4. Formate código
dart format .

# 5. Verifique mudanças
git diff main...feature/minha-feature
```

### Template de PR

```markdown
## Descrição

[Breve descrição das mudanças]

## Tipo de Mudança

- [ ] Bug fix (non-breaking change que corrige um issue)
- [ ] New feature (non-breaking change que adiciona funcionalidade)
- [ ] Breaking change (fix ou feature que causa mudança em funcionalidade existente)
- [ ] Refactoring (mudanças de código que não mudam comportamento)
- [ ] Documentation update

## Como Testar

1. [Passo 1]
2. [Passo 2]
3. [Passo 3]

## Checklist

- [ ] Código segue style guidelines do projeto
- [ ] Self-review do código realizado
- [ ] Comentários adicionados em áreas complexas
- [ ] Documentação atualizada
- [ ] Mudanças não geram novos warnings
- [ ] Testes unitários adicionados/atualizados
- [ ] Testes passam localmente
- [ ] Mudanças dependentes foram merged e publicadas

## Screenshots (se aplicável)

[Adicione screenshots aqui]

## Issues Relacionadas

Closes #[issue number]
Fixes #[issue number]
Related to #[issue number]

## Notas Adicionais

[Qualquer informação adicional para revisores]
```

### Tamanho do PR

- ✅ **Pequeno**: < 200 linhas (ideal)
- ⚠️ **Médio**: 200-500 linhas (aceitável)
- ❌ **Grande**: > 500 linhas (quebrar em PRs menores)

### Review Checklist

Revisores devem verificar:

- [ ] Código segue padrões do projeto
- [ ] Lógica de negócio está correta
- [ ] Testes cobrem casos relevantes
- [ ] Documentação está atualizada
- [ ] Não há problemas de performance
- [ ] Não há vulnerabilidades de segurança
- [ ] UI/UX está consistente com design system
- [ ] Mensagens de erro são user-friendly
- [ ] Logs apropriados foram adicionados
- [ ] Analytics tracking está correto

---

## Testes

### Executando Testes

```bash
# Todos os testes
melos run test

# Micro app específico
cd packages/micro_apps/auth
flutter test

# Com cobertura
melos run test

# Apenas testes modificados
flutter test --test-randomize-ordering-seed random
```

### Escrevendo Testes

#### Unit Tests

```dart
// test/domain/usecases/login_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('LoginUseCase', () {
    late LoginUseCase useCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      useCase = LoginUseCase(mockRepository);
    });

    test('should call repository with correct parameters', () async {
      // Arrange
      when(mockRepository.login(any, any))
          .thenAnswer((_) async => testUser);

      // Act
      await useCase.execute('email@test.com', 'password');

      // Assert
      verify(mockRepository.login('email@test.com', 'password'))
          .called(1);
    });
  });
}
```

#### Widget Tests

```dart
// test/presentation/pages/login_page_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('should show error when login fails', (tester) async {
    // Arrange
    await tester.pumpWidget(TestApp(child: LoginPage()));

    // Act
    await tester.enterText(find.byType(TextField).first, 'invalid@email');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
```

### Cobertura Mínima

- **Unit Tests**: 80% mínimo
- **Widget Tests**: 60% mínimo
- **Critical paths**: 100%

---

## Documentação

### Atualizando Docs

Documentação deve ser atualizada junto com o código:

- **README.md**: Instruções de setup e overview
- **ARCHITECTURE.md**: Mudanças arquiteturais
- **ONBOARDING.md**: Novos processos ou ferramentas
- **CONTRIBUTING.md**: Novas guidelines
- **Inline docs**: dartdoc para APIs públicas

### Escrevendo Boas Docs

```dart
/// ✅ BOM: Explica o "por quê" e fornece exemplo
/// Valida um email usando regex RFC 5322.
///
/// Este validador é mais restritivo que a especificação completa
/// para prevenir emails mal formatados que tecnicamente são válidos
/// mas raramente usados na prática.
///
/// Exemplo:
/// ```dart
/// final isValid = EmailValidator.validate('user@example.com');
/// print(isValid); // true
/// ```
///
/// Returns `true` se o email é válido, `false` caso contrário.
bool validate(String email) {
  // ...
}

/// ❌ RUIM: Apenas repete o nome da função
/// Valida email
bool validate(String email) {
  // ...
}
```

---

## Code Review

### Como Revisor

#### Seja Construtivo

```markdown
# ✅ BOM
"Considere usar `const` aqui para melhor performance:
```dart
const Text('Hello')
```
Referência: https://dart.dev/guides/language/effective-dart#do-use-const"

# ❌ RUIM
"Isso está errado. Você não deveria fazer assim."
```

#### Faça Perguntas

```markdown
# ✅ BOM
"Você considerou o caso onde o usuário não tem permissão?
Como isso seria tratado?"

# ❌ RUIM
"Isso vai quebrar se o usuário não tiver permissão."
```

#### Aprove com Sugestões

```markdown
# ✅ BOM
"LGTM! Pequena sugestão: poderia extrair essa lógica
para um método separado para melhor testabilidade,
mas não é bloqueante. ✅"

# ❌ RUIM
"Aprovado mas você deveria mudar X, Y e Z."
```

### Como Autor

#### Responda Feedback

- Agradeça pelo feedback
- Explique decisões quando necessário
- Faça perguntas se não entender
- Implemente sugestões relevantes

#### Não Leve para o Pessoal

- Code review é sobre o código, não sobre você
- Feedback é uma oportunidade de aprender
- Discussões técnicas são saudáveis

---

## Recursos Adicionais

- 📖 [Effective Dart](https://dart.dev/guides/language/effective-dart)
- 📖 [Flutter Best Practices](https://docs.flutter.dev/development/best-practices)
- 📖 [Clean Code](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- 📖 [Refactoring](https://refactoring.com/)

---

## Perguntas?

Se você tiver dúvidas sobre como contribuir:

- 💬 Abra uma [Discussion](https://github.com/your-org/super-app-flutter-sample/discussions)
- 📧 Entre em contato no Slack: `#mobile-team`
- 📝 Comente na issue relevante

---

**Obrigado por contribuir! 🙏**

Toda contribuição, não importa o tamanho, é valiosa e apreciada.
