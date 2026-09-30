import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/currency_text.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/presentation/nueva_venta_screen.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() async {
    setupTestEnvironment();
    await initializeDateFormatting('es_CL', null);
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  // Vista ancha (>800) para que se muestre el panel lateral con
  // «Registrar Venta» y quepan las dos filas del grid.
  void useWideViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Payloads vivos de referencia (mismo shape que devuelve el backend):
  // categorías modernas (name/status/total_products) y catálogo for_sale
  // (presentaciones con stock en el bar).
  final Map<String, dynamic> routes = {
    '/anfitrionas': {
      'success': true,
      'data': [
        {'id': 'a1', 'nick': 'Lola', 'name': 'Paola'},
      ],
    },
    '/rooms': {'success': true, 'data': []},
    '/cashregister/status': {
      'success': true,
      'data': {'hasOpenCaja': true},
    },
    '/clients': {
      'success': true,
      'data': [
        {'id': 'cl1', 'name': 'Carlos', 'lastName': 'Flores'},
      ],
    },
    '/categories': {
      'success': true,
      'data': [
        {'id': 'cat1', 'name': 'Cerveza', 'status': 1, 'total_products': 2},
        {'id': 'cat2', 'name': 'Champagne', 'status': 1, 'total_products': 1},
        // El dashboard las oculta en ventas: sin stock de producto o inactiva.
        {'id': 'cat3', 'name': 'Vacía', 'status': 1, 'total_products': 0},
        {'id': 'cat4', 'name': 'Baja', 'status': 0, 'total_products': 4},
      ],
    },
    '/products?for_sale=1&category_id=cat1': {
      'success': true,
      'data': [
        {
          'presentacion_id': 'p330',
          'presentacion_nombre': '330 ml',
          'producto_id': 'prod1',
          'producto_nombre': 'Paceña',
          'categoria_nombre': 'Cerveza',
          'precio_venta': 5000,
          'comision': 0,
          'stock_bar': 2,
        },
        {
          'presentacion_id': 'p710',
          'presentacion_nombre': '710 ml',
          'producto_id': 'prod1',
          'producto_nombre': 'Paceña',
          'categoria_nombre': 'Cerveza',
          'precio_venta': 20000,
          'comision': 5000,
          'stock_bar': 10,
        },
        // Presentación con venta por ml a precio de cliente y de anfitriona:
        // es la que habilita el selector Botella / Shot cliente / Shot anfitriona.
        {
          'presentacion_id': 'p750',
          'presentacion_nombre': '750 ml',
          'producto_id': 'prodw',
          'producto_nombre': 'Whisky Black',
          'categoria_nombre': 'Whisky',
          'precio_venta': 180000,
          'comision': 5000,
          'stock_bar': 2,
          'opciones_venta': [
            {'tipo': 'botella', 'precio': 180000, 'comision': 5000},
            {
              'tipo': 'shot',
              'precio': 6000,
              'comision': 0,
              'precio_anfitriona': 3500,
            },
          ],
        },
      ],
    },
    '/products?for_sale=1&category_id=cat2': {
      'success': true,
      'data': [
        {
          'presentacion_id': 'ch1',
          'presentacion_nombre': '750 ml',
          'producto_id': 'prodch',
          'producto_nombre': 'Champagne Gran',
          'categoria_nombre': 'Champagne',
          'precio_venta': 50000,
          'comision': 3000,
          'stock_bar': 3,
        },
      ],
    },
    // Búsqueda global (NewSaleSearch): match exacto del término para poder
    // comprobar también el estado «No hay resultados» con otro término.
    '/products?for_sale=1&term=pace': {
      'success': true,
      'data': [
        {
          'presentacion_id': 'p355',
          'presentacion_nombre': '355 ml',
          'producto_id': 'prodcorona',
          'producto_nombre': 'Corona',
          'categoria_nombre': 'Cerveza',
          'precio_venta': 7000,
          'comision': 0,
          'stock_bar': 5,
        },
      ],
    },
  };

  // Dio que registra URLs y bodies y responde según `routes` (match por
  // `path.contains(clave)`, igual que `createMockDioWithRoutes`).
  Dio makeRecordingDio(List<String> urls, List<dynamic> bodies) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          urls.add(options.uri.toString());
          bodies.add(options.data);
          for (final entry in routes.entries) {
            if (options.path.contains(entry.key)) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: entry.value,
                ),
              );
              return;
            }
          }
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true},
            ),
          );
        },
      ),
    );
    return dio;
  }

  Widget buildApp(Dio dio, {bool withRouter = false}) {
    final List<Override> overrides = [
      authProvider.overrideWith(
        (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
      ),
      apiClientProvider.overrideWith((ref) => ApiClient(dio: dio)),
    ];
    final theme = AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor);

    if (!withRouter) {
      return createTestApp(
        overrides: overrides,
        child: MaterialApp(theme: theme, home: const NuevaVentaScreen()),
      );
    }

    // `context.pop()` del envío exitoso necesita un GoRouter con una ruta
    // detrás (en la app real es el stack del cajero).
    final router = GoRouter(
      initialLocation: '/venta',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/venta',
          builder: (context, state) => const NuevaVentaScreen(),
        ),
        // Pantalla de caja simulada (AppBar con su botón «atrás»).
        GoRoute(
          path: '/cajero/caja',
          builder: (context, state) =>
              Scaffold(appBar: AppBar(title: const Text('Caja'))),
        ),
      ],
    );
    return createTestApp(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router, theme: theme),
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Dio dio,
    bool withRouter = false,
  }) async {
    useWideViewport(tester);
    await tester.pumpWidget(buildApp(dio, withRouter: withRouter));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista el catálogo for_sale y oculta categorías sin ventas', (
    WidgetTester tester,
  ) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(tester, dio: makeRecordingDio(urls, bodies));

    // Filtro del dashboard: estado === 1 y total_products > 0.
    expect(find.text('Cerveza'), findsOneWidget);
    expect(find.text('Champagne'), findsOneWidget);
    expect(find.text('Vacía'), findsNothing);
    expect(find.text('Baja'), findsNothing);

    // Pide el catálogo de venta del bar (nunca el admin sin for_sale).
    expect(
      urls.any((u) => u.contains('/products?for_sale=1&category_id=cat1')),
      isTrue,
      reason: 'debe cargar /products?for_sale=1 de la categoría activa',
    );
    expect(
      urls.any((u) => u.contains('/products?category_id=')),
      isFalse,
      reason: 'no debe usar el catálogo admin de productos',
    );

    // Presentaciones normalizadas: nombre producto + presentación y
    // precio_venta (no el precio legacy del producto).
    expect(find.text('Paceña 330 ml'), findsOneWidget);
    expect(find.text('Paceña 710 ml'), findsOneWidget);
    expect(find.text(formatCurrency(5000)), findsWidgets);
    expect(find.text(formatCurrency(20000)), findsWidgets);

    // Las etiquetas de los selectores usan el shape moderno (name/nick).
    await tester.tap(find.text('Cliente General'));
    await tester.pumpAndSettle();
    expect(find.text('Carlos'), findsOneWidget);
  });

  testWidgets('el carrito sobrevive al cambiar de categoría y envía la '
      'presentación', (WidgetTester tester) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(
      tester,
      dio: makeRecordingDio(urls, bodies),
      withRouter: true,
    );

    expect(find.text('Paceña 330 ml'), findsOneWidget);

    // Agrega la presentación de 330 ml (stock en el bar: 2).
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();

    // Cambia de categoría: antes los ítems se perdían en silencio del total
    // y del payload porque el carrito solo guardaba el id.
    await tester.tap(find.text('Champagne'));
    await tester.pumpAndSettle();

    expect(find.text('Champagne Gran 750 ml'), findsOneWidget);
    expect(find.text('Paceña 330 ml'), findsOneWidget); // sigue en el carro
    expect(
      find.text(formatCurrency(5000)),
      findsWidgets,
    ); // total a pagar intacto

    final registrarBtn = find.widgetWithText(ElevatedButton, 'Registrar Venta');
    expect(
      registrarBtn,
      findsOneWidget,
      reason: 'botón Registrar Venta visible',
    );
    await tester.tap(registrarBtn);
    await tester.pumpAndSettle();

    final salesIdx = urls.indexWhere((u) => u.endsWith('/sales'));
    expect(
      salesIdx,
      greaterThanOrEqualTo(0),
      reason: 'debe registrar la venta; urls=$urls',
    );
    final payload = bodies[salesIdx] as Map;
    final detalles = (payload['detalles'] as List).cast<Map>();

    expect(detalles, hasLength(1));
    expect(detalles[0]['producto_id'], 'prod1');
    expect(detalles[0]['presentacion_id'], 'p330');
    expect(detalles[0]['tipo_venta'], 'botella');
    expect(detalles[0]['precio'], 5000);
    expect(detalles[0]['sub_total'], 5000);
    expect(detalles[0]['comision'], 0);
    expect(payload['total'], 5000);

    // Drena el snackbar de éxito para no dejar timers pendientes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('el stepper de cantidad se topa en el stock del bar', (
    WidgetTester tester,
  ) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(tester, dio: makeRecordingDio(urls, bodies));

    // p330 tiene stock_bar = 2: el backend revierte la venta si se pide más
    // (INSUFFICIENT_BAR_STOCK), igual que el máximo del dashboard.
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('busca con debounce de 300 ms y agrega el resultado al '
      'payload', (WidgetTester tester) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(
      tester,
      dio: makeRecordingDio(urls, bodies),
      withRouter: true,
    );

    final searchField = find.byKey(const Key('nueva_venta_search_input'));
    expect(searchField, findsOneWidget);

    // Dos cambios rápidos: el debounce cancela el primero y solo dispara
    // una petición con el último término (300 ms, como el dashboard).
    await tester.enterText(searchField, 'p');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(searchField, 'pace');
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Buscando...'),
      findsOneWidget,
      reason: 'estado de carga mientras espera el debounce',
    );
    expect(
      urls.where((u) => u.contains('&term=')),
      isEmpty,
      reason: 'debe esperar los 300 ms antes de pedir',
    );

    await tester.pump(const Duration(milliseconds: 150));
    final termRequests = urls.where((u) => u.contains('&term=')).toList();
    expect(termRequests, hasLength(1), reason: 'una sola petición: $urls');
    expect(termRequests.single, contains('/products?for_sale=1&term=pace'));
    await tester.pumpAndSettle();

    // El grid por categoría queda oculto mientras hay búsqueda.
    expect(find.text('Corona 355 ml'), findsOneWidget);
    expect(find.text('Paceña 330 ml'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pumpAndSettle();

    final registrarBtn = find.widgetWithText(ElevatedButton, 'Registrar Venta');
    await tester.tap(registrarBtn);
    await tester.pumpAndSettle();

    final salesIdx = urls.indexWhere((u) => u.endsWith('/sales'));
    expect(
      salesIdx,
      greaterThanOrEqualTo(0),
      reason: 'debe registrar la venta; urls=$urls',
    );
    final payload = bodies[salesIdx] as Map;
    final detalles = (payload['detalles'] as List).cast<Map>();

    // La presentación encontrada por la búsqueda entra al catálogo y al
    // payload con el mismo shape que el dashboard.
    expect(detalles, hasLength(1));
    expect(detalles[0]['producto_id'], 'prodcorona');
    expect(detalles[0]['presentacion_id'], 'p355');
    expect(detalles[0]['tipo_venta'], 'botella');
    expect(detalles[0]['precio'], 7000);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('muestra «No hay resultados» y Limpiar restaura el grid por '
      'categoría', (WidgetTester tester) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(tester, dio: makeRecordingDio(urls, bodies));

    final searchField = find.byKey(const Key('nueva_venta_search_input'));
    await tester.enterText(searchField, 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No hay resultados'), findsOneWidget);
    expect(find.text('Paceña 330 ml'), findsNothing);

    await tester.tap(find.byKey(const Key('nueva_venta_search_clear')));
    await tester.pumpAndSettle();

    expect(find.text('No hay resultados'), findsNothing);
    expect(find.text('Paceña 330 ml'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
      reason: 'Limpiar vacía el campo de búsqueda',
    );
  });

  testWidgets('con la caja cerrada avisa y bloquea «Registrar Venta»', (
    WidgetTester tester,
  ) async {
    routes['/cashregister/status'] = <String, dynamic>{
      'success': true,
      'data': {'hasOpenCaja': false},
    };
    addTearDown(() {
      routes['/cashregister/status'] = <String, dynamic>{
        'success': true,
        'data': {'hasOpenCaja': true},
      };
    });

    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(tester, dio: makeRecordingDio(urls, bodies));

    expect(
      urls.any((u) => u.contains('/cashregister/status')),
      isTrue,
      reason: 'debe consultar el estado de la caja al cargar',
    );

    // Mismos textos que `CajaStatusCheck` del dashboard.
    expect(find.text('No hay caja abierta.'), findsOneWidget);
    expect(
      find.text('No se pueden realizar ventas sin una caja abierta.'),
      findsOneWidget,
    );
    expect(find.text('Abrir Caja'), findsOneWidget);

    final registrarBtn = find.widgetWithText(ElevatedButton, 'Registrar Venta');
    expect(
      tester.widget<ElevatedButton>(registrarBtn).onPressed,
      isNull,
      reason: 'el envío queda deshabilitado con la caja cerrada',
    );

    // Seguir armando el carrito está permitido; lo que se bloquea es cobrar.
    await tester.tap(find.byIcon(Icons.add_circle).first);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    expect(
      urls.any((u) => u.endsWith('/sales')),
      isFalse,
      reason: 'no debe intentar POST /sales con la caja cerrada',
    );
  });
  testWidgets('con la caja abierta no muestra el aviso y deja enviar', (
    WidgetTester tester,
  ) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(tester, dio: makeRecordingDio(urls, bodies));

    expect(find.text('No hay caja abierta.'), findsNothing);
    expect(find.text('Abrir Caja'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Registrar Venta'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('al volver de la pantalla de Caja refresca solo el estado de '
      'caja', (WidgetTester tester) async {
    routes['/cashregister/status'] = <String, dynamic>{
      'success': true,
      'data': {'hasOpenCaja': false},
    };
    addTearDown(() {
      routes['/cashregister/status'] = <String, dynamic>{
        'success': true,
        'data': {'hasOpenCaja': true},
      };
    });

    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(
      tester,
      dio: makeRecordingDio(urls, bodies),
      withRouter: true,
    );

    expect(find.text('No hay caja abierta.'), findsOneWidget);
    int productCalls() => urls
        .where((u) => u.contains('/products?for_sale=1&category_id='))
        .length;
    final catalogCallsBefore = productCalls();

    await tester.tap(find.text('Abrir Caja'));
    await tester.pumpAndSettle();
    expect(
      find.text('Caja'),
      findsOneWidget,
      reason: 'abre la pantalla de caja',
    );

    // El usuario abre caja allí y vuelve con «atrás».
    routes['/cashregister/status'] = <String, dynamic>{
      'success': true,
      'data': {'hasOpenCaja': true},
    };
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('No hay caja abierta.'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Registrar Venta'),
          )
          .onPressed,
      isNotNull,
      reason: 'con la caja abierta el envío se habilita',
    );
    expect(
      urls.where((u) => u.contains('/cashregister/status')).length,
      greaterThanOrEqualTo(2),
      reason: 'debe reconsultar la caja al volver',
    );
    expect(
      productCalls(),
      catalogCallsBefore,
      reason: 'el catálogo no debe recargarse',
    );
  });

  // Presentación del catálogo que sí ofrece las tres formas de venta.
  const String whisky = 'Whisky Black 750 ml';

  /// Toca algo dentro de la tarjeta del producto (hace visible si hace falta).
  Future<void> tapInCard(
    WidgetTester tester,
    String productName,
    Finder target,
  ) async {
    final card = find
        .ancestor(of: find.text(productName), matching: find.byType(Container))
        .first;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: card, matching: target).first);
    await tester.pumpAndSettle();
  }

  testWidgets('elige shot de anfitriona y manda precio y audiencia al '
      'payload', (WidgetTester tester) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(
      tester,
      dio: makeRecordingDio(urls, bodies),
      withRouter: true,
    );

    // Solo quien ofrece venta por ml pinta el selector (espejo del dashboard).
    expect(find.text('Botella · ${formatCurrency(180000)}'), findsOneWidget);
    expect(find.text('Shot cliente · ${formatCurrency(6000)}'), findsOneWidget);
    expect(find.text('Shot anfitriona · ${formatCurrency(3500)}'), findsOneWidget);
    expect(
      find.text('Botella · ${formatCurrency(5000)}'),
      findsNothing,
      reason: 'sin opciones de venta no se pinta ningún chip',
    );

    // Elige shot de anfitriona: la tarjeta pasa a cobrar su precio.
    await tapInCard(
      tester,
      whisky,
      find.text('Shot anfitriona · ${formatCurrency(3500)}'),
    );
    expect(find.text(formatCurrency(3500)), findsWidgets);

    await tapInCard(tester, whisky, find.byIcon(Icons.add_circle));

    // El carrito etiqueta la línea: un shot no se confunde con la botella.
    expect(find.text('Shot anfitriona'), findsOneWidget);
    expect(find.text('1 x ${formatCurrency(3500)}'), findsOneWidget);
    expect(find.text(formatCurrency(186000)), findsNothing);

    final registrarBtn = find.widgetWithText(ElevatedButton, 'Registrar Venta');
    await tester.tap(registrarBtn);
    await tester.pumpAndSettle();

    final salesIdx = urls.indexWhere((u) => u.endsWith('/sales'));
    expect(salesIdx, greaterThanOrEqualTo(0), reason: 'debe registrar: $urls');
    final payload = bodies[salesIdx] as Map;
    final detalles = (payload['detalles'] as List).cast<Map>();

    expect(detalles, hasLength(1));
    expect(detalles[0]['presentacion_id'], 'p750');
    expect(detalles[0]['tipo_venta'], 'shot');
    expect(detalles[0]['shot_anfitriona'], isTrue);
    expect(detalles[0]['precio'], 3500);
    expect(detalles[0]['sub_total'], 3500);
    expect(detalles[0]['comision'], 0, reason: 'el shot no hereda comisión');
    expect(payload['total'], 3500);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('la botella y el shot de la misma presentación son líneas '
      'separadas en el carrito', (WidgetTester tester) async {
    final urls = <String>[];
    final bodies = <dynamic>[];
    await pumpScreen(
      tester,
      dio: makeRecordingDio(urls, bodies),
      withRouter: true,
    );

    // Botella primero (por defecto) y luego shot de cliente: antes ambas
    // entraban con la misma clave y pisaban precio, comisión y cantidad.
    await tapInCard(tester, whisky, find.byIcon(Icons.add_circle));
    await tapInCard(
      tester,
      whisky,
      find.text('Shot cliente · ${formatCurrency(6000)}'),
    );
    await tapInCard(tester, whisky, find.byIcon(Icons.add_circle));

    expect(find.text('1 x ${formatCurrency(180000)}'), findsOneWidget);
    expect(find.text('1 x ${formatCurrency(6000)}'), findsOneWidget);
    expect(find.text('Shot cliente'), findsOneWidget);
    expect(
      find.text(formatCurrency(186000)),
      findsOneWidget,
      reason: 'total = botella + shot',
    );

    final registrarBtn = find.widgetWithText(ElevatedButton, 'Registrar Venta');
    await tester.tap(registrarBtn);
    await tester.pumpAndSettle();

    final salesIdx = urls.indexWhere((u) => u.endsWith('/sales'));
    expect(salesIdx, greaterThanOrEqualTo(0), reason: 'debe registrar: $urls');
    final payload = bodies[salesIdx] as Map;
    final detalles = (payload['detalles'] as List).cast<Map>();

    expect(detalles, hasLength(2));
    final botella = detalles.firstWhere((d) => d['tipo_venta'] == 'botella');
    final shot = detalles.firstWhere((d) => d['tipo_venta'] == 'shot');

    expect(botella['precio'], 180000);
    expect(botella['sub_total'], 180000);
    expect(botella.containsKey('shot_anfitriona'), isFalse);
    expect(shot['precio'], 6000);
    expect(shot['shot_anfitriona'], isFalse);
    expect(shot['comision'], 0, reason: 'shot: comisión 0, no la de botella');
    expect(botella['comision'], 5000);
    expect(payload['total'], 186000);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
