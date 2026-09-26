import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';

/// Secure storage en memoria (mismo patrón que `auth_notifier_test.dart`).
class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<String?> read({required String key, Map<String, String>? options}) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    Map<String, String>? options,
  }) async =>
      _store[key] = value;

  @override
  Future<void> delete({required String key, Map<String, String>? options}) async =>
      _store.remove(key);

  @override
  Future<Map<String, String>> readAll({Map<String, String>? options}) async =>
      Map.from(_store);

  @override
  Future<bool> containsKey({required String key, Map<String, String>? options}) async =>
      _store.containsKey(key);

  @override
  Future<void> deleteAll({Map<String, String>? options}) async => _store.clear();
}

/// Store de caché en memoria: registra las claves guardadas y cuántas veces
/// se ha limpiado.
class FakeCacheStore implements CacheStore {
  final entries = <String, CacheResponse>{};
  int cleanCalls = 0;

  @override
  Future<bool> exists(String key) async => entries.containsKey(key);

  @override
  Future<CacheResponse?> get(String key) async => entries[key];

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async =>
      entries.entries
          .where((e) => pathPattern.hasMatch(e.key))
          .map((e) => e.value)
          .toList();

  @override
  Future<void> set(CacheResponse response) async {
    entries[response.key] = response;
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    entries.remove(key);
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    entries.removeWhere((key, _) => pathPattern.hasMatch(key));
  }

  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    entries.clear();
    cleanCalls++;
  }

  @override
  Future<void> close() async {}

  @override
  bool pathExists(
    String url,
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) =>
      pathPattern.hasMatch(url) && entries.isNotEmpty;
}

/// Entrada de caché de relleno para simular respuestas ya cacheadas.
CacheResponse _cachedEntry(String key) => CacheResponse(
      cacheControl: CacheControl(),
      content: null,
      date: null,
      eTag: null,
      expires: null,
      headers: null,
      key: key,
      lastModified: null,
      maxStale: null,
      priority: CachePriority.normal,
      requestDate: DateTime.now(),
      responseDate: DateTime.now(),
      url: 'http://cache.test/$key',
    );

/// ApiClient + «red» simulada: un interceptor añadido DESPUÉS del cliente
/// resuelve toda petición con JSON y cuenta las que llegan a red.
({ApiClient client, FakeCacheStore store, Dio dio, int Function() networkCalls})
    _buildClient() {
  final store = FakeCacheStore();
  final dio = Dio(BaseOptions(baseUrl: 'http://cache.test'));
  final client = ApiClient(dio: dio, cacheStore: store);
  var networkCalls = 0;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        networkCalls++;
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {'ok': true, 'path': options.path},
          ),
          true, // que el DioCacheInterceptor guarde la respuesta (onResponse)
        );
      },
    ),
  );
  return (
    client: client,
    store: store,
    dio: dio,
    networkCalls: () => networkCalls,
  );
}

/// AuthNotifier sobre cliente con caché fake; el «red» responde login y
/// cualquier otro endpoint.
({AuthNotifier notifier, ApiClient client, FakeCacheStore store})
    _buildAuth() {
  final store = FakeCacheStore();
  final dio = Dio(BaseOptions(baseUrl: 'http://cache.test'));
  final client = ApiClient(dio: dio, cacheStore: store);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final dynamic data = options.path.endsWith('/auth/login')
            ? {
                'token': 'tok-nuevo',
                'user': {
                  'id': '1',
                  'email': 'a@b.c',
                  'nombre': 'U',
                  'role': 'garzon',
                },
              }
            : {'success': true};
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
          true,
        );
      },
    ),
  );
  final notifier = AuthNotifier(client);
  return (notifier: notifier, client: client, store: store);
}

void main() {
  late FakeSecureStorage storage;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient: caché HTTP aislada por sesión', () {
    test('la clave de caché incluye el token: dos usuarios no comparten entrada',
        () async {
      final f = _buildClient();

      // Sesión A llena la caché.
      await storage.write(key: 'auth_token', value: 'tok-user-a');
      await f.dio.get('/tips');
      expect(f.networkCalls(), 1);
      expect(f.store.entries, hasLength(1));
      expect(f.store.entries.keys.single, contains('#'),
          reason: 'la clave debe llevar el aislamiento por token');

      // Misma sesión: forceCache sirve sin volver a red.
      await f.dio.get('/tips');
      expect(f.networkCalls(), 1, reason: 'forceCache sirve desde caché');

      // Sesión B (otro usuario), misma URI: clave distinta → red.
      await storage.write(key: 'auth_token', value: 'tok-user-b');
      final resB = await f.dio.get('/tips');
      expect(f.networkCalls(), 2, reason: 'otro token no lee la caché de A');
      expect(resB.statusCode, 200);
      expect(f.store.entries, hasLength(2));
      expect(f.store.entries.keys.toSet(), hasLength(2),
          reason: 'las claves de A y B deben ser distintas');

      // La entrada de A sigue intacta: volver a A golpea caché sin red.
      await storage.write(key: 'auth_token', value: 'tok-user-a');
      await f.dio.get('/tips');
      expect(f.networkCalls(), 2,
          reason: 'la sesión A conserva su propia entrada');
    });

    test('clearCache vacía la store; sin store no lanza', () async {
      final f = _buildClient();
      await storage.write(key: 'auth_token', value: 'tok-user-a');
      await f.dio.get('/tips');
      expect(f.store.entries, hasLength(1));

      await f.client.clearCache();
      expect(f.store.entries, isEmpty, reason: 'login/logout limpian la caché');
      expect(f.store.cleanCalls, 1);

      // ApiClient sin store (arranque antes de resolver el provider).
      final bare = ApiClient(dio: Dio(BaseOptions(baseUrl: 'http://cache.test')));
      await bare.clearCache(); // no debe lanzar
    });
  });

  group('AuthNotifier: la caché se limpia en cada cambio de sesión', () {
    test('login descarta respuestas de la cuenta anterior', () async {
      final f = _buildAuth();
      await Future<void>.delayed(Duration.zero);
      // Entradas «de la cuenta anterior» de una corrida previa.
      f.store.entries['uri-anterior'] = _cachedEntry('uri-anterior');

      final twoStep = await f.notifier.login(username: 'u', password: 'p');
      expect(twoStep, isFalse);
      expect(f.notifier.state.user, isNotNull);
      expect(f.store.entries, isEmpty,
          reason: 'el login no debe heredar la caché del usuario previo');
      expect(f.store.cleanCalls, 1);
    });

    test('logout limpia la caché de la sesión cerrada', () async {
      final f = _buildAuth();
      await Future<void>.delayed(Duration.zero);
      await f.notifier.login(username: 'u', password: 'p');

      f.store.entries['uri-sesion'] = _cachedEntry('uri-sesion');
      final before = f.store.cleanCalls;
      await f.notifier.logout();
      expect(f.store.entries, isEmpty, reason: 'logout limpia la caché');
      expect(f.store.cleanCalls, before + 1);
    });

    test('sesión vencida (onUnauthorized) limpia la caché', () async {
      final f = _buildAuth();
      await Future<void>.delayed(Duration.zero);
      await f.notifier.login(username: 'u', password: 'p');
      expect(f.client.onUnauthorized, isNotNull,
          reason: 'AuthNotifier engancha onUnauthorized');

      f.store.entries['uri-401'] = _cachedEntry('uri-401');
      final before = f.store.cleanCalls;
      f.client.onUnauthorized!();
      await Future<void>.delayed(Duration.zero);
      expect(f.store.entries, isEmpty,
          reason: 'la sesión vencida no deja respuestas cacheadas');
      expect(f.store.cleanCalls, before + 1);
    });
  });
}
