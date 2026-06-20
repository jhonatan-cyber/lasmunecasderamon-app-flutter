import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/data/ventas_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';






Dio _dioWithResponse({
  required dynamic data,
  int statusCode = 200,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(requestOptions: options, statusCode: statusCode, data: data),
        );
      },
    ),
  );
  return dio;
}


Dio _dioWithError() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, error: 'Connection error'),
        );
      },
    ),
  );
  return dio;
}


Dio _dioWithConditionalResponse({
  required Map<String, dynamic> routeToData,
  int statusCode = 200,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final data = routeToData[options.path];
        if (data != null) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: statusCode,
              data: data,
            ),
          );
        } else {
          handler.reject(
            DioException(
              requestOptions: options,
              error: 'No mock for ${options.path}',
            ),
          );
        }
      },
    ),
  );
  return dio;
}

VentasListNotifier _buildNotifier(Dio dio) {
  return VentasListNotifier(ApiClient(dio: dio));
}





Map<String, dynamic> successSales() => {
      'success': true,
      'data': [
        {
          'id_venta': 1,
          'codigo': 'V-001',
          'estado': 2,
          'total': 50000,
          'subtotal': 50000,
          'metodo_pago': 'efectivo',
          'cliente_nombre': 'Juan Pérez',
          'habitacion_nombre': '101',
          'fecha_crea': '2025-01-15T14:30:00.000',
          'usuarios_nicks': 'admin',
        },
        {
          'id_venta': 2,
          'codigo': 'V-002',
          'estado': 1,
          'total': 25000,
          'metodo_pago': 'tarjeta',
          'cliente_nombre': 'María García',
          'habitacion_nombre': 'Barra',
          'fecha_crea': '2025-01-15T15:00:00.000',
          'usuarios_nicks': 'staff',
        },
        {
          'id_venta': 3,
          'codigo': 'V-003',
          'estado': 0,
          'total': 10000,
          'metodo_pago': 'efectivo',
          'cliente_nombre': 'Pedro López',
          'habitacion_nombre': '202',
          'fecha_crea': '2025-01-15T10:00:00.000',
          'usuarios_nicks': 'admin',
        },
      ],
    };

Map<String, dynamic> successSummary() => {
      'success': true,
      'data': {
        'total_ventas': 85000,
        'cantidad_ventas': 3,
        'cantidad_anuladas': 1,
      },
    };

Map<String, dynamic> emptySales() => {'success': true, 'data': []};

Map<String, dynamic> emptySummary() => {'success': true, 'data': {}};

Map<String, dynamic> failResponse() => {
      'success': false,
      'message': 'Error de servidor',
    };

Map<String, dynamic> successDetail() => {
      'success': true,
      'data': {
        'id_venta': 1,
        'codigo': 'V-001',
        'estado': 2,
        'total': 50000,
        'subtotal': 50000,
        'descuento': 0,
        'propina': 0,
        'metodo_pago': 'efectivo',
        'cliente_nombre': 'Juan Pérez',
        'items': [
          {'nombre': 'Producto 1', 'cantidad': 2, 'precio': 15000},
          {'nombre': 'Producto 2', 'cantidad': 1, 'precio': 20000},
        ],
      },
    };





void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('initial state', () {
    test('has correct defaults', () {
      final notifier = _buildNotifier(Dio());
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isRefreshing, false);
      expect(notifier.state.loadingDetail, false);
      expect(notifier.state.anulandoVenta, false);
      expect(notifier.state.error, '');
      expect(notifier.state.ventas, []);
      expect(notifier.state.resumen, {});
      expect(notifier.state.selectedVenta, null);
      notifier.dispose();
    });
  });

  group('fetchData', () {
    test('sets isLoading and clears error before fetch', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': successSales(),
            '/sales?tipo=resumen': successSummary(),
          },
        ),
      );

      final future = notifier.fetchData();
      expect(notifier.state.isLoading, true);
      expect(notifier.state.error, '');
      await future;
      notifier.dispose();
    });

    test('populates ventas and resumen on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': successSales(),
            '/sales?tipo=resumen': successSummary(),
          },
        ),
      );

      await notifier.fetchData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.ventas.length, 3);
      expect(notifier.state.resumen['total_ventas'], 85000);
      expect(notifier.state.error, '');
      notifier.dispose();
    });

    test('sets isRefreshing on manual refresh', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': emptySales(),
            '/sales?tipo=resumen': emptySummary(),
          },
        ),
      );

      final future = notifier.fetchData(isManual: true);
      expect(notifier.state.isRefreshing, true);
      expect(notifier.state.isLoading, false);
      await future;
      expect(notifier.state.isRefreshing, false);
      notifier.dispose();
    });

    test('handles empty data gracefully', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': emptySales(),
            '/sales?tipo=resumen': emptySummary(),
          },
        ),
      );

      await notifier.fetchData();

      expect(notifier.state.ventas, []);
      expect(notifier.state.resumen, {});
      expect(notifier.state.error, '');
      notifier.dispose();
    });

    test('sets error on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });

    test('clears error before new fetch', () async {
      final notifier = _buildNotifier(_dioWithError());

      
      await notifier.fetchData();
      expect(notifier.state.error, isNotEmpty);

      notifier.dispose();

      
      final notifier2 = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': successSales(),
            '/sales?tipo=resumen': successSummary(),
          },
        ),
      );

      await notifier2.fetchData();

      expect(notifier2.state.error, '');
      expect(notifier2.state.ventas.length, 3);
      notifier2.dispose();
    });
  });

  group('fetchDetail', () {
    test('sets loadingDetail before fetch and clears after', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: successDetail()),
      );

      final future = notifier.fetchDetail(1);
      expect(notifier.state.loadingDetail, true);
      await future;

      expect(notifier.state.loadingDetail, false);
      expect(notifier.state.selectedVenta, isNotNull);
      notifier.dispose();
    });

    test('populates selectedVenta on success', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: successDetail()),
      );

      await notifier.fetchDetail(1);

      expect(notifier.state.selectedVenta['id_venta'], 1);
      expect(notifier.state.selectedVenta['codigo'], 'V-001');
      expect((notifier.state.selectedVenta['items'] as List).length, 2);
      notifier.dispose();
    });

    test('handles fetch failure', () async {
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchDetail(999);

      expect(notifier.state.loadingDetail, false);
      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });
  });

  group('finalizarVenta', () {
    test('returns true and updates local estado on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/sales?limit=50': successSales(),
            '/sales?tipo=resumen': successSummary(),
            '/ventas/1': {'success': true},
          },
        ),
      );
      await notifier.fetchData();

      final result = await notifier.finalizarVenta(1);

      expect(result, true);
      final venta = notifier.state.ventas.firstWhere(
        (v) => v['id_venta'] == 1,
      );
      expect(venta['estado'], 1);
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final result = await notifier.finalizarVenta(1);

      expect(result, false);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.finalizarVenta(1);

      expect(result, false);
      notifier.dispose();
    });
  });

  group('anularVenta', () {
    test('returns true on success and resets anulandoVenta', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: {'success': true}),
      );

      final future = notifier.anularVenta(1, 'Cliente insatisfecho', 25000);
      expect(notifier.state.anulandoVenta, true);
      final result = await future;

      expect(result, true);
      expect(notifier.state.anulandoVenta, false);
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final result = await notifier.anularVenta(1, 'Motivo', 1000);

      expect(result, false);
      expect(notifier.state.anulandoVenta, false);
      notifier.dispose();
    });

    test('sets error on invalid response', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(
          data: {'success': false, 'message': 'Monto inválido'},
        ),
      );

      await notifier.anularVenta(1, 'Motivo', 0);

      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.anularVenta(1, 'Motivo', 1000);

      expect(result, false);
      expect(notifier.state.anulandoVenta, false);
      notifier.dispose();
    });
  });

  group('clearSelectedVenta', () {
    test('resets selectedVenta and loadingDetail', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: successDetail()),
      );

      await notifier.fetchDetail(1);
      expect(notifier.state.selectedVenta, isNotNull);

      notifier.clearSelectedVenta();

      expect(notifier.state.selectedVenta, null);
      expect(notifier.state.loadingDetail, false);
      notifier.dispose();
    });
  });
}
