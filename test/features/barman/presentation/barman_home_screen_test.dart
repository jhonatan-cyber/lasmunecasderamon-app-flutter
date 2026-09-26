import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/operations_calendar.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/barman/presentation/barman_home_screen.dart';
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
      // El ProviderScope va por encima del MaterialApp (como en `main.dart`):
      // los modales que abren estas pantallas viven en rutas del Navigator.
      createTestApp(
        overrides: [
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
          ),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(dio: createMockDio()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
          home: const BarmanHomeScreen(),
        ),
      ),
    );

    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'FINANCIERO action card is rendered (enlace a Eventos Financieros)',
    (WidgetTester tester) async {
      await pumpHomeScreen(tester);

      expect(find.text('FINANCIERO'), findsOneWidget);
      expect(find.text('Eventos y propinas'), findsOneWidget);
    },
  );

  testWidgets('tarjeta de liquidación con export a PDF está en el home', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('TOTAL A COBRAR'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reportes'), findsOneWidget);
  });

  testWidgets('calendario operativo con selección de días está en el home', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    final dayCell = find.byKey(
      Key('calendar-day-${calendarDateKey(DateTime.now())}'),
    );
    await tester.scrollUntilVisible(
      dayCell,
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Calendario Operativo'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);
    expect(find.text('Comisión'), findsOneWidget);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    expect(find.text('1 día seleccionado'), findsOneWidget);
  });
}
