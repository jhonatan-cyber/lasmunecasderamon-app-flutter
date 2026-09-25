import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Test de contrato auto-verificativo: llamadas de la app Flutter ↔ rutas
/// REALES del dashboard. Porte de `tests/unit/services/api-contract.test.ts`
/// de la app Expo al runner de Flutter.
///
/// En vez de mockear Dio (auto-verificativo y ciego a cambios del backend),
/// este test:
///   1. escanea los fuentes de `lib/` y extrae cada endpoint que la app llama
///      vía `<cliente>.get/post/put/patch/delete('...')` (receptores `dio`,
///      `_dio`, `client`… incluidas llamadas encadenadas en varias líneas) y
///      las que pasan un identificador (`dio.get(_endpoint)`),
///   2. lee las rutas reales del dashboard (route.ts bajo app/api/),
///   3. falla si la app llama a un endpoint que no existe (o si la ruta del
///      dashboard no soporta ninguno de los métodos HTTP usados).
///
/// Requiere el repo del dashboard como hermano de la app.
void main() {
  final cwd = Directory.current.path;
  final candidates = <String>[
    '$cwd/../lasmunecasderamon-dashboard',
    '$cwd/../../lasmunecasderamon-dashboard',
    '$cwd/lasmunecasderamon-dashboard',
  ];
  final dashboardRoot =
      candidates.where((c) => Directory('$c/app/api').existsSync()).firstOrNull;
  final apiDir = dashboardRoot == null ? null : Directory('$dashboardRoot/app/api');

  group('API contract: llamadas HTTP de la app Flutter ↔ rutas reales del dashboard', () {
    final appCalls = apiDir == null ? <AppCall>[] : extractAppCalls();
    final dashRoutes = apiDir == null ? <DashRoute>[] : readDashboardRoutes(apiDir);
    final patterns = [
      for (final r in dashRoutes) PatternRoute(route: r, re: routeToRegex(r.path)),
    ];

    test('el walker encontró rutas en ambos lados (no falló en silencio)', () {
      expect(
        apiDir,
        isNotNull,
        reason: 'No se encontró el repo del dashboard como hermano de la app. '
            'Busqué en: ${candidates.join(' | ')}',
      );
      expect(
        dashRoutes.length,
        greaterThan(100),
        reason: 'dashboard: se esperaban >100 rutas app/api/**/route.ts',
      );
      expect(
        appCalls.length,
        greaterThan(100),
        reason: 'app: se esperaban >100 llamadas HTTP con endpoint en lib/ '
            '(literales + identificadores); el walker extrajo ${appCalls.length}',
      );
    });

    test('cada endpoint llamado por la app existe en el dashboard', () {
      final faltantes = appCalls
          .where((c) => !patterns.any((p) => p.re.hasMatch('/api${c.path}')))
          .map((c) => '${c.path} (${c.file})')
          .toSet()
          .toList()
        ..sort();
      expect(
        faltantes,
        isEmpty,
        reason: 'Endpoints de la app sin ruta en el dashboard: '
            '${faltantes.join(', ')}',
      );
    });

    test('el método HTTP que la app envía existe en la ruta del dashboard', () {
      final errores = <String>{};
      for (final call in appCalls) {
        final hits =
            patterns.where((p) => p.re.hasMatch('/api${call.path}')).toList();
        if (hits.isEmpty) continue; // lo cubre el test anterior
        if (!hits.any(
            (h) => call.methods.any((m) => h.route.methods.contains(m)))) {
          errores.add(
            '${call.methods.join('/')} /api${call.path} (${call.file}) — la '
            'ruta existe solo con: '
            '${hits.map((h) => '${h.route.methods.join('/')} (${h.route.path})').join(', ')}',
          );
        }
      }
      expect(errores, isEmpty, reason: errores.join(' | '));
    });
  });
}

class AppCall {
  AppCall({required this.path, required this.methods, required this.file});

  /// Ruta normalizada (`/cuentas/<dyn>/stop`), sin query string.
  final String path;

  /// Métodos HTTP que la app envía a esta ruta. Siempre de tamaño 1 para
  /// llamadas con literal; para llamadas por identificador puede traer varios
  /// cuando la definición es un ternario (`cond ? a : b`) y el emparejamiento
  /// método↔rama no es estáticamente resoluble — en ese caso basta con que la
  /// ruta soporte al menos uno.
  final Set<String> methods;

  /// Ruta del fichero fuente, relativa a `lib/`.
  final String file;
}

class DashRoute {
  DashRoute({required this.path, required this.methods});

  final String path;
  final List<String> methods;
}

class PatternRoute {
  PatternRoute({required this.route, required this.re});

  final DashRoute route;
  final RegExp re;
}

// ── Extracción de llamadas HTTP en lib/ ─────────────────────────────────────

/// Métodos HTTP expuestos por Dio y relevantes para el contrato.
const _httpVerbs = ['get', 'post', 'put', 'patch', 'delete'];

/// Receptores que son (o contienen) un cliente HTTP de la app. Cubre
/// `dio.get(...)`, `_dio.get(...)`, `client.post(...)` (Dio local de
/// api_client) y la forma encadenada `_apiClient.dio\n    .get('...')`.
const _httpReceivers = {
  'dio',
  '_dio',
  'client',
  '_client',
  'api',
  '_api',
  'dioClient',
  '_dioClient',
  'apiClient',
  '_apiClient',
  'http',
};

/// `<receptor>.get('/endpoint', ...)` — la primera cadena tras el paréntesis
/// es el endpoint; el método HTTP lo da el verbo. `\s*` cruza líneas, así que
/// captura también las llamadas con el literal en la línea siguiente.
final _dioCallRe = RegExp(
  r"(\w+)\s*\.\s*(get|post|put|patch|delete)\(\s*'(/[^']*)'",
);

/// `<receptor>.get(_endpoint, ...)` / `.patch(endpoint, ...)` — primer
/// argumento identificador; se resuelve contra las definiciones del archivo.
final _dioIdentCallRe = RegExp(
  r'(\w+)\s*\.\s*(get|post|put|patch|delete)\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*[,)]',
);

/// Literales `'...'` con forma de endpoint dentro de una expresión.
final _endpointLitRe = RegExp(r"'(/[^']*)'");

/// Normaliza el literal del endpoint a una ruta limpia:
///  - interpolación en posición de segmento (`/users/$id`) → comodín `<dyn>`
///  - interpolación dentro del último segmento (`/clients?id=$x`) → query fuera
String? normalizeEndpoint(String raw) {
  // Interpolación `$var` (string Dart sin llaves): `/users/$userId/detail`.
  var out = raw.replaceAllMapped(RegExp(r'/\$[A-Za-z0-9_]+'), (_) => '/<dyn>');
  // Interpolación `${expr}`: el segmento completo pasa a comodín.
  out = out.replaceAllMapped(RegExp(r'/\$\{[^}]*\}'), (_) => '/<dyn>');
  // Cola parcial interpolada: si la interpolación NO empieza un segmento
  // (`/clients?id=$x`), corta ahí.
  final dollar = out.indexOf(r'/$');
  if (dollar >= 0) out = out.substring(0, dollar);
  if (out.contains(r'$')) out = out.substring(0, out.indexOf(r'$'));
  // Query string fuera.
  final q = out.indexOf('?');
  if (q >= 0) out = out.substring(0, q);
  // Limpieza.
  out = out.replaceAll(RegExp(r'/+'), '/');
  if (out.endsWith('/')) out = out.substring(0, out.length - 1);
  if (out.length < 2) return null;
  // Ruta de segmentos separados por `/` (`<dyn>` cuenta como segmento válido).
  if (!RegExp(r'^/(?:[A-Za-z0-9_\-<>.]+/)*[A-Za-z0-9_\-<>.]+$').hasMatch(out)) {
    return null;
  }
  if (!out.contains(RegExp(r'[A-Za-z]'))) return null;
  return out;
}

List<AppCall> extractAppCalls() {
  final libDir = Directory('lib');
  final calls = <AppCall>[];
  if (!libDir.existsSync()) return calls;

  void walk(Directory dir) {
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        final rel = entity.path.replaceAll('\\', '/');
        final src = entity.readAsStringSync();
        final file = rel.replaceFirst('lib/', '');

        // 1) Llamadas con literal: `<cliente>.get('/ruta', ...)`.
        for (final m in _dioCallRe.allMatches(src)) {
          if (!_httpReceivers.contains(m.group(1)!.toLowerCase())) continue;
          final verb = m.group(2)!.toUpperCase();
          if (!_httpVerbs.contains(verb.toLowerCase())) continue;
          final path = normalizeEndpoint(m.group(3)!);
          if (path == null) continue;
          calls.add(AppCall(path: path, methods: {verb}, file: file));
        }

        // 2) Llamadas con identificador: `<cliente>.get(_endpoint)`.
        //    Se agrupan los verbos usados con cada identificador y se resuelven
        //    sus definiciones (`ident => expr;` o `ident = expr;`) en este
        //    archivo, extrayendo los literales con forma de ruta.
        final identMethods = <String, Set<String>>{};
        for (final m in _dioIdentCallRe.allMatches(src)) {
          if (!_httpReceivers.contains(m.group(1)!.toLowerCase())) continue;
          final verb = m.group(2)!.toUpperCase();
          if (!_httpVerbs.contains(verb.toLowerCase())) continue;
          identMethods.putIfAbsent(m.group(3)!, () => {}).add(verb);
        }
        for (final entry in identMethods.entries) {
          final defRe = RegExp(
            '\\b${RegExp.escape(entry.key)}\\s*(?:=>|=(?!=))\\s*([^;]*);',
          );
          for (final d in defRe.allMatches(src)) {
            for (final l in _endpointLitRe.allMatches(d.group(1)!)) {
              final path = normalizeEndpoint(l.group(1)!);
              if (path == null) continue;
              calls.add(AppCall(
                path: path,
                methods: {...entry.value},
                file: file,
              ));
            }
          }
        }
      }
    }
  }

  walk(libDir);
  return calls;
}

// ── Rutas reales del dashboard (route.ts bajo app/api/) ─────────────────────

final _exportMethodRe = RegExp(
  r'export\s+(?:const|async\s+function|function)\s+'
  r'(GET|POST|PUT|PATCH|DELETE|OPTIONS)\b',
);

List<DashRoute> readDashboardRoutes(Directory apiDir) {
  final routes = <DashRoute>[];
  final apiPrefix = apiDir.path.replaceAll('\\', '/');

  void walk(Directory dir) {
    for (final entity in dir.listSync(recursive: false)) {
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File &&
          (entity.path.endsWith('route.ts') ||
              entity.path.endsWith('route.tsx'))) {
        final rel =
            entity.path.replaceAll('\\', '/').replaceFirst('$apiPrefix/', '');
        final segments = rel.split('/')..removeLast();
        final routePath =
            '/api${segments.isEmpty ? '' : '/${segments.join('/')}'}';
        final src = entity.readAsStringSync();
        final methods =
            _exportMethodRe.allMatches(src).map((m) => m.group(1)!).toList();
        routes.add(DashRoute(path: routePath, methods: methods));
      }
    }
  }

  walk(apiDir);
  return routes;
}

/// Convierte una ruta del dashboard (`/api/users/[id]`) en RegExp que matchea
/// rutas normalizadas de la app (`/api/users/<dyn>`).
RegExp routeToRegex(String routePath) {
  final re = routePath
      .split('/')
      .where((s) => s.isNotEmpty)
      .map((s) {
        if (s.startsWith('[...')) return '[^/]+';
        if (s.startsWith('[[')) return '(?:[^/]+)?';
        if (s.startsWith('[') && s.endsWith(']')) return '[^/]+';
        return RegExp.escape(s);
      })
      .join('/');
  return RegExp('^/$re\$');
}
