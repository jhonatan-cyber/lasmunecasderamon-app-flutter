import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'offline/offline_interceptor.dart';
import 'offline/offline_sync_manager.dart';





CacheOptions _defaultCacheOptions(CacheStore store) => CacheOptions(
  store: store,
  policy: CachePolicy.forceCache,
  maxStale: Duration(minutes: 5),
  priority: CachePriority.normal,
);

class ApiClient {
  /// Dominio del backend. El default es el entorno desplegado; para correr
  /// contra un backend local se pasa `--dart-define=API_BASE_DOMAIN=http://localhost:3000`.
  static const String baseDomain = String.fromEnvironment(
    'API_BASE_DOMAIN',
    defaultValue: 'https://dashboard.xn--lasmuecasderamon-bub.com',
  );
  static const String baseUrl = '$baseDomain/api';
  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

  /// Invocado cuando el refresh token falla: la sesión ya no es válida y hay que
  /// cerrarla (equivalente a `notifyUnauthorized` de la app Expo).
  void Function()? onUnauthorized;

  /// Mutex para que solo haya un refresh en vuelo a la vez.
  Future<bool>? _refreshInFlight;

  /// Rutas donde un 401 es una respuesta esperada y no implica sesión vencida.
  static bool _isAuthExempt(String path) =>
      path.contains('/auth/refresh') ||
      path.contains('/auth/login') ||
      path.contains('/auth/logout');

  ApiClient({Dio? dio, CacheStore? cacheStore, OfflineSyncManager? offlineSync})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final expired =
              e.response?.statusCode == 401 &&
              e.requestOptions.extra['token_refreshed'] != true &&
              !_isAuthExempt(e.requestOptions.path);

          if (expired) {
            final refreshed = await refreshAccessToken();
            if (refreshed) {
              // Token nuevo: reintenta la misma petición una sola vez.
              e.requestOptions.extra['token_refreshed'] = true;
              try {
                final resp = await _dio.fetch<dynamic>(e.requestOptions);
                return handler.resolve(resp);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
            // Ni siquiera el refresh sirvió: la sesión murió.
            onUnauthorized?.call();
          }
          return handler.next(e);
        },
      ),
    );

    
    if (cacheStore != null) {
      _dio.interceptors.add(
        DioCacheInterceptor(
          options: _defaultCacheOptions(cacheStore),
        ),
      );
    }

    
    if (offlineSync != null) {
      _dio.interceptors.add(OfflineInterceptor(offlineSync));
    }
  }

  Dio get dio => _dio;

  /// Renueva el access token con el refresh token almacenado (rotación incluida).
  /// Devuelve false si no hay refresh token o si el servidor lo rechaza.
  Future<bool> refreshAccessToken() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    try {
      final stored = await _secureStorage.read(key: 'refresh_token');
      if (stored == null || stored.isEmpty) return false;

      final client = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final response = await client.post(
        '/auth/refresh',
        options: Options(headers: {'x-refresh-token': stored}),
      );
      final data = response.data;

      if (data is Map && data['success'] == true && data['token'] is String) {
        await _secureStorage.write(key: 'auth_token', value: data['token'] as String);
        final rotated = data['refreshToken'];
        if (rotated is String && rotated.isNotEmpty) {
          await _secureStorage.write(key: 'refresh_token', value: rotated);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  
  static Future<HiveCacheStore> createDefaultStore() async {
    final dir = await getApplicationDocumentsDirectory();
    return HiveCacheStore(dir.path, hiveBoxName: 'dio_cache');
  }
}
