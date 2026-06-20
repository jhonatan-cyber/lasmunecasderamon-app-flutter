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
          
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(
              ref.watch(apiClientProvider),
            ),
          ),
          
          apiClientProvider.overrideWith(
            (ref) => ApiClient(dio: createMockDio()),
          ),
        ],
      ),
    );

    
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    
    expect(find.byType(MaterialApp), findsOneWidget);

    
    
    expect(find.text('Iniciar Sesión'), findsOneWidget);

    
    expect(find.text('Nick'), findsWidgets);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  test('App core providers initialize correctly', () async {
    final container = ProviderContainer();
    addTearDown(() => container.dispose());

    
    expect(container.read(themeModeProvider), ThemeMode.dark);

    
    expect(container.read(accentColorProvider), appThemeOptions[0]);
  });
}
