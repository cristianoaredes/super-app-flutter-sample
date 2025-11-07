import 'package:auth/src/data/datasources/auth_local_datasource.dart';
import 'package:auth/src/data/datasources/auth_remote_datasource.dart';
import 'package:auth/src/data/models/user_model.dart';
import 'package:auth/src/data/repositories/auth_repository_impl.dart';
import 'package:auth/src/domain/entities/user.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_repository_impl_test.mocks.dart';

/// Gera os mocks necessários para os testes
/// Execute: dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  AuthRemoteDataSource,
  AuthLocalDataSource,
  NetworkService,
])
void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockLocalDataSource;
  late MockNetworkService mockNetworkService;

  // Test data
  final testUserModel = UserModel(
    id: 'test-id',
    name: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime(2024, 1, 1),
    lastLogin: DateTime(2024, 1, 1),
  );

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalDataSource = MockAuthLocalDataSource();
    mockNetworkService = MockNetworkService();

    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      networkService: mockNetworkService,
    );

    // Default: assume internet connection is available
    when(mockNetworkService.hasInternetConnection)
        .thenAnswer((_) async => true);
  });

  group('AuthRepositoryImpl', () {
    group('getCurrentUser', () {
      test('should return user from local data source', () async {
        // Arrange
        when(mockLocalDataSource.getUser())
            .thenAnswer((_) async => testUserModel);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, equals(testUserModel));
        verify(mockLocalDataSource.getUser()).called(1);
        verifyNoMoreInteractions(mockLocalDataSource);
      });

      test('should return null when no user is stored', () async {
        // Arrange
        when(mockLocalDataSource.getUser()).thenAnswer((_) async => null);

        // Act
        final result = await repository.getCurrentUser();

        // Assert
        expect(result, isNull);
        verify(mockLocalDataSource.getUser()).called(1);
      });
    });

    group('isAuthenticated', () {
      test('should return true when access token exists', () async {
        // Arrange
        when(mockLocalDataSource.getAccessToken())
            .thenAnswer((_) async => 'valid-token');

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result, isTrue);
        verify(mockLocalDataSource.getAccessToken()).called(1);
      });

      test('should return false when access token is null', () async {
        // Arrange
        when(mockLocalDataSource.getAccessToken()).thenAnswer((_) async => null);

        // Act
        final result = await repository.isAuthenticated();

        // Assert
        expect(result, isFalse);
        verify(mockLocalDataSource.getAccessToken()).called(1);
      });
    });

    group('loginWithEmailAndPassword', () {
      const testEmail = 'test@example.com';
      const testPassword = 'password123';

      test('should login user and save to local storage when successful',
          () async {
        // Arrange
        when(mockRemoteDataSource.loginWithEmailAndPassword(
          any,
          any,
        )).thenAnswer((_) async => testUserModel);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async => {});

        // Act
        final result =
            await repository.loginWithEmailAndPassword(testEmail, testPassword);

        // Assert
        expect(result, equals(testUserModel));
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.loginWithEmailAndPassword(
          testEmail,
          testPassword,
        )).called(1);
        verify(mockLocalDataSource.saveUser(testUserModel)).called(1);
      });

      test('should throw exception when no internet connection', () async {
        // Arrange
        when(mockNetworkService.hasInternetConnection)
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => repository.loginWithEmailAndPassword(testEmail, testPassword),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verifyNever(mockRemoteDataSource.loginWithEmailAndPassword(any, any));
        verifyNever(mockLocalDataSource.saveUser(any));
      });

      test('should throw exception when remote login fails', () async {
        // Arrange
        when(mockRemoteDataSource.loginWithEmailAndPassword(
          any,
          any,
        )).thenThrow(Exception('Invalid credentials'));

        // Act & Assert
        expect(
          () => repository.loginWithEmailAndPassword(testEmail, testPassword),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.loginWithEmailAndPassword(
          testEmail,
          testPassword,
        )).called(1);
        verifyNever(mockLocalDataSource.saveUser(any));
      });
    });

    group('loginWithGoogle', () {
      test('should login user and save to local storage when successful',
          () async {
        // Arrange
        when(mockRemoteDataSource.loginWithGoogle())
            .thenAnswer((_) async => testUserModel);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async => {});

        // Act
        final result = await repository.loginWithGoogle();

        // Assert
        expect(result, equals(testUserModel));
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.loginWithGoogle()).called(1);
        verify(mockLocalDataSource.saveUser(testUserModel)).called(1);
      });

      test('should throw exception when no internet connection', () async {
        // Arrange
        when(mockNetworkService.hasInternetConnection)
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => repository.loginWithGoogle(),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verifyNever(mockRemoteDataSource.loginWithGoogle());
        verifyNever(mockLocalDataSource.saveUser(any));
      });
    });

    group('loginWithApple', () {
      test('should login user and save to local storage when successful',
          () async {
        // Arrange
        when(mockRemoteDataSource.loginWithApple())
            .thenAnswer((_) async => testUserModel);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async => {});

        // Act
        final result = await repository.loginWithApple();

        // Assert
        expect(result, equals(testUserModel));
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.loginWithApple()).called(1);
        verify(mockLocalDataSource.saveUser(testUserModel)).called(1);
      });

      test('should throw exception when no internet connection', () async {
        // Arrange
        when(mockNetworkService.hasInternetConnection)
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => repository.loginWithApple(),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verifyNever(mockRemoteDataSource.loginWithApple());
        verifyNever(mockLocalDataSource.saveUser(any));
      });
    });

    group('logout', () {
      test('should remove user and access token from local storage', () async {
        // Arrange
        when(mockLocalDataSource.removeUser()).thenAnswer((_) async => {});
        when(mockLocalDataSource.removeAccessToken())
            .thenAnswer((_) async => {});

        // Act
        await repository.logout();

        // Assert
        verify(mockLocalDataSource.removeUser()).called(1);
        verify(mockLocalDataSource.removeAccessToken()).called(1);
      });
    });

    group('register', () {
      const testName = 'Test User';
      const testEmail = 'test@example.com';
      const testPassword = 'password123';

      test('should register user and save to local storage when successful',
          () async {
        // Arrange
        when(mockRemoteDataSource.register(
          any,
          any,
          any,
        )).thenAnswer((_) async => testUserModel);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async => {});

        // Act
        final result =
            await repository.register(testName, testEmail, testPassword);

        // Assert
        expect(result, equals(testUserModel));
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.register(
          testName,
          testEmail,
          testPassword,
        )).called(1);
        verify(mockLocalDataSource.saveUser(testUserModel)).called(1);
      });

      test('should throw exception when no internet connection', () async {
        // Arrange
        when(mockNetworkService.hasInternetConnection)
            .thenAnswer((_) async => false);

        // Act & Assert
        expect(
          () => repository.register(testName, testEmail, testPassword),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verifyNever(mockRemoteDataSource.register(any, any, any));
        verifyNever(mockLocalDataSource.saveUser(any));
      });

      test('should throw exception when registration fails', () async {
        // Arrange
        when(mockRemoteDataSource.register(
          any,
          any,
          any,
        )).thenThrow(Exception('Email already exists'));

        // Act & Assert
        expect(
          () => repository.register(testName, testEmail, testPassword),
          throwsA(isA<Exception>()),
        );
        verify(mockNetworkService.hasInternetConnection).called(1);
        verify(mockRemoteDataSource.register(
          testName,
          testEmail,
          testPassword,
        )).called(1);
        verifyNever(mockLocalDataSource.saveUser(any));
      });
    });
  });
}
