import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:lasmunecasderamon_flutter/core/router.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/main.dart' as app;

/// Smoke e2e: la caché HTTP de Flutter (`dio_cache_interceptor` con
/// `forceCache` + Hive) NO debe servir datos del usuario anterior al cambiar
/// de sesión. Regresión del fix de `ApiClient` (clave de caché aislada por
/// token + `clearCache()` en login/logout/sesión vencida).
///
/// Flujo (dispositivo Windows real, backend local):
///
///   login A → `/garzon/financieros` llena la caché con las propinas de A
///   → logout → login B → `/garzon/financieros` ve las de B y NO las de A
///   → logout → login A de nuevo → ve las de A y NO las de B.
///
/// Requiere usuarios con datos distintos en dev (p. ej. Damo con fixtures
/// `SMOKE-TIPS-*` de `tool/seed_financial_fixtures.mjs` y Sebas con sus
/// propinas reales `DEV-FIN-001`/`IWEOX95J`).
///
/// Lanzamiento:
///
///   flutter test integration_test/session_cache_switch_test.dart -d windows \
///     --dart-define=SMOKE_NICK=... --dart-define=SMOKE_PASSWORD=... \
///     --dart-define=SMOKE_NICK_B=... --dart-define=SMOKE_PASSWORD_B=... \
///     --dart-define=API_BASE_DOMAIN=http://localhost:3000
///
/// Sin defines, el test valida solo el arranque hasta la pantalla de login.
const String _nick = String.fromEnvironment('SMOKE_NICK', defaultValue: '');
const String _pass = String.fromEnvironment('SMOKE_PASSWORD', defaultValue: '');
const String _nickB = String.fromEnvironment('SMOKE_NICK_B', defaultValue: '');
const String _passB = String.fromEnvironment('SMOKE_PASSWORD_B', defaultValue: '');

/// Bombea (con tiempo real para la red) hasta que [finder] exista.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) {
  return pumpUntil(
    tester,
    () => tester.any(finder),
    timeout: timeout,
    reason: '$finder',
  );
}

/// Bombea hasta que [condition] sea verdadera (tiempo real + frames).
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
  String reason = '',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 150));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  fail('Timeout tras ${timeout.inSeconds}s esperando: $reason');
}

/// Ruta actual del GoRouter de la app bajo test (ver nota en barman_smoke).
String currentPath(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  final router = container.read(routerProvider);
  return router.routerDelegate.currentConfiguration.uri.path;
}

/// Navega con `go` (ruta declarada) y espera a que el uri la refleje.
Future<void> goTo(WidgetTester tester, String path) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  container.read(routerProvider).go(path);
  await pumpUntil(tester, () => currentPath(tester) == path,
      reason: 'navegar a $path (va en ${currentPath(tester)})');
}

/// Login con el formulario y espera el shell del rol.
Future<void> loginAs(WidgetTester tester, String nick, String pass) async {
  await tester.enterText(find.byType(TextFormField).at(0), nick);
  await tester.enterText(find.byType(TextFormField).at(1), pass);
  await tester.ensureVisible(find.text('Iniciar Sesión'));
  await tester.tap(find.text('Iniciar Sesión'));
  try {
    await pumpUntil(
      tester,
      () => tester.any(find.byType(NavigationBar)) &&
          currentPath(tester).isNotEmpty &&
          currentPath(tester) != '/login' &&
          currentPath(tester) != '/',
      timeout: const Duration(seconds: 30),
      reason: 'shell del rol tras login de "$nick" (path=${currentPath(tester)})',
    );
  } catch (_) {
    debugPrint('SWITCH DIAG: path=${currentPath(tester)}');
    debugPrint('SWITCH DIAG: exception=${tester.takeException()}');
    rethrow;
  }
  debugPrint('SWITCH: login "$nick" OK → ${currentPath(tester)}');
}

/// Logout vía el notifier (mismo camino que los botones de las homes) y
/// espera el retorno al login.
Future<void> logout(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  await container.read(authProvider.notifier).logout();
  await pumpUntil(
    tester,
    () => currentPath(tester) == '/login' ||
        tester.any(find.text('Iniciar Sesión')),
    timeout: const Duration(seconds: 30),
    reason: 'volver al login tras logout (va en ${currentPath(tester)})',
  );
  await pumpUntilFound(tester, find.text('Iniciar Sesión'));
}

/// Espera la pantalla de propinas con [code] y afirma la ausencia de los
/// códigos de la otra sesión.
Future<void> expectOnlyPropinasOf(
  WidgetTester tester, {
  required String own,
  required String ownSecond,
  required String foreign,
  required String foreignSecond,
  required String who,
}) async {
  await goTo(tester, '/garzon/financieros');
  await pumpUntilFound(tester, find.text('Eventos Financieros'));
  await pumpUntil(
    tester,
    () => tester.any(find.text(own)),
    timeout: const Duration(seconds: 30),
    reason: 'fila $own en la sesión de $who',
  );
  expect(find.text(ownSecond), findsOneWidget,
      reason: '$ownSecond también pertenece a $who');
  expect(find.text(foreign), findsNothing,
      reason: 'la caché de la otra sesión no debe filtrarse en la de $who');
  expect(find.text(foreignSecond), findsNothing,
      reason: 'la caché de la otra sesión no debe filtrarse en la de $who');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Caché HTTP aislada por sesión: Damo → Sebas → Damo sin fugas de datos',
      (tester) async {
    // Sesión limpia: aunque la app haya quedado logueada de una corrida previa.
    // OJO: la caché Hive NO se limpia a mano: ese es justamente el punto del
    // test (el fix debe evitar las fugas sin limpieza manual).
    await const FlutterSecureStorage().deleteAll();

    await app.main();

    // 1) Arranque: pantalla de login visible.
    await pumpUntilFound(tester, find.text('Iniciar Sesión'));
    expect(find.text('Iniciar Sesión'), findsOneWidget,
        reason: 'La app debe abrir en el login');

    if (_nick.isEmpty || _pass.isEmpty || _nickB.isEmpty || _passB.isEmpty) {
      debugPrint(
        'SWITCH (sin credenciales): arranque hasta login OK. '
        'Reejecuta con --dart-define=SMOKE_NICK/SMOKE_PASSWORD/'
        'SMOKE_NICK_B/SMOKE_PASSWORD_B para el smoke completo.',
      );
      return;
    }

    // 2) Sesión A (Damo): llena la caché con SUS propinas (fixtures seed).
    await loginAs(tester, _nick, _pass);
    await expectOnlyPropinasOf(
      tester,
      own: 'SMOKE-TIPS-1',
      ownSecond: 'SMOKE-TIPS-2',
      foreign: 'DEV-FIN-001',
      foreignSecond: 'IWEOX95J',
      who: _nick,
    );
    debugPrint('SWITCH: sesión A ($_nick) ve sus propinas; cacheadas');

    // 3) Cambio de sesión → sesión B (Sebas): sus propinas reales.
    //    Se entra por el enlace del home (paridad con el tab de Expo);
    //    go_router 14 no refleja context.push en currentConfiguration.uri,
    //    así que la llegada se aserta por widget.
    await logout(tester);
    await loginAs(tester, _nickB, _passB);
    await pumpUntil(
      tester,
      () => tester.any(find.text('FINANCIERO')),
      timeout: const Duration(seconds: 30),
      reason: 'tarjeta FINANCIERO en el home del garzón',
    );
    await tester.ensureVisible(find.text('FINANCIERO'));
    await tester.tap(find.text('FINANCIERO'), warnIfMissed: true);
    await pumpUntilFound(tester, find.text('Eventos Financieros'),
        timeout: const Duration(seconds: 15));
    // El enlace usa push; se hace pop antes del flujo con go() para no dejar
    // la ruta pusheada montada debajo (finders ambiguos con dos pantallas).
    Navigator.of(tester.element(find.text('Eventos Financieros'))).pop();
    await pumpUntil(
      tester,
      () => !tester.any(find.text('Eventos Financieros')),
      timeout: const Duration(seconds: 15),
      reason: 'el pop vuelve al home del garzón',
    );
    await expectOnlyPropinasOf(
      tester,
      own: 'DEV-FIN-001',
      ownSecond: 'IWEOX95J',
      foreign: 'SMOKE-TIPS-1',
      foreignSecond: 'SMOKE-TIPS-2',
      who: _nickB,
    );
    debugPrint('SWITCH: sesión B ($_nickB) solo ve las suyas ✓');

    // 4) Vuelta a A: los datos de B tampoco deben filtrarse.
    await logout(tester);
    await loginAs(tester, _nick, _pass);
    await expectOnlyPropinasOf(
      tester,
      own: 'SMOKE-TIPS-1',
      ownSecond: 'SMOKE-TIPS-2',
      foreign: 'DEV-FIN-001',
      foreignSecond: 'IWEOX95J',
      who: _nick,
    );
    debugPrint('SWITCH: de vuelta en A ($_nick) sin datos de B ✓');

    // 5) Sin excepciones renderizadas durante todo el recorrido.
    expect(tester.takeException(), isNull,
        reason: 'No debe haber excepciones de render durante el smoke');
    debugPrint('SWITCH: ¡COMPLETADO SIN ERRORES!');
  });
}
