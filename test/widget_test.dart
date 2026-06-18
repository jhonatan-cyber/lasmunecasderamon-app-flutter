import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lasmunecasderamon_flutter/main.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'helpers/test_setup.dart';

void main() {
  setUp(() {
    setupTestEnvironment();
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  testWidgets('App renders login screen when not authenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createTestApp(
        child: const MyApp(),
        overrides: [
          // Use a test AuthNotifier that doesn't touch FlutterSecureStorage
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(
              ref.watch(apiClientProvider),
            ),
          ),
          // Mock the API client to prevent real network calls
          apiClientProvider.overrideWith(
            (ref) => ApiClient(dio: createMockDio()),
          ),
        ],
      ),
    );

    // Process initial frame (router redirect, layout)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify the app root renders
    expect(find.byType(MaterialApp), findsOneWidget);

    // The router should redirect to /login since no user is authenticated.
    // Login screen should render "Iniciar Sesión" button text.
    expect(find.text('Iniciar Sesión'), findsOneWidget);

    // Login form labels should be present
    expect(find.text('Nick'), findsWidgets);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  test('App core providers initialize correctly', () async {
    final container = ProviderContainer();
    addTearDown(() => container.dispose());

    // Verify theme provider initializes with default value
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Verify accent color provider initializes with first option (Terracota)
    expect(container.read(accentColorProvider), appThemeOptions[0]);
  });
}
