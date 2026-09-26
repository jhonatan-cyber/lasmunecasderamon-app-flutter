import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/report_service.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/currency_text.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/event_detail_modal.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import '../helpers/test_setup.dart';

void main() {
  setUp(() async {
    setupTestEnvironment();
    await initializeDateFormatting('es_CL', null);
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  LiquidationEvent event({
    String id = '8a1b',
    String type = 'comision',
    String? subType = 'venta',
    double amount = 250,
    String codigo = 'DEV-FIN-001',
    int? estado = 1,
  }) {
    return LiquidationEvent(
      id: id,
      type: type,
      subType: subType,
      codigo: codigo,
      date: DateTime(2026, 9, 26, 21, 15),
      amount: amount,
      estado: estado,
    );
  }

  Future<void> pumpAndOpen(
    WidgetTester tester,
    LiquidationEvent item, {
    Object? detail,
    String? userRole,
    Brightness brightness = Brightness.dark,
    bool forceDark = false,
  }) async {
    // El ProviderScope va por encima del MaterialApp (como en `main.dart`):
    // el diálogo vive en una ruta del Navigator y necesita leer providers.
    await tester.pumpWidget(
      createTestApp(
        overrides: [
          apiClientProvider.overrideWith(
            (ref) => ApiClient(
              dio: createMockDioWithRoutes({
                '/events/detail/': detail ?? {'success': true, 'data': null},
              }),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(brightness, AppTheme.primaryColor),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEventDetailModal(
                    context,
                    item,
                    userRole: userRole,
                    forceDark: forceDark,
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los datos del evento y el detalle de la comisión', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(
      tester,
      event(),
      userRole: 'cajero',
      detail: {
        'success': true,
        'data': {
          'tipo': 'comision',
          'monto_total': 250,
          'habitacion_nombre': 'Barra',
          'cajero_nick': 'Pepe',
          'anfitrionas': [
            {'nick': 'Lizi', 'comision': 250},
          ],
          'propinas_detalle': [
            {'nick': 'sebas', 'monto': 300},
          ],
          'detalles': [
            {'cantidad': 2, 'producto_nombre': 'Cerveza', 'subtotal': 350},
          ],
        },
      },
    );

    expect(find.text('COMISIÓN DE VENTA'), findsOneWidget);
    expect(find.text('+${formatCurrency(250)}'), findsOneWidget);
    expect(find.text('Fecha y Hora'), findsOneWidget);
    expect(find.text('26/09/2026 21:15'), findsOneWidget);
    expect(find.text('Origen'), findsOneWidget);
    expect(find.text('Por cobrar'), findsOneWidget);

    // Bloque de detalle real (claves del payload de /events/detail).
    expect(find.text('Procesó la venta'), findsOneWidget);
    expect(find.text('Pepe'), findsOneWidget);
    expect(find.text('Habitación'), findsOneWidget);
    expect(find.text('Barra'), findsOneWidget);
    expect(find.text('Productos'), findsOneWidget);
    expect(find.text('2x Cerveza'), findsOneWidget);
    expect(find.text(formatCurrency(350)), findsOneWidget);
    expect(find.text('Propina total'), findsOneWidget);
    expect(find.text(formatCurrency(300)), findsOneWidget);
    expect(find.text('Dividida entre'), findsOneWidget);
  });

  testWidgets('la anfitriona ve su comisión y no el reparto de propinas', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(
      tester,
      event(),
      userRole: 'anfitriona',
      detail: {
        'success': true,
        'data': {
          'tipo': 'comision',
          'anfitrionas': [
            {'nick': 'Lizi', 'comision': 250},
          ],
          'propinas_detalle': [
            {'nick': 'sebas', 'monto': 300},
          ],
        },
      },
    );

    expect(find.text('Comisión por anfitriona'), findsOneWidget);
    expect(find.text('Lizi'), findsOneWidget);
    expect(find.text(formatCurrency(250)), findsOneWidget);
    expect(find.text('Propina total'), findsNothing);
    expect(find.text('Dividida entre'), findsNothing);
  });

  testWidgets('el anticipo muestra solicitante, motivo e historial', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(
      tester,
      event(
        type: 'anticipo',
        subType: null,
        amount: 5000,
        codigo: 'ANT',
        estado: 2,
      ),
      detail: {
        'success': true,
        'data': {
          'tipo': 'anticipo',
          'solicitante_nick': 'damo',
          'monto': 5000,
          'observacion': 'Préstamo',
          'historial': [
            {
              'accion': 'solicitud',
              'fecha_crea': '2026-09-20T10:00:00.000Z',
              'usuario_accion_nick': 'damo',
            },
          ],
        },
      },
    );

    expect(find.text('ANTICIPO'), findsOneWidget);
    expect(find.text('-${formatCurrency(5000)}'), findsOneWidget);
    expect(find.text('Solicitado por'), findsOneWidget);
    expect(find.text('damo'), findsOneWidget);
    expect(find.text('Motivo'), findsOneWidget);
    expect(find.text('Préstamo'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Solicitado'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('forceDark mantiene la paleta oscura en tema claro', (
    WidgetTester tester,
  ) async {
    // El administrativo del cajero es dark-only: su detalle no debe cambiar de
    // paleta con el tema activo.
    await pumpAndOpen(
      tester,
      event(),
      brightness: Brightness.light,
      forceDark: true,
    );

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, AppTheme.darkSurfaceColor);
  });

  testWidgets('sin detalle adicional muestra solo los datos del evento', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(tester, event());

    expect(find.text('Cargando detalle...'), findsNothing);
    expect(find.text('Fecha y Hora'), findsOneWidget);
    expect(find.text('COMISIÓN DE VENTA'), findsOneWidget);
    expect(find.text('Productos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la asistencia muestra sueldo, aporte y neto', (
    WidgetTester tester,
  ) async {
    await pumpAndOpen(
      tester,
      event(
        type: 'asistencia',
        subType: null,
        amount: 45000,
        codigo: 'ASIS',
      ),
      detail: {
        'success': true,
        'data': {
          'tipo': 'asistencia',
          'sueldo': 50000,
          'aporte': 5000,
          'descuento_total': 0,
          'semanas_con_descuento': 0,
          'neto': 45000,
        },
      },
    );

    expect(find.text('Sueldo'), findsOneWidget);
    expect(find.text(formatCurrency(50000)), findsOneWidget);
    expect(find.text('Aporte'), findsOneWidget);
    expect(find.text('-${formatCurrency(5000)}'), findsOneWidget);
    expect(find.text('Neto por asistencia'), findsOneWidget);
    expect(find.text(formatCurrency(45000)), findsOneWidget);
  });
}
