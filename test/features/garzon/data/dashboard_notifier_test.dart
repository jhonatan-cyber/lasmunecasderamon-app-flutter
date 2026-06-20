import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/data/dashboard_notifier.dart';
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

GarzonDashboardNotifier _buildNotifier(Dio dio) {
  return GarzonDashboardNotifier(ApiClient(dio: dio));
}





Map<String, dynamic> successEvents() => {
      'success': true,
      'data': [
        {
          'id': 1,
          'type': 'propina',
          'amount': 5000,
          'date': DateTime.now().toIso8601String(),
        },
        {
          'id': 2,
          'type': 'comision',
          'amount': 10000,
          'date': DateTime.now().toIso8601String(),
        },
      ],
    };

Map<String, dynamic> successStats() => {
      'success': true,
      'data': {
        'totalEarnings': 15000,
        'svcCount': 5,
      },
    };

Map<String, dynamic> successMeStats() => {
      'success': true,
      'data': {
        'stats': {
          'montoAnticipoMaximo': 200000,
        },
      },
    };

Map<String, dynamic> emptyEvents() => {
      'success': true,
      'data': [],
    };

Map<String, dynamic> emptyStats() => {
      'success': true,
      'data': {},
    };

Map<String, dynamic> failResponse() => {
      'success': false,
      'message': 'Server error',
    };

Map<String, dynamic> meStatsWithoutNestedStats() => {
      'success': true,
      'data': {
        'someOtherField': 'value',
      },
    };

const List<Map<String, dynamic>> rawEventsList = [
  {
    'id': 1,
    'type': 'propina',
    'amount': 3000,
    'date': '2025-01-15T14:30:00.000',
  },
];





void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
  });

  group('initial state', () {
    test('has correct defaults', () {
      final notifier = _buildNotifier(Dio());

      expect(notifier.state.isLoading, false);
      expect(notifier.state.isRefreshing, false);
      expect(notifier.state.error, '');
      expect(notifier.state.totalEarnings, 0.0);
      expect(notifier.state.salesWithTips, 0);
      expect(notifier.state.payoutTotal, 0.0);
      expect(notifier.state.events, isEmpty);
      expect(notifier.state.eventDays, isEmpty);

      notifier.dispose();
    });
  });

  group('fetchDashboardData', () {
    test('sets isLoading before fetch and clears after', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': successEvents(),
            '/events/stats': successStats(),
            '/users/me/stats': successMeStats(),
          },
        ),
      );

      expect(notifier.state.isLoading, false);

      final future = notifier.fetchDashboardData();
      expect(notifier.state.isLoading, true);
      expect(notifier.state.error, '');
      await future;

      expect(notifier.state.isLoading, false);

      notifier.dispose();
    });

    test('populates all fields on success', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': successEvents(),
            '/events/stats': successStats(),
            '/users/me/stats': successMeStats(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, '');
      expect(notifier.state.totalEarnings, 15000);
      expect(notifier.state.salesWithTips, 5);
      expect(notifier.state.payoutTotal, 200000);
      expect(notifier.state.events.length, 2);
      
      expect(notifier.state.eventDays.length, 1);
      expect(notifier.state.eventDays, contains(DateTime.now().day));

      notifier.dispose();
    });

    test('sets isRefreshing on manual refresh', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': emptyEvents(),
            '/events/stats': emptyStats(),
            '/users/me/stats': emptyStats(),
          },
        ),
      );

      final future = notifier.fetchDashboardData(isManual: true);
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
            '/events/user': emptyEvents(),
            '/events/stats': emptyStats(),
            '/users/me/stats': emptyStats(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      expect(notifier.state.totalEarnings, 0);
      expect(notifier.state.salesWithTips, 0);
      expect(notifier.state.payoutTotal, 0);
      expect(notifier.state.events, isEmpty);
      expect(notifier.state.eventDays, isEmpty);

      notifier.dispose();
    });

    test('parses events when API returns raw list instead of wrapped format',
        () async {
      
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/events/user')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: rawEventsList,
                ),
              );
            } else if (options.path.contains('/events/stats')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: emptyStats(),
                ),
              );
            } else if (options.path.contains('/users/me/stats')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: emptyStats(),
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
      final notifier = _buildNotifier(dio);

      await notifier.fetchDashboardData();

      expect(notifier.state.events.length, 1);
      expect(notifier.state.events[0]['type'], 'propina');

      notifier.dispose();
    });

    test('returns defaults when API responds with success=false',
        () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': failResponse(),
            '/events/stats': failResponse(),
            '/users/me/stats': failResponse(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      
      expect(notifier.state.totalEarnings, 0);
      expect(notifier.state.salesWithTips, 0);
      expect(notifier.state.payoutTotal, 0);
      expect(notifier.state.events, isEmpty);

      notifier.dispose();
    });

    test('handles stats with flat data format (no success wrapper)', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': emptyEvents(),
            '/events/stats': {'totalEarnings': 25000, 'svcCount': 10},
            '/users/me/stats': {
              'stats': {'montoAnticipoMaximo': 50000},
            },
          },
        ),
      );

      await notifier.fetchDashboardData();

      expect(notifier.state.totalEarnings, 25000);
      expect(notifier.state.salesWithTips, 10);
      expect(notifier.state.payoutTotal, 50000);

      notifier.dispose();
    });

    test('handles success=false response without crashing and returns defaults',
        () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': failResponse(),
            '/events/stats': failResponse(),
            '/users/me/stats': failResponse(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      
      expect(notifier.state.totalEarnings, 0);
      expect(notifier.state.salesWithTips, 0);
      expect(notifier.state.payoutTotal, 0);
      expect(notifier.state.events, isEmpty);

      notifier.dispose();
    });

    test('handles null responses gracefully (individual endpoint failures)',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/events/user')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: successEvents(),
                ),
              );
            } else {
              
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Server error',
                ),
              );
            }
          },
        ),
      );
      final notifier = _buildNotifier(dio);

      await notifier.fetchDashboardData();

      
      expect(notifier.state.totalEarnings, 0);
      expect(notifier.state.salesWithTips, 0);
      expect(notifier.state.payoutTotal, 0);
      expect(notifier.state.events.length, 2);

      notifier.dispose();
    });

    test('handles meStats without nested stats map', () async {
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': emptyEvents(),
            '/events/stats': emptyStats(),
            '/users/me/stats': meStatsWithoutNestedStats(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      
      expect(notifier.state.payoutTotal, 0);

      notifier.dispose();
    });

    test('returns defaults when all endpoints silently fail', () async {
      
      
      final notifier = _buildNotifier(_dioWithError());

      await notifier.fetchDashboardData();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.isRefreshing, false);
      expect(notifier.state.error, ''); 
      expect(notifier.state.totalEarnings, 0);
      expect(notifier.state.events, isEmpty);

      notifier.dispose();
    });

    test('builds eventDays only for current month', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      final nextMonth = DateTime(now.year, now.month + 1, 10);

      final mixedEvents = {
        'success': true,
        'data': [
          {
            'id': 1,
            'type': 'propina',
            'amount': 5000,
            'date': now.toIso8601String(),
          },
          {
            'id': 2,
            'type': 'comision',
            'amount': 3000,
            'date': lastMonth.toIso8601String(),
          },
          {
            'id': 3,
            'type': 'propina',
            'amount': 2000,
            'date': nextMonth.toIso8601String(),
          },
        ],
      };

      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': mixedEvents,
            '/events/stats': emptyStats(),
            '/users/me/stats': emptyStats(),
          },
        ),
      );

      await notifier.fetchDashboardData();

      
      expect(notifier.state.eventDays.length, 1);
      expect(notifier.state.eventDays, contains(now.day));

      notifier.dispose();
    });

    test('clears error before new fetch on a retry notifier', () async {
      
      
      final notifier = _buildNotifier(
        _dioWithConditionalResponse(
          routeToData: {
            '/events/user': failResponse(),
            '/events/stats': failResponse(),
            '/users/me/stats': failResponse(),
          },
        ),
      );

      
      await notifier.fetchDashboardData();
      expect(notifier.state.error, '');

      
      final successDio = _dioWithConditionalResponse(
        routeToData: {
          '/events/user': successEvents(),
          '/events/stats': successStats(),
          '/users/me/stats': successMeStats(),
        },
      );
      final notifier2 = _buildNotifier(successDio);

      await notifier2.fetchDashboardData();

      expect(notifier2.state.error, '');
      expect(notifier2.state.totalEarnings, 15000);

      notifier2.dispose();
    });
  });
}





class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<String?> read(
      {required String key, Map<String, String>? options}) async {
    return _store[key];
  }

  @override
  Future<void> write(
      {required String key,
      required String value,
      Map<String, String>? options}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(
      {required String key, Map<String, String>? options}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll(
      {Map<String, String>? options}) async {
    return Map.from(_store);
  }

  @override
  Future<bool> containsKey(
      {required String key, Map<String, String>? options}) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> deleteAll({Map<String, String>? options}) async {
    _store.clear();
  }
}
