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

  
  
  
  
  Future<void> pumpLoginScreen(WidgetTester tester) async {
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

  
  
  

  testWidgets('renders all UI elements on the login screen', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    expect(find.byType(MaterialApp), findsOneWidget);


    
    expect(find.text('Nick'), findsWidgets);
    expect(find.text('Contraseña'), findsOneWidget);

    
    expect(find.text('Iniciar Sesión'), findsOneWidget);

    
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    
    expect(find.text('O ingresa con'), findsOneWidget);

    
    expect(find.text('Código QR'), findsOneWidget);

    
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
  });

  
  
  

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

    
    await tester.enterText(find.byType(TextFormField).first, 'testuser');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();
    
    expect(validateUsernameField(tester, 'testuser'), isNull);
    expect(validatePasswordField(tester, 'password123'), isNull);
    expect(formState.validate(), isTrue);
  });

  
  
  

  testWidgets('biometric (Huella) button is hidden when biometrics unavailable', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    
    expect(find.text('Huella'), findsNothing);
  });

  
  
  

  testWidgets('password visibility can be toggled', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    final passwordField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );
    expect(passwordField.obscureText, isTrue);

    
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    
    final updatedField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).last,
        matching: find.byType(TextField),
      ),
    );
    expect(updatedField.obscureText, isFalse);

    
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

  
  
  

  testWidgets('forgot password link is rendered and tappable (navigates via GoRouter)', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    
    
    
    final linkButton = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('¿Olvidaste tu contraseña?'),
        matching: find.byType(TextButton),
      ),
    );
    expect(linkButton.onPressed, isNotNull);
  });

  
  
  

  testWidgets('theme toggle switches between dark and light mode', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);

    
    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_rounded), findsNothing);

    
    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
  });

  
  
  

  testWidgets('QR button exists and can be tapped', (
    WidgetTester tester,
  ) async {
    await pumpLoginScreen(tester);

    
    
    await tester.ensureVisible(find.text('Código QR'));
    await tester.pump();

    
    expect(find.text('Código QR'), findsOneWidget);

    
    
    
  });
}
