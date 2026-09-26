import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/operations_calendar.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/anfitriona/presentation/anfitriona_home_screen.dart';
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
          home: const AnfitrionaHomeScreen(),
        ),
      ),
    );

    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tarjeta «Eventos Financieros» está en el home', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    await tester.scrollUntilVisible(
      find.text('Eventos Financieros'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Eventos Financieros'), findsOneWidget);
    expect(find.text('Mis comisiones y sus estados'), findsOneWidget);
  });

  testWidgets('tarjeta de liquidación con export a PDF está en el home', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    await tester.scrollUntilVisible(
      find.text('TOTAL A COBRAR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('TOTAL A COBRAR'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reportes'), findsOneWidget);
  });

  testWidgets('tarjeta «Analíticas» está en el home (enlace a Analytics)', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    await tester.scrollUntilVisible(
      find.text('Analíticas'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Analíticas'), findsOneWidget);
    expect(find.text('Métricas y tendencias'), findsOneWidget);
  });

  testWidgets('calendario operativo con selección de días está en el home', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    await tester.scrollUntilVisible(
      find.text('Calendario Operativo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Calendario Operativo'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);
    expect(find.text('Comisión'), findsOneWidget);
    expect(
      find.byKey(Key('calendar-day-${calendarDateKey(DateTime.now())}')),
      findsOneWidget,
    );

    // La selección y la hoja de detalle se cubren en
    // test/core/operations_calendar_test.dart: en el ListView del home la
    // celda queda en el cacheExtent y un tap no es fiable.
  });
}
