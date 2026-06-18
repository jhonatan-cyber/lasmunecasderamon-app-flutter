import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/data/cuentas_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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

CuentasListNotifier _buildNotifier(Dio dio) {
  return CuentasListNotifier(ApiClient(dio: dio));
}

// ─────────────────────────────────────────────────────────────────────────────
// Test data
// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> successCuentas() => {
      'success': true,
      'data': [
        {
          'id_cuenta': 1,
          'id': 1,
          'codigo': 'C-001',
          'estado': '0',
          'total': 45000,
          'cliente_nombre': 'Juan Pérez',
          'room_name': '101',
          'anfitriona_nombre': 'María',
          'garzon_nombre': 'Pedro',
          'fecha_apertura': '2025-01-15T14:00:00.000',
        },
        {
          'id_cuenta': 2,
          'id': 2,
          'codigo': 'C-002',
          'estado': '1',
          'total': 32000,
          'cliente_nombre': 'Ana López',
          'room_name': 'VIP',
          'anfitriona_nombre': 'Luisa',
          'garzon_nombre': 'Carlos',
          'fecha_apertura': '2025-01-15T15:30:00.000',
        },
      ],
    };

Map<String, dynamic> successSummary() => {
      'success': true,
      'data': {
        'total_estimado': 77000,
        'mesas_ocupadas': 2,
      },
    };

Map<String, dynamic> emptyCuentas() => {'success': true, 'data': []};

Map<String, dynamic> emptySummary() => {'success': true, 'data': {}};

Map<String, dynamic> failResponse() => {
      'success': false,
      'message': 'Error de servidor',
    };

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

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
      expect(notifier.state.cuentas, []);
      expect(notifier.state.resumen, {});
      notifier.dispose();
    });
  });

  group('fetchData', () {
    test('sets isLoading and clears error before fetch', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas?limit=50': successCuentas(),
            '/cuentas?tipo=resumen': successSummary(),
          },
        ),
      );

      final future = notifier.fetchData();
      expect(notifier.state.isLoading, true);
      expect(notifier.state.error, '');
      await future;
      notifier.dispose();
    });

    test('populates cuentas and resumen on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas?limit=50': successCuentas(),
            '/cuentas?tipo=resumen': successSummary(),
          },
        ),
      );

      await notifier.fetchData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.cuentas.length, 2);
      expect(notifier.state.resumen['total_estimado'], 77000);
      expect(notifier.state.error, '');
      notifier.dispose();
    });

    test('sets isRefreshing on manual refresh', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas?limit=50': emptyCuentas(),
            '/cuentas?tipo=resumen': emptySummary(),
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
            '/cuentas?limit=50': emptyCuentas(),
            '/cuentas?tipo=resumen': emptySummary(),
          },
        ),
      );

      await notifier.fetchData();

      expect(notifier.state.cuentas, []);
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
  });

  group('detenerTiempo', () {
    test('returns true and re-fetches on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas/1/stop': {'success': true},
            '/cuentas?limit=50': emptyCuentas(),
            '/cuentas?tipo=resumen': emptySummary(),
          },
        ),
      );

      final result = await notifier.detenerTiempo(1);

      expect(result, true);
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final result = await notifier.detenerTiempo(1);

      expect(result, false);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.detenerTiempo(1);

      expect(result, false);
      notifier.dispose();
    });
  });

  group('cobrarCuenta', () {
    test('returns true and removes cuenta locally on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas?limit=50': successCuentas(),
            '/cuentas?tipo=resumen': successSummary(),
            '/cuentas/1/cobrar': {'success': true},
          },
        ),
      );
      await notifier.fetchData();
      expect(notifier.state.cuentas.length, 2);

      final result = await notifier.cobrarCuenta(
        idCuenta: 1,
        metodoPago: 'efectivo',
        propina: 4500,
        cargoTarjeta: 0,
        usuarioId: 1,
      );

      expect(result, true);
      // Cuenta should be removed from local list
      expect(notifier.state.cuentas.length, 1);
      expect(
        notifier.state.cuentas.every((c) =>
            c['id_cuenta'] != 1 && c['id'] != 1),
        true,
      );
      notifier.dispose();
    });

    test('returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final result = await notifier.cobrarCuenta(
        idCuenta: 1,
        metodoPago: 'efectivo',
        propina: 0,
        cargoTarjeta: 0,
        usuarioId: 1,
      );

      expect(result, false);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.cobrarCuenta(
        idCuenta: 1,
        metodoPago: 'tarjeta',
        propina: 0,
        cargoTarjeta: 100,
        usuarioId: 1,
      );

      expect(result, false);
      notifier.dispose();
    });
  });

  group('anularCuenta', () {
    test('returns true and removes cuenta locally on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/cuentas?limit=50': successCuentas(),
            '/cuentas?tipo=resumen': successSummary(),
            '/cuentas/anulacion': {'success': true},
          },
        ),
      );
      await notifier.fetchData();
      expect(notifier.state.cuentas.length, 2);

      final result = await notifier.anularCuenta(1, 'Cliente se retiró');

      expect(result, true);
      expect(notifier.state.cuentas.length, 1);
      notifier.dispose();
    });

    test('sets error and returns false on API failure', () async {
      final notifier = _buildNotifier(
        _dioWithResponse(data: failResponse()),
      );

      final result = await notifier.anularCuenta(1, 'Motivo');

      expect(result, false);
      expect(notifier.state.error, isNotEmpty);
      notifier.dispose();
    });

    test('returns false on DioException', () async {
      final notifier = _buildNotifier(_dioWithError());

      final result = await notifier.anularCuenta(1, 'Motivo');

      expect(result, false);
      notifier.dispose();
    });
  });
}
