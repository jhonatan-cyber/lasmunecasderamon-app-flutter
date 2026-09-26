import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/report_service.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/operations_calendar.dart';
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
    required String type,
    required DateTime date,
    String id = '8a1b',
    String? subType,
    double amount = 1000,
    String codigo = 'DEV-001',
    int? estado = 1,
  }) {
    return LiquidationEvent(
      id: id,
      type: type,
      subType: subType,
      codigo: codigo,
      date: date,
      amount: amount,
      estado: estado,
    );
  }

  /// Monta la barra de selección como host de la hoja de detalle. El
  /// ProviderScope va por encima del MaterialApp porque el modal de detalle se
  /// abre en una ruta del Navigator.
  Future<void> pumpSheetHost(
    WidgetTester tester, {
    required List<LiquidationEvent> events,
    required Set<String> selectedDates,
    Object? detail,
  }) async {
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
          theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
          home: Scaffold(
            body: Builder(
              builder: (context) => SelectedDaysBar(
                count: selectedDates.length,
                onDetails: () => showSelectedEventsSheet(
                  context,
                  events: events,
                  selectedDates: selectedDates,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpCalendar(
    WidgetTester tester, {
    List<LiquidationEvent> events = const [],
    Set<String>? selectedDates,
  }) async {
    final selected = selectedDates ?? <String>{};
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return OperationsCalendar(
                  events: events,
                  selectedDates: selected,
                  onDateToggle: (dateKey) {
                    setState(() {
                      if (!selected.remove(dateKey)) selected.add(dateKey);
                    });
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('toggles a day on and off', (WidgetTester tester) async {
    final selected = <String>{};
    final todayKey = calendarDateKey(DateTime.now());
    await pumpCalendar(tester, selectedDates: selected);

    final dayCell = find.byKey(Key('calendar-day-$todayKey'));
    expect(dayCell, findsOneWidget);

    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(selected, {todayKey});

    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
  });

  testWidgets('renders the weekday header, legend and 42 day cells', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester);

    for (final label in ['DO', 'LU', 'MA', 'MI', 'JU', 'VI', 'SÁ']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Comisión'), findsOneWidget);
    expect(find.text('Hora extra'), findsOneWidget);

    // 6 semanas × 7 días (la clave se propaga al KeyedSubtree del InkWell, así
    // que se cuentan solo las celdas).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.key.toString().contains('calendar-day-'),
      ),
      findsNWidgets(42),
    );
  });

  testWidgets('navigates to the previous and next month', (
    WidgetTester tester,
  ) async {
    await pumpCalendar(tester);

    final formatter = DateFormat('MMMM yyyy', 'es_CL');
    final current = formatter.format(DateTime.now()).toUpperCase();
    final next = formatter
        .format(DateTime(DateTime.now().year, DateTime.now().month + 1, 1))
        .toUpperCase();

    expect(find.text(current), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-nav-next')));
    await tester.pumpAndSettle();
    expect(find.text(next), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-nav-prev')));
    await tester.pumpAndSettle();
    expect(find.text(current), findsOneWidget);
  });

  testWidgets('marks the days with events', (WidgetTester tester) async {
    final today = DateTime.now();
    await pumpCalendar(
      tester,
      events: [
        event(type: 'comision', date: today),
        event(type: 'propina', date: today, codigo: 'TIPS'),
      ],
    );

    final todayKey = calendarDateKey(today);
    final cell = find.byKey(Key('calendar-day-$todayKey'));
    final dots = find.descendant(of: cell, matching: find.byType(Container));

    // Un punto por tipo de evento del día (comisión y propina).
    expect(tester.widgetList(dots).length, greaterThanOrEqualTo(2));
  });

  testWidgets('cabe en un viewport de teléfono sin desbordar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCalendar(
      tester,
      events: [event(type: 'servicio', date: DateTime.now())],
    );

    expect(tester.takeException(), isNull);

    final cardSize = tester.getSize(find.byType(OperationsCalendar));
    expect(cardSize.width, lessThanOrEqualTo(360));
    // Mes + semana + 6 filas de días + leyenda.
    expect(cardSize.height, greaterThan(300));
  });

  test('eventsForDates filtra por día y ordena del más reciente al más antiguo', () {
    final events = [
      event(type: 'servicio', date: DateTime(2026, 9, 26, 22, 0), amount: 50000),
      event(type: 'propina', date: DateTime(2026, 9, 25, 20, 0), amount: 1500),
      event(type: 'anticipo', date: DateTime(2026, 9, 26, 23, 30), amount: 5000),
    ];

    final selected = eventsForDates(events, {'2026-09-26'});

    expect(selected.length, 2);
    expect(selected.first.type, 'anticipo');
    expect(selected.last.type, 'servicio');
  });

  testWidgets('la barra de selección y la hoja de detalle muestran los eventos', (
    WidgetTester tester,
  ) async {
    final events = [
      event(
        type: 'comision',
        subType: 'venta',
        date: DateTime(2026, 9, 26, 21, 15),
        amount: 250,
        codigo: 'DEV-FIN-001',
      ),
    ];
    final selected = <String>{'2026-09-26'};

    await pumpSheetHost(tester, events: events, selectedDates: selected);

    expect(find.text('1 día seleccionado'), findsOneWidget);

    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();

    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Comisión de Venta'), findsOneWidget);
    expect(find.text('26/09/26 21:15 · DEV-FIN-001'), findsOneWidget);
  });

  testWidgets('la hoja de detalle avisa cuando no hay eventos', (
    WidgetTester tester,
  ) async {
    await pumpSheetHost(
      tester,
      events: const [],
      selectedDates: const {'2026-09-26', '2026-09-27'},
    );

    expect(find.text('2 días seleccionados'), findsOneWidget);

    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();

    expect(find.text('Sin eventos en los días seleccionados'), findsOneWidget);
  });

  testWidgets('tocar un evento de la hoja abre su detalle', (
    WidgetTester tester,
  ) async {
    final events = [
      event(
        type: 'comision',
        subType: 'venta',
        date: DateTime(2026, 9, 26, 21, 15),
        amount: 250,
        codigo: 'DEV-FIN-001',
      ),
    ];

    await pumpSheetHost(
      tester,
      events: events,
      selectedDates: const {'2026-09-26'},
      detail: {
        'success': true,
        'data': {'tipo': 'comision', 'cajero_nick': 'Pepe'},
      },
    );

    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();
    expect(find.text('Eventos'), findsOneWidget);

    await tester.tap(find.text('Comisión de Venta'));
    await tester.pumpAndSettle();

    // Se abre el detalle del evento (GET /events/detail/{id}?type=...).
    expect(find.text('Fecha y Hora'), findsOneWidget);
    expect(find.text('Procesó la venta'), findsOneWidget);
    expect(find.text('Pepe'), findsOneWidget);
  });
}
