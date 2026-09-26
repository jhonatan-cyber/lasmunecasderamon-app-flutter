import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/presentation/cajero_home_screen.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() async {
    setupTestEnvironment();
    await initializeDateFormatting('es_CL', null);
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
        home: createTestApp(
          child: const CajeroHomeScreen(),
          overrides: [
            authProvider.overrideWith(
              (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
            ),
            apiClientProvider.overrideWith(
              (ref) => ApiClient(dio: createMockDio()),
            ),
          ],
        ),
      ),
    );

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('FINANCIERO action card is rendered (enlace a Eventos Financieros)',
      (WidgetTester tester) async {
    await pumpHomeScreen(tester);

    expect(find.text('FINANCIERO'), findsOneWidget);
    expect(find.text('Eventos y propinas'), findsOneWidget);
  });
}
