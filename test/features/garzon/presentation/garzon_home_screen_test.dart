import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/operations_calendar.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/skeleton_loader.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/presentation/garzon_home_screen.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
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
  // modales que abre el home viven en rutas del Navigator.
  Future<void> pumpHomeScreen(WidgetTester tester, {Dio? dio}) async {
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
          home: const GarzonHomeScreen(),
        ),
      ),
    );

    
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));

    
    await tester.pumpAndSettle();
  }



  
  
  

  testWidgets('renders all dashboard sections after loading completes', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    
    expect(find.byType(SkeletonStatCard), findsNothing);

    
    expect(find.text('Métricas del Período'), findsOneWidget);

    
    expect(find.text('Total Propinas'), findsOneWidget);
    expect(find.text('Comandas con Propina'), findsOneWidget);

    
    expect(find.text('Acumulado para Retiro'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);

    
    expect(find.text('Calendario Operativo'), findsOneWidget);

    
    expect(find.text('PEDIDOS'), findsOneWidget);
    expect(find.text('SERVICIOS'), findsOneWidget);
    expect(find.text('Comandas de Mesa'), findsOneWidget);
    expect(find.text('Registro de Atención'), findsOneWidget);
  });

  testWidgets('stats card shows zero values when no API data', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    
    expect(find.text('0 ventas'), findsOneWidget);
  });

  testWidgets('payout card container is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('Acumulado para Retiro'), findsOneWidget);
  });

  testWidgets('payout card has a working Reportes export button', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.widgetWithText(ElevatedButton, 'Reportes'), findsOneWidget);

    // Persona real (dart:io) para que la generación del PDF y la escritura del
    // archivo puedan completar: sin plugins nativos el export falla, pero debe
    // ejecutarse y reportarlo (el chip anterior no hacía nada).
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reportes'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('No se pudo generar el reporte PDF'), findsOneWidget);
  });

  testWidgets('calendar shows weekday headers', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    
    expect(find.text('LU'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);
    expect(find.text('MI'), findsOneWidget);
    expect(find.text('JU'), findsOneWidget);
    expect(find.text('VI'), findsOneWidget);
    expect(find.text('SÁ'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);
  });

  testWidgets('calendar shows the type legend (paridad con Expo)', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('Asistencia'), findsOneWidget);
    expect(find.text('Anticipo'), findsOneWidget);
    expect(find.text('Propina'), findsOneWidget);
    expect(find.text('Hora extra'), findsOneWidget);
    expect(find.text('Comisión'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget);
    expect(find.text('Gratificación'), findsOneWidget);
  });

  testWidgets('calendar navigates to the next month', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    final currentMonth =
        DateFormat('MMMM yyyy', 'es_CL').format(DateTime.now()).toUpperCase();
    expect(find.text(currentMonth), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-nav-next')));
    await tester.pumpAndSettle();

    expect(find.text(currentMonth), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-nav-prev')));
    await tester.pumpAndSettle();

    expect(find.text(currentMonth), findsOneWidget);
  });

  testWidgets('tocar un evento del calendario abre su detalle', (
    WidgetTester tester,
  ) async {
    // Evento real del día de hoy en `/events/user` + su detalle.
    final now = DateTime.now();
    await pumpHomeScreen(
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
          'data': {'tipo': 'comision', 'cajero_nick': 'Pepe'},
        },
      }),
    );

    final dayCell = find.byKey(Key('calendar-day-${calendarDateKey(now)}'));
    await tester.scrollUntilVisible(
      dayCell,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comisión de Venta'));
    await tester.pumpAndSettle();

    expect(find.text('Fecha y Hora'), findsOneWidget);
    expect(find.text('Procesó la venta'), findsOneWidget);
    expect(find.text('Pepe'), findsOneWidget);
  });

  testWidgets('calendar selection opens the selected days detail', (
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
    await tester.tap(dayCell);
    await tester.pumpAndSettle();

    expect(find.text('1 día seleccionado'), findsOneWidget);

    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();

    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Sin eventos en los días seleccionados'), findsOneWidget);
  });

  
  
  

  testWidgets('PEDIDOS action card is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('PEDIDOS'), findsOneWidget);
    expect(find.text('Comandas de Mesa'), findsOneWidget);
  });

  testWidgets('SERVICIOS action card is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('SERVICIOS'), findsOneWidget);
    expect(find.text('Registro de Atención'), findsOneWidget);
  });

  testWidgets('FINANCIERO action card is rendered (enlace a Eventos Financieros)', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('FINANCIERO'), findsOneWidget);
    expect(find.text('Eventos y propinas'), findsOneWidget);
  });

  testWidgets('ANALÍTICAS action card is rendered (enlace a Analytics)', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('ANALÍTICAS'), findsOneWidget);
    expect(find.text('Métricas y ventas'), findsOneWidget);
  });
}
