import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/data/servicios_notifier.dart';
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


ServiciosListNotifier _buildNotifier(Dio dio) {
  return ServiciosListNotifier(ApiClient(dio: dio));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ServiciosListNotifier', () {
    test('initial state has isLoading = true', () {
      final notifier = _buildNotifier(Dio());
      expect(notifier.state.isLoading, true);
      expect(notifier.state.error, '');
      expect(notifier.state.servicios, isEmpty);
      expect(notifier.state.activeServicios, isEmpty);
    });

    group('fetchServicios', () {
      test('loads servicios from API', () async {
        final mockData = [
          {
            'id_servicio': 1,
            'room_name': 'VIP-1',
            'estado': 0,
            'fecha_inicio': '2026-06-17T10:00:00.000',
            'anfitriona_nombre': 'Ana',
            'cliente_nombre': 'Juan',
          },
          {
            'id_servicio': 2,
            'room_name': 'Suite-2',
            'estado': 0,
            'fecha_inicio': '2026-06-17T11:00:00.000',
            'anfitriona_nombre': 'Bety',
            'cliente_nombre': 'Pedro',
          },
        ];

        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': true, 'data': mockData}),
        );

        await notifier.fetchServicios();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.servicios.length, 2);
        expect(notifier.state.activeServicios.length, 2);
        expect(notifier.state.error, '');
      });

      test('sets isRefreshing when manual refresh', () async {
        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': true, 'data': []}),
        );

        await notifier.fetchServicios(isManual: true);

        expect(notifier.state.isRefreshing, false);
        expect(notifier.state.isLoading, false);
      });

      test('filters out non-active servicios', () async {
        final mockData = [
          {'id_servicio': 1, 'room_name': 'A', 'estado': 0},
          {'id_servicio': 2, 'room_name': 'B', 'estado': 1},
          {'id_servicio': 3, 'room_name': 'C', 'estado': 0},
        ];

        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': true, 'data': mockData}),
        );

        await notifier.fetchServicios();

        expect(notifier.state.activeServicios.length, 2);
        expect(
          notifier.state.activeServicios.map((s) => s['id_servicio']),
          containsAll([1, 3]),
        );
      });

      test('sets error on API failure (success: false)', () async {
        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': false}),
        );

        await notifier.fetchServicios();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotEmpty);
        expect(notifier.state.servicios, isEmpty);
      });

      test('sets error on DioException', () async {
        final failingDio = Dio();
        failingDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  message: 'Network error',
                ),
              );
            },
          ),
        );

        final notifier = ServiciosListNotifier(ApiClient(dio: failingDio));
        await notifier.fetchServicios();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNotEmpty);
      });
    });

    group('finalizarServicio', () {
      test('removes servicio from list on success', () async {
        final mockData = [
          {'id_servicio': 1, 'room_name': 'A', 'estado': 0},
          {'id_servicio': 2, 'room_name': 'B', 'estado': 0},
        ];

        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': true}),
        );
        
        notifier.state = notifier.state.copyWith(servicios: mockData);
        expect(notifier.state.servicios.length, 2);

        
        final result = await notifier.finalizarServicio(1);
        expect(result, true);
        expect(notifier.state.servicios.length, 1);
        expect(notifier.state.servicios.first['id_servicio'], 2);
      });

      test('returns false on API error', () async {
        final notifier = _buildNotifier(
          _dioWithResponse(data: {'success': false, 'message': 'Not found'}),
        );
        notifier.state = notifier.state.copyWith(servicios: [
          {'id_servicio': 1, 'room_name': 'A', 'estado': 0},
        ]);

        final result = await notifier.finalizarServicio(1);
        expect(result, false);
        expect(notifier.state.servicios.length, 1); 
        expect(notifier.state.error, isNotEmpty);
      });

      test('returns false on DioException', () async {
        final failingDio = Dio();
        failingDio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(requestOptions: options, message: 'Timeout'),
              );
            },
          ),
        );

        final notifier = ServiciosListNotifier(ApiClient(dio: failingDio));
        notifier.state = notifier.state.copyWith(servicios: [
          {'id_servicio': 1, 'room_name': 'A', 'estado': 0},
        ]);

        final result = await notifier.finalizarServicio(1);
        expect(result, false);
        expect(notifier.state.error, isNotEmpty);
      });
    });

    group('activeServicios', () {
      test('returns only status 0 items', () {
        final state = ServiciosListState(servicios: [
          {'id_servicio': 1, 'estado': 0},
          {'id_servicio': 2, 'estado': 1},
          {'id_servicio': 3, 'estado': 2},
          {'id_servicio': 4, 'estado': 0},
        ]);

        expect(state.activeServicios.length, 2);
      });

      test('handles missing estado field (defaults to 0 = active)', () {
        final state = ServiciosListState(servicios: [
          {'id_servicio': 1},
          {'id_servicio': 2, 'estado': 1},
        ]);

        
        expect(state.activeServicios.length, 1);
        expect(state.activeServicios.first['id_servicio'], 1);
      });
    });
  });
}
