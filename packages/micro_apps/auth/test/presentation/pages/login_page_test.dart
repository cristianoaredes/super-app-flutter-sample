import 'package:auth/src/domain/entities/user.dart';
import 'package:auth/src/presentation/bloc/auth_bloc.dart';
import 'package:auth/src/presentation/bloc/auth_event.dart';
import 'package:auth/src/presentation/bloc/auth_state.dart';
import 'package:auth/src/presentation/pages/login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'login_page_test.mocks.dart';

@GenerateMocks([NavigationService])
void main() {
  late MockNavigationService mockNavigationService;
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockNavigationService = MockNavigationService();
    mockAuthBloc = MockAuthBloc();

    // Register NavigationService in GetIt
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<NavigationService>()) {
      getIt.registerSingleton<NavigationService>(mockNavigationService);
    }

    // Setup default state
    when(mockAuthBloc.state).thenReturn(const AuthInitialState());
    when(mockAuthBloc.stream)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Widget createLoginPage() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>(
        create: (_) => mockAuthBloc,
        child: const LoginPage(),
      ),
    );
  }

  group('LoginPage Widget Tests', () {
    testWidgets('should render login form with all fields',
        (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(createLoginPage());

      // Assert
      expect(find.text('Login'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and password
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Criar conta'), findsOneWidget);
      expect(find.text('Esqueci minha senha'), findsOneWidget);
    });

    testWidgets('should validate email field when empty',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Try to submit without filling email
      final loginButton = find.text('Entrar');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Assert - Should show validation error
      expect(find.text('Digite seu email'), findsOneWidget);
    });

    testWidgets('should validate email format', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Enter invalid email
      await tester.enterText(
        find.byType(TextFormField).first,
        'invalid-email',
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Assert - Should show validation error
      expect(find.text('Digite um email válido'), findsOneWidget);
    });

    testWidgets('should validate password field when empty',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Fill email but not password
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Digite sua senha'), findsOneWidget);
    });

    testWidgets('should toggle password visibility', (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());
      final passwordField = find.byType(TextFormField).last;

      // Act - Find and tap the visibility toggle icon
      final visibilityIcon = find.descendant(
        of: passwordField,
        matching: find.byType(IconButton),
      );

      // Initially password should be obscured
      TextFormField textField = tester.widget(passwordField);
      expect(textField.obscureText, isTrue);

      // Tap to show password
      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();

      // Assert - Password should now be visible
      textField = tester.widget(passwordField);
      expect(textField.obscureText, isFalse);
    });

    testWidgets('should dispatch LoginWithEmailAndPasswordEvent when form is valid',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Fill form with valid data
      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'password123',
      );
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuthBloc.add(const LoginWithEmailAndPasswordEvent(
        email: 'test@example.com',
        password: 'password123',
      ))).called(1);
    });

    testWidgets('should dispatch LoginWithGoogleEvent when Google button tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Find and tap Google login button
      final googleButton = find.text('Continuar com Google');
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuthBloc.add(const LoginWithGoogleEvent())).called(1);
    });

    testWidgets('should dispatch LoginWithAppleEvent when Apple button tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act - Find and tap Apple login button
      final appleButton = find.text('Continuar com Apple');
      await tester.tap(appleButton);
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuthBloc.add(const LoginWithAppleEvent())).called(1);
    });

    testWidgets('should navigate to register page when "Criar conta" tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigationService.navigateTo('/register')).called(1);
    });

    testWidgets('should navigate to reset password when "Esqueci minha senha" tapped',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(createLoginPage());

      // Act
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockNavigationService.navigateTo('/reset-password')).called(1);
    });

    testWidgets('should show loading indicator when state is AuthLoadingState',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([const AuthLoadingState()]),
        initialState: const AuthInitialState(),
      );

      // Act
      await tester.pumpWidget(createLoginPage());
      await tester.pump(); // Trigger the stream

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error snackbar when state is AuthErrorState',
        (WidgetTester tester) async {
      // Arrange
      whenListen(
        mockAuthBloc,
        Stream.fromIterable([
          const AuthErrorState(message: 'Invalid credentials'),
        ]),
        initialState: const AuthInitialState(),
      );

      // Act
      await tester.pumpWidget(createLoginPage());
      await tester.pump(); // Trigger the stream
      await tester.pump(); // Process the snackbar

      // Assert
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should navigate to dashboard when authenticated',
        (WidgetTester tester) async {
      // Arrange
      final testUser = User(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime(2024, 1, 1),
      );

      whenListen(
        mockAuthBloc,
        Stream.fromIterable([AuthenticatedState(user: testUser)]),
        initialState: const AuthInitialState(),
      );

      // Act
      await tester.pumpWidget(createLoginPage());
      await tester.pump(); // Trigger the stream

      // Assert
      verify(mockNavigationService.navigateTo('/dashboard')).called(1);
    });
  });
}

/// Mock AuthBloc for testing
class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
