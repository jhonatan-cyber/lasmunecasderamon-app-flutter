import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/caja_status.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/caja_closed_banner.dart';

void main() {
  Response resp(dynamic data) => Response(
    requestOptions: RequestOptions(path: '/cashregister/status'),
    data: data,
  );

  group('parseCajaAbierta', () {
    test('devuelve true/false cuando el backend lo confirma', () {
      expect(
        parseCajaAbierta(
          resp({
            'success': true,
            'data': {'hasOpenCaja': true},
          }),
        ),
        isTrue,
      );
      expect(
        parseCajaAbierta(
          resp({
            'success': true,
            'data': {'hasOpenCaja': false},
          }),
        ),
        isFalse,
      );
    });

    test('devuelve null sin data o con error (no debe bloquear)', () {
      expect(parseCajaAbierta(resp({'success': true})), isNull);
      expect(
        parseCajaAbierta(resp({'success': false, 'message': 'x'})),
        isNull,
      );
      expect(parseCajaAbierta(resp(null)), isNull);
    });
  });

  group('fetchCajaAbierta', () {
    test('lee el estado con un solo GET y devuelve null si falla', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {'hasOpenCaja': false},
                },
              ),
            ),
          ),
        );
      expect(await fetchCajaAbierta(ApiClient(dio: dio)), isFalse);

      final failing = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException(requestOptions: options, error: 'boom'),
            ),
          ),
        );
      expect(await fetchCajaAbierta(ApiClient(dio: failing)), isNull);
    });
  });

  testWidgets('«Abrir Caja» navega y refresca el estado al volver', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var refreshed = false;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: CajaClosedBanner(
              onReturnedFromCaja: () async {
                refreshed = true;
              },
            ),
          ),
        ),
        GoRoute(
          path: '/cajero/caja',
          builder: (context, state) =>
              Scaffold(appBar: AppBar(title: const Text('Caja'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
      ),
    );

    // Mismos textos que el Alert de CajaStatusCheck del dashboard.
    expect(find.text('No hay caja abierta.'), findsOneWidget);
    expect(
      find.text('No se pueden realizar ventas sin una caja abierta.'),
      findsOneWidget,
    );
    expect(find.text('Abrir Caja'), findsOneWidget);

    await tester.tap(find.text('Abrir Caja'));
    await tester.pumpAndSettle();
    expect(
      find.text('Caja'),
      findsOneWidget,
      reason: 'abre la pantalla de caja',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      refreshed,
      isTrue,
      reason: 'al volver debe refrescarse solo el estado de caja',
    );
  });
}
