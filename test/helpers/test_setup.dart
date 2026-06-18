import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';

/// Creates a mock [Dio] instance that returns canned responses
/// for all requests, preventing real network calls during tests.
Dio createMockDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Return empty 200 response for all requests
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'success': true},
          ),
        );
      },
    ),
  );
  return dio;
}

/// Sets up the common test environment for widget tests.
///
/// Call this in setUp() to:
/// - Initialize SharedPreferences mock (used by AccentColorNotifier, AuthNotifier)
/// - Disable google_fonts runtime fetching (fonts are loaded from bundled assets)
///
/// Font files are bundled at assets/fonts/ and declared in pubspec.yaml.
void setupTestEnvironment() {
  SharedPreferences.setMockInitialValues({});
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Resets the shared test environment.
///
/// Call this in tearDown() to reset global state.
void tearDownTestEnvironment() {
  GoogleFonts.config.allowRuntimeFetching = true;
}

/// Creates a [ProviderScope] wrapping [child] for testing.
///
/// Optionally accepts provider overrides to mock specific providers
/// (e.g., authProvider, apiClientProvider).
///
/// Example with mocked API client:
/// ```dart
/// createTestApp(
///   child: const MyApp(),
///   overrides: [
///     apiClientProvider.overrideWith(
///       (ref) => ApiClient() // or a custom mock
///     ),
///   ],
/// )
/// ```
/// A test [AuthNotifier] that never touches platform channels.
///
/// [FlutterSecureStorage] requires real platform channels which throw
/// [MissingPluginException] in the test environment. This subclass overrides
/// [checkAuth] to immediately set an unauthenticated state without any I/O.
class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(super.apiClient);

  @override
  Future<void> checkAuth() async {
    state = AuthState(isLoading: false);
  }
}

ProviderScope createTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: child,
  );
}
