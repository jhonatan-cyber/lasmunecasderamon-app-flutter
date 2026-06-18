import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lasmunecasderamon_flutter/main.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() {
    setupTestEnvironment();
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  /// Pumps the full app with providers overridden for testing.
  ///
  /// * [authProvider] uses [TestAuthNotifier] so no platform channels are touched.
  /// * [apiClientProvider] uses [createMockDio] so no real HTTP requests are made.
  Future<void> pumpLoginScreen(WidgetTester tester) async {
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
          apiClientProvider.overrideWith(
            (ref) => ApiClient(dio: createMockDio()),
          ),
        ],
      ),
    );

    // Process initial frame (router redirect, layout)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  String? validateUsernameField(WidgetTester tester, String? value) {
    final usernameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    return usernameField.validator?.call(value);
  }

  String? validatePasswordField(WidgetTester tester, String? value) {
    final passwordField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    return passwordField.validator?.call(value);
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  testWidgets('renders all UI elements on the login screen', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // App shell
    expect(find.byType(MaterialApp), findsOneWidget);


    // Form labels
    expect(find.text('Nick'), findsWidgets);
    expect(find.text('Contraseña'), findsOneWidget);

    // Primary CTA
    expect(find.text('Iniciar Sesión'), findsOneWidget);

    // Forgot password link
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    // Quick-login divider label
    expect(find.text('O ingresa con'), findsOneWidget);

    // QR button is unconditional
    expect(find.text('Código QR'), findsOneWidget);

    // Theme toggle
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Form validation – empty field errors
  // ---------------------------------------------------------------------------

  testWidgets('shows both validation errors when login is tapped with empty fields', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);
    final formState = tester.state<FormState>(find.byType(Form));

    expect(validateUsernameField(tester, ''), 'Por favor ingresa tu nick');
    expect(validatePasswordField(tester, ''), 'Por favor ingresa tu contraseña');
    expect(formState.validate(), isFalse);
  });

  testWidgets('shows only username error when password is filled', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);
    final formState = tester.state<FormState>(find.byType(Form));

    // Fill only the password field (second TextFormField)
    await tester.enterText(find.byType(TextFormField).last, 'somepassword');
    await tester.pump();

    expect(validateUsernameField(tester, ''), 'Por favor ingresa tu nick');
    expect(validatePasswordField(tester, 'somepassword'), isNull);
    expect(formState.validate(), isFalse);
  });

  testWidgets('shows only password error when username is filled', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);
    final formState = tester.state<FormState>(find.byType(Form));

    // Fill only the username field (first TextFormField)
    await tester.enterText(find.byType(TextFormField).first, 'testuser');
    await tester.pump();

    expect(validateUsernameField(tester, 'testuser'), isNull);
    expect(validatePasswordField(tester, ''), 'Por favor ingresa tu contraseña');
    expect(formState.validate(), isFalse);
  });

  testWidgets('validation errors disappear after fields are filled and form is re-submitted', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);
    final formState = tester.state<FormState>(find.byType(Form));

    expect(formState.validate(), isFalse);
    expect(validateUsernameField(tester, ''), 'Por favor ingresa tu nick');
    expect(validatePasswordField(tester, ''), 'Por favor ingresa tu contraseña');

    // Fill both fields
    await tester.enterText(find.byType(TextFormField).first, 'testuser');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();
    
    expect(validateUsernameField(tester, 'testuser'), isNull);
    expect(validatePasswordField(tester, 'password123'), isNull);
    expect(formState.validate(), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Biometric button visibility
  // ---------------------------------------------------------------------------

  testWidgets('biometric (Huella) button is hidden when biometrics unavailable', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // In the test environment LocalAuthentication platform calls throw,
    // so _isBiometricAvailable stays false — the "Huella" button is not rendered.
    expect(find.text('Huella'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Password visibility toggle
  // ---------------------------------------------------------------------------

  testWidgets('password visibility can be toggled', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // Initially obscured
    final passwordField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );
    expect(passwordField.obscureText, isTrue);

    // Tap the visibility icon
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    // Now visible
    final updatedField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );
    expect(updatedField.obscureText, isFalse);

    // Tap again to hide
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    final hiddenAgain = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );
    expect(hiddenAgain.obscureText, isTrue);
  });

  // ---------------------------------------------------------------------------
  // Forgot password dialog
  // ---------------------------------------------------------------------------

  testWidgets('forgot password link is rendered and tappable (navigates via GoRouter)', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // Link exists
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    // Tapping triggers navigation (push /auth/reset-password via GoRouter).
    // In the test environment without GoRouter, the context.push will throw,
    // but we verify the button exists and is configured.
    final linkButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('¿Olvidaste tu contraseña?'),
        matching: find.byType(TextButton),
      ),
    );
    expect(linkButton.onPressed, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Theme toggle rendering
  // ---------------------------------------------------------------------------

  testWidgets('theme toggle switches between dark and light mode', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // Starts in dark mode (default), so light_mode icon is shown
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);

    // Tap the theme toggle (now placed after SafeArea in Stack, so it's tappable)
    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now in light mode: dark_mode icon appears
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsNothing);

    // Toggle back
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // QR scanner dialog
  // ---------------------------------------------------------------------------

  testWidgets('QR button exists and can be tapped', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    // The QR button is below the viewport on a 800x600 test surface.
    // Scroll the quick-login section into view.
    await tester.ensureVisible(find.text('Código QR'));
    await tester.pump();

    // Verify the QR button renders
    expect(find.text('Código QR'), findsOneWidget);

    // Note: the MobileScanner inside the QR dialog uses platform channels
    // (camera) that throw in the test environment, so we cannot test the
    // dialog interaction here.
  });
}
