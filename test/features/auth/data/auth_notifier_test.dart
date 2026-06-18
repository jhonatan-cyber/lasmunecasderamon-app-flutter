import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/auth/domain/user.dart';

/// A fake [FlutterSecureStoragePlatform] that keeps values in memory.
///
/// This avoids [MissingPluginException] when [AuthNotifier] tries to
/// read/write tokens in the test environment.
class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    Map<String, String>? options,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    Map<String, String>? options,
  }) async => _store[key] = value;

  @override
  Future<void> delete({
    required String key,
    Map<String, String>? options,
  }) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    Map<String, String>? options,
  }) async => Map.from(_store);

  @override
  Future<bool> containsKey({
    required String key,
    Map<String, String>? options,
  }) async => _store.containsKey(key);

  @override
  Future<void> deleteAll({Map<String, String>? options}) async => _store.clear();
}

/// Creates a [Dio] instance that returns a canned JSON [data] for every POST.
///
/// Pass [error] to simulate a failure instead.
Dio _dioWithResponse({Map<String, dynamic>? data, DioException? errorData}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (errorData != null) {
          handler.reject(errorData);
        } else {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: data ?? {'success': true},
            ),
          );
        }
      },
    ),
  );
  return dio;
}

/// Helper to create a new [AuthNotifier] wired to a canned [Dio].
///
/// Waits for the async [AuthNotifier.checkAuth] to complete before returning.
Future<AuthNotifier> _createNotifier({
  Map<String, dynamic>? response,
  DioException? errorData,
}) async {
  final notifier = AuthNotifier(ApiClient(dio: _dioWithResponse(data: response, errorData: errorData)));
  // Wait for constructor's checkAuth() to finish
  await Future<void>.delayed(Duration.zero);
  return notifier;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
  });

  group('AuthNotifier', () {
    // ─────────────────────────────────────────────────────────────────────────
    // Initial state
    // ─────────────────────────────────────────────────────────────────────────

    test('initial state is unauthenticated', () async {
      final notifier = await _createNotifier();

      expect(notifier.state.user, isNull);
      expect(notifier.state.token, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Login – success
    // ─────────────────────────────────────────────────────────────────────────

    test('login with username/password transforms username to email', () async {
      final notifier = await _createNotifier(response: {
        'token': 'tok123',
        'user': {
          'id': '1',
          'email': 'user@lasmunecasderamon.com',
          'nombre': 'User',
          'role': 'garzon',
        },
      });

      final result = await notifier.login(username: 'user', password: 'pass123');

      expect(result, isFalse);
      expect(notifier.state.token, 'tok123');
      expect(notifier.state.user, isNotNull);
      expect(notifier.state.user!.id, '1');
      expect(notifier.state.user!.email, 'user@lasmunecasderamon.com');
    });

    test('login with email (already contains @) does not add domain', () async {
      final notifier = await _createNotifier(response: {
        'token': 'tok456',
        'user': {
          'id': '2',
          'email': 'real@email.com',
          'nombre': 'Real',
          'role': 'garzon',
        },
      });

      final result = await notifier.login(username: 'real@email.com', password: 'pass');

      expect(result, isFalse);
      expect(notifier.state.user!.email, 'real@email.com');
    });

    test('login with qrToken sends qr_token in payload', () async {
      final notifier = await _createNotifier(response: {
        'token': 'qr_tok',
        'user': {
          'id': '3',
          'email': 'qr@test.com',
          'nombre': 'QR User',
          'role': 'garzon',
        },
      });

      final result = await notifier.login(qrToken: 'qrcode123');

      expect(result, isFalse);
      expect(notifier.state.token, 'qr_tok');
    });

    test('login returns true when verification code (2FA) is required', () async {
      final notifier = await _createNotifier(response: {
        'requiereCodigo': true,
      });

      final result = await notifier.login(username: 'user', password: 'pass');

      // Full testability: the 2FA path returns BEFORE reaching secure storage
      expect(result, isTrue);
      expect(notifier.state.tempAuthData, isNotNull);
      expect(notifier.state.tempAuthData!['username'], 'user');
      expect(notifier.state.isLoading, isFalse);
    });

    test('login sets user and token after full auth', () async {
      final notifier = await _createNotifier(response: {
        'token': 'tok_final',
        'user': {
          'id': '42',
          'email': 'full@test.com',
          'nombre': 'Full Auth',
          'role': 'cajero',
        },
      });

      await notifier.login(username: 'full', password: 'auth');

      expect(notifier.state.token, 'tok_final');
      expect(notifier.state.user!.role, 'cajero');
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Login – errors
    // ─────────────────────────────────────────────────────────────────────────

    test('login throws when neither credentials nor qrToken are provided', () async {
      final notifier = await _createNotifier();

      await expectLater(
        notifier.login(),
        throwsA(predicate<Exception>((e) => e.toString().contains('requeridos'))),
      );
      expect(notifier.state.isLoading, isFalse);
    });

    test('login sets error state on DioException with message', () async {
      // Create a Dio that always rejects
      final failingDio = Dio(BaseOptions(baseUrl: 'http://test'));
      failingDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'message': 'Credenciales inválidas'},
                ),
              ),
            );
          },
        ),
      );
      final failingClient = ApiClient(dio: failingDio);
      final notifier2 = AuthNotifier(failingClient);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        notifier2.login(username: 'user', password: 'wrong'),
        throwsA(isA<DioException>()),
      );
      expect(notifier2.state.error, contains('Credenciales inválidas'));
      expect(notifier2.state.isLoading, isFalse);
    });

    test('login sets error on unexpected response (no token, no message)', () async {
      final notifier = await _createNotifier(response: {'unexpected': true});

      await expectLater(
        notifier.login(username: 'user', password: 'pass'),
        throwsA(isA<Exception>()),
      );
      expect(notifier.state.error, contains('Error desconocido'));
      expect(notifier.state.isLoading, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Login – loading state
    // ─────────────────────────────────────────────────────────────────────────

    test('login sets isLoading while authenticating', () async {
      final notifier = await _createNotifier(response: {
        'token': 't',
        'user': {'id': '1', 'email': 'a@b.c', 'nombre': 'A', 'role': 'garzon'},
      });

      expect(notifier.state.isLoading, isFalse);

      // Start login but don't await: isLoading is set synchronously at the top
      // of the method before any awaits.
      final loginFuture = notifier.login(username: 'user', password: 'pass');

      // After the sync part of login(), isLoading should be true
      expect(notifier.state.isLoading, isTrue);

      await loginFuture;
      expect(notifier.state.isLoading, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Logout
    // ─────────────────────────────────────────────────────────────────────────

    test('logout clears user and token and resets state', () async {
      final notifier = await _createNotifier(response: {
        'token': 'tok',
        'user': {'id': '1', 'email': 'a@b.c', 'nombre': 'U', 'role': 'garzon'},
      });

      await notifier.login(username: 'user', password: 'pass');
      expect(notifier.state.user, isNotNull);

      await notifier.logout();

      expect(notifier.state.user, isNull);
      expect(notifier.state.token, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.tempAuthData, isNull);
      expect(notifier.state.error, isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Password reset
    // ─────────────────────────────────────────────────────────────────────────

    test('requestPasswordReset calls API and resets loading state', () async {
      final notifier = await _createNotifier(response: {'success': true});

      expect(notifier.state.isLoading, isFalse);

      await notifier.requestPasswordReset('test@test.com');

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('requestPasswordReset sets error on DioException', () async {
      final failingDio = Dio(BaseOptions(baseUrl: 'http://test'));
      failingDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'message': 'Email no encontrado'},
                ),
              ),
            );
          },
        ),
      );
      final failingClient = ApiClient(dio: failingDio);
      final notifier2 = AuthNotifier(failingClient);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        notifier2.requestPasswordReset('notfound@test.com'),
        throwsA(isA<DioException>()),
      );
      expect(notifier2.state.error, contains('Email no encontrado'));
      expect(notifier2.state.isLoading, isFalse);
    });

    test('confirmPasswordReset calls API with code and password', () async {
      final notifier = await _createNotifier(response: {'success': true});

      await notifier.confirmPasswordReset('ABC123', 'newPass123!');

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('confirmPasswordReset sets error on DioException', () async {
      final failingDio = Dio(BaseOptions(baseUrl: 'http://test'));
      failingDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'message': 'Código inválido'},
                ),
              ),
            );
          },
        ),
      );
      final failingClient = ApiClient(dio: failingDio);
      final notifier2 = AuthNotifier(failingClient);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        notifier2.confirmPasswordReset('BAD', 'pass'),
        throwsA(isA<DioException>()),
      );
      expect(notifier2.state.error, contains('Código inválido'));
      expect(notifier2.state.isLoading, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Biometric
    // ─────────────────────────────────────────────────────────────────────────

    test('isBiometricEnabled returns false by default', () async {
      final notifier = await _createNotifier();

      final enabled = await notifier.isBiometricEnabled();

      expect(enabled, isFalse);
    });

    test('setBiometricEnabled persists and reads preference', () async {
      final notifier = await _createNotifier();

      await notifier.setBiometricEnabled(true);
      final enabled = await notifier.isBiometricEnabled();
      expect(enabled, isTrue);

      await notifier.setBiometricEnabled(false);
      final disabled = await notifier.isBiometricEnabled();
      expect(disabled, isFalse);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Profile
    // ─────────────────────────────────────────────────────────────────────────

    test('updateProfile updates state and persists to SharedPreferences', () async {
      final notifier = await _createNotifier(response: {
        'token': 't',
        'user': {'id': '1', 'email': 'old@test.com', 'nombre': 'Old', 'role': 'garzon'},
      });

      await notifier.login(username: 'user', password: 'pass');

      await notifier.updateProfile(User(
        id: '1',
        email: 'new@test.com',
        nombre: 'New Name',
        role: 'garzon',
      ));

      expect(notifier.state.user!.nombre, 'New Name');
      expect(notifier.state.user!.email, 'new@test.com');

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user'), contains('New Name'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Credentials (save/get)
    // ─────────────────────────────────────────────────────────────────────────

    test('saveCredentials and getCredentials round-trip', () async {
      final notifier = await _createNotifier();

      await notifier.saveCredentials('testuser', 'testpass');

      final creds = await notifier.getCredentials();
      expect(creds, isNotNull);
      expect(creds!['username'], 'testuser');
      expect(creds['password'], 'testpass');
    });

    test('removeCredentials deletes stored credentials', () async {
      final notifier = await _createNotifier();

      await notifier.saveCredentials('u', 'p');
      expect(await notifier.getCredentials(), isNotNull);

      await notifier.removeCredentials();
      expect(await notifier.getCredentials(), isNull);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // AuthState value semantics
    // ─────────────────────────────────────────────────────────────────────────

    test('AuthState copyWith clears fields with clear flags', () {
      final state = AuthState(
        user: User(id: '1', email: 'a@b.c', nombre: 'A', role: 'garzon'),
        token: 'tok',
        isLoading: true,
        tempAuthData: {'username': 'u'},
        error: 'err',
      );

      final cleared = state.copyWith(
        clearUser: true,
        clearToken: true,
        clearTempAuthData: true,
        clearError: true,
        isLoading: false,
      );

      expect(cleared.user, isNull);
      expect(cleared.token, isNull);
      expect(cleared.tempAuthData, isNull);
      expect(cleared.error, isNull);
      expect(cleared.isLoading, isFalse);
    });

    test('AuthState copyWith preserves fields when clear flags are false', () {
      final state = AuthState(
        user: User(id: '1', email: 'a@b.c', nombre: 'A', role: 'garzon'),
        token: 'tok',
        isLoading: true,
        tempAuthData: {'username': 'u'},
        error: 'err',
      );

      final preserved = state.copyWith(isLoading: false);

      expect(preserved.user, isNotNull);
      expect(preserved.token, 'tok');
      expect(preserved.tempAuthData, isNotNull);
      expect(preserved.error, 'err');
      expect(preserved.isLoading, isFalse);
    });
  });
}
