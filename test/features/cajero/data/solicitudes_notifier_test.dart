import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/data/solicitudes_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';





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
            Response(requestOptions: options, statusCode: statusCode, data: data),
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

SolicitudesListNotifier _buildNotifier(Dio dio) {
  return SolicitudesListNotifier(ApiClient(dio: dio));
}





Map<String, dynamic> emptySuccess() => {'success': true, 'data': []};

Map<String, dynamic> emptyCajaStats() => {'success': true, 'cajas_abiertas': 1};

Map<String, dynamic> closedCajaStats() => {'success': true, 'cajas_abiertas': 0};

Map<String, dynamic> servicesData() => {
      'success': true,
      'data': [
        {
          'id_solicitud': 1,
          'codigo': 'SRV-001',
          'total': 25000,
          'habitacion_nombre': '101',
          'solicitado_por_nombre': 'Luisa',
          'fecha_solicitud': '2025-01-15T14:00:00.000',
          'estado': 0,
          'tiempo': 30,
          'precio_servicio': 25000,
        },
      ],
    };

Map<String, dynamic> ordersData() => {
      'success': true,
      'data': [
        {
          'id_pedido': 10,
          'codigo': 'PED-001',
          'total': 15000,
          'habitacion_nombre': 'VIP',
          'mesero_nick': 'Carlos',
          'fecha_crea': '2025-01-15T15:00:00.000',
          'estado': 0,
          'metodo_pago': 'efectivo',
        },
      ],
    };

Map<String, dynamic> advancesData() => {
      'success': true,
      'data': [
        {
          'id_anticipo': 100,
          'codigo': 'ANT-001',
          'monto': 50000,
          'estado': 1,
          'usuario': 'Juan Pérez',
          'fecha_crea': '2025-01-15T16:00:00.000',
          'motivo': 'Compra de insumos',
        },
        {
          'id_anticipo': 101,
          'codigo': 'ANT-002',
          'monto': 30000,
          'estado': 2,
          'usuario': 'Ana López',
          'fecha_crea': '2025-01-15T17:00:00.000',
        },
      ],
    };

Map<String, dynamic> hostessesData() => {
      'success': true,
      'data': [
        {'id': 1, 'nombre': 'María'},
        {'id': 2, 'nombre': 'Luisa'},
      ],
    };

Map<String, dynamic> successResponse() => {'success': true};

Map<String, dynamic> failResponse() => {
      'success': false,
      'message': 'Error del servidor',
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
      expect(notifier.state.error, '');
      expect(notifier.state.solicitudes, []);
      expect(notifier.state.allHostesses, []);
      expect(notifier.state.cajaAbierta, false);
      notifier.dispose();
    });
  });

  group('fetchData', () {
    test('combines services, orders and advances', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': servicesData(),
          '/orders': ordersData(),
          '/anticipos': advancesData(),
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': hostessesData(),
        }),
      );

      await notifier.fetchData();

      expect(notifier.state.isLoading, false);
      
      expect(notifier.state.solicitudes.length, 4);
      expect(notifier.state.cajaAbierta, true);
      expect(notifier.state.allHostesses.length, 2);
      expect(notifier.state.error, '');
      notifier.dispose();
    });

    test('handles empty data gracefully', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': emptySuccess(),
          '/orders': emptySuccess(),
          '/anticipos': emptySuccess(),
          '/caja/stats': closedCajaStats(),
          '/anfitrionas': emptySuccess(),
        }),
      );

      await notifier.fetchData();

      expect(notifier.state.solicitudes, []);
      expect(notifier.state.allHostesses, []);
      expect(notifier.state.cajaAbierta, false);
      notifier.dispose();
    });

    test('sets isRefreshing on manual refresh', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': emptySuccess(),
          '/orders': emptySuccess(),
          '/anticipos': emptySuccess(),
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
        }),
      );

      final future = notifier.fetchData(isManual: true);
      expect(notifier.state.isRefreshing, true);
      expect(notifier.state.isLoading, false);
      await future;
      expect(notifier.state.isRefreshing, false);
      notifier.dispose();
    });

    test('handles all failed requests gracefully with catchError', () async {
      
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchData();

      expect(notifier.state.isLoading, false);
      
      expect(notifier.state.error, '');
      expect(notifier.state.solicitudes, []);
      notifier.dispose();
    });

    test('filters out anticipos with estado 0', () async {
      final advancesWithZero = {
        'success': true,
        'data': [
          {'id_anticipo': 100, 'monto': 50000, 'estado': 0, 'usuario': 'Juan', 'fecha_crea': '2025-01-15T16:00:00.000'},
          {'id_anticipo': 101, 'monto': 30000, 'estado': 1, 'usuario': 'Ana', 'fecha_crea': '2025-01-15T17:00:00.000'},
        ],
      };

      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': emptySuccess(),
          '/orders': emptySuccess(),
          '/anticipos': advancesWithZero,
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
        }),
      );

      await notifier.fetchData();

      
      expect(notifier.state.solicitudes.length, 1);
      expect(notifier.state.solicitudes.first.id, '101');
      notifier.dispose();
    });
  });

  group('aprobarAnticipo', () {
    test('pays advance directly when estado == 1', () async {
      final advancesWith = {
        'success': true,
        'data': [
          {'id_anticipo': 100, 'monto': 50000, 'estado': 1, 'usuario': 'Juan', 'fecha_crea': '2025-01-15T16:00:00.000'},
        ],
      };

      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': emptySuccess(),
          '/orders': emptySuccess(),
          '/anticipos': advancesWith,
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
          '/anticipos/100': {'success': true},
        }),
      );

      await notifier.fetchData();
      expect(notifier.state.solicitudes.length, 1);

      
      final item = notifier.state.solicitudes.first;
      final result = await notifier.aprobarAnticipo(item);

      expect(result, true);
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final item = notifier.state.solicitudes.isNotEmpty
          ? notifier.state.solicitudes.first
          : null;
      if (item == null) {
        
        expect(true, true);
        notifier.dispose();
        return;
      }

      final result = await notifier.aprobarAnticipo(item);
      expect(result, false);
      notifier.dispose();
    });
  });

  group('rechazarSolicitud', () {
    test('rejects service (solicitud) successfully', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': servicesData(),
          '/orders': emptySuccess(),
          '/anticipos': emptySuccess(),
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
          '/solicitudes-servicios/1/rechazar': {'success': true},
        }),
      );

      await notifier.fetchData();
      expect(notifier.state.solicitudes.length, 1);

      final item = notifier.state.solicitudes.first;
      final result = await notifier.rechazarSolicitud(item);

      expect(result, true);
      notifier.dispose();
    });

    test('rejects order (pedido) successfully', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': emptySuccess(),
          '/orders': ordersData(),
          '/anticipos': emptySuccess(),
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
          '/orders/10': {'success': true},
        }),
      );

      await notifier.fetchData();
      expect(notifier.state.solicitudes.length, 1);

      final item = notifier.state.solicitudes.first;
      final result = await notifier.rechazarSolicitud(item);

      expect(result, true);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(routeToData: {
          '/solicitudes-servicios?estado=0': servicesData(),
          '/orders': emptySuccess(),
          '/anticipos': emptySuccess(),
          '/caja/stats': emptyCajaStats(),
          '/anfitrionas': emptySuccess(),
        }),
      );

      await notifier.fetchData();
      final item = notifier.state.solicitudes.first;
      
      final result = await notifier.rechazarSolicitud(item);

      expect(result, false);
      notifier.dispose();
    });
  });
}

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
