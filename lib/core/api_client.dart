import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'offline/offline_interceptor.dart';
import 'offline/offline_sync_manager.dart';

/// Default cache options for non‑critical GET requests.
///
/// Responses are cached for 5 minutes and stored on disk via Hive.
/// [store] is set at construction time via [copyWith].
CacheOptions _defaultCacheOptions(CacheStore store) => CacheOptions(
  store: store,
  policy: CachePolicy.forceCache,
  maxStale: Duration(minutes: 5),
  priority: CachePriority.normal,
);

class ApiClient {
  static const String baseDomain = 'https://dashboard.xn--lasmuecasderamon-bub.com';
  static const String baseUrl = '$baseDomain/api';
  final Dio _dio;
  final _secureStorage = const FlutterSecureStorage();

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
    // ── Auth interceptor ──────────────────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          return handler.next(e);
        },
      ),
    );

    // ── Cache interceptor ─────────────────────────────────────────────
    if (cacheStore != null) {
      _dio.interceptors.add(
        DioCacheInterceptor(
          options: _defaultCacheOptions(cacheStore),
        ),
      );
    }

    // ── Offline interceptor (last = catches errors first on response) ─
    if (offlineSync != null) {
      _dio.interceptors.add(OfflineInterceptor(offlineSync));
    }
  }

  Dio get dio => _dio;

  /// Helper: create a [CacheStore] backed by Hive on the app's documents dir.
  static Future<HiveCacheStore> createDefaultStore() async {
    final dir = await getApplicationDocumentsDirectory();
    return HiveCacheStore(dir.path, hiveBoxName: 'dio_cache');
  }
}
