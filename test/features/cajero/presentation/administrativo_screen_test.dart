import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/operations_calendar.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/presentation/administrativo_screen.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() async {
    setupTestEnvironment();
    await initializeDateFormatting('es_CL', null);
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  // El ProviderScope va por encima del MaterialApp (como en `main.dart`): los
  // modales que abre la pantalla viven en rutas del Navigator.
  Future<void> pumpScreen(WidgetTester tester, {Dio? dio}) async {
    await tester.pumpWidget(
      createTestApp(
        overrides: [
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
          ),
          apiClientProvider.overrideWith(
            (ref) => ApiClient(dio: dio ?? createMockDio()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
          home: const CajeroAdministrativoScreen(),
        ),
      ),
    );

    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el botón Reportes está junto al total a cobrar', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await tester.scrollUntilVisible(
      find.widgetWithText(ElevatedButton, 'Reportes'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('TOTAL A COBRAR'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reportes'), findsOneWidget);
  });

  testWidgets('Reportes dispara el export de liquidación a PDF', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    final reportesBtn = find.widgetWithText(ElevatedButton, 'Reportes');
    await tester.scrollUntilVisible(
      reportesBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // Con dart:io real para que la generación del PDF pueda completar; sin
    // plugins nativos el export falla, pero debe ejecutarse y reportarlo (el
    // diálogo de texto plano anterior no generaba ningún archivo).
    await tester.runAsync(() async {
      await tester.tap(reportesBtn);
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('No se pudo generar el reporte PDF'), findsOneWidget);
  });

  testWidgets('tocar un evento del resumen abre el detalle compartido', (
    WidgetTester tester,
  ) async {
    // Evento de hoy en /events/user + su detalle real.
    final now = DateTime.now();
    await pumpScreen(
      tester,
      dio: createMockDioWithRoutes({
        '/events/user': {
          'success': true,
          'data': [
            {
              'type': 'comision',
              'id': '8a1b',
              'codigo': 'DEV-FIN-001',
              'date': now.toIso8601String(),
              'amount': 250,
              'estado': 1,
              'subType': 'venta',
            },
          ],
        },
        '/events/detail/': {
          'success': true,
          'data': {
            'tipo': 'comision',
            'cajero_nick': 'Pepe',
            'detalles': [
              {'cantidad': 1, 'producto_nombre': 'Paceña', 'subtotal': 50},
            ],
          },
        },
      }),
    );

    // Día de hoy en el calendario del administrativo → Ver Detalles → evento.
    final dayCell = find.byKey(Key('calendar-day-${calendarDateKey(now)}'));
    await tester.scrollUntilVisible(
      dayCell,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ver Detalles'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ver Detalles'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Comisión de Venta'));
    await tester.pumpAndSettle();

    // Detalle compartido (mismas claves reales del endpoint).
    expect(find.text('Fecha y Hora'), findsOneWidget);
    expect(find.text('Procesó la venta'), findsOneWidget);
    expect(find.text('Pepe'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('1x Paceña'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);
  });

  testWidgets('navegar de mes recarga /events/user de ese mes', (
    WidgetTester tester,
  ) async {
    final requestedUris = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedUris.add(options.uri.toString());
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': <dynamic>[]},
            ),
          );
        },
      ),
    );

    await pumpScreen(tester, dio: dio);

    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final navNext = find.byKey(const Key('calendar-nav-next'));
    await tester.scrollUntilVisible(
      navNext,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(navNext);
    await tester.pumpAndSettle();

    // El mes lo controla la pantalla (paridad con currentMonth/onMonthChange
    // de PremiumCalendar en Expo): cambia la etiqueta del calendario y
    // vuelve a pedir /events/user con el rango del mes navegado.
    final nextMonthLabel = DateFormat(
      'MMMM yyyy',
      'es_CL',
    ).format(nextMonth).toUpperCase();
    expect(find.text(nextMonthLabel), findsOneWidget);

    final expectedStart = DateFormat('yyyy-MM-dd').format(nextMonth);
    expect(
      requestedUris.any((uri) => uri.contains('startDate=$expectedStart')),
      isTrue,
      reason: 'debe recargar /events/user del mes navegado',
    );
  });
}
