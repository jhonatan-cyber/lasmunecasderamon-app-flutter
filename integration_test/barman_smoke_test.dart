import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:lasmunecasderamon_flutter/core/router.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/premium_header.dart';
import 'package:lasmunecasderamon_flutter/features/barman/presentation/bar_screen.dart';
import 'package:lasmunecasderamon_flutter/main.dart' as app;

/// Smoke test del rol Barman sobre el dispositivo Windows (dispositivo real,
/// no widget test): login contra el backend real → redirección a `/barman` →
/// los 5 tabs del shell → pantalla Bar (`/barman/bar`) y sus 4 subtabs.
///
/// Las credenciales NO van hardcodeadas: se inyectan en el run con
///   flutter test integration_test -d windows --dart-define=SMOKE_NICK=nick --dart-define=SMOKE_PASSWORD=pass
/// Sin defines, el test valida solo el arranque hasta la pantalla de login.
const String _nick = String.fromEnvironment('SMOKE_NICK', defaultValue: '');
const String _pass = String.fromEnvironment('SMOKE_PASSWORD', defaultValue: '');

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

/// Ruta actual del GoRouter de la app bajo test.
///
/// Nota: `currentConfiguration.uri` en go_router 14 solo refleja las rutas
/// navegadas con `go`/`pushNamed`; las imperativas (`context.push`, p. ej. la
/// tarjeta BAR) NO cambian el `uri`. Para esas se comprueba la presencia del
/// widget de la pantalla.
String currentPath(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  final router = container.read(routerProvider);
  return router.routerDelegate.currentConfiguration.uri.path;
}

/// Título del `PremiumHeader` de la pantalla actual (si lo hay). Tolera que
/// haya más de uno durante la transición entre tabs (ramas keep-alive).
String? headerTitle(WidgetTester tester) {
  final headers = tester.widgetList<PremiumHeader>(find.byType(PremiumHeader));
  if (headers.isEmpty) return null;
  return headers.first.title;
}

/// true si algún `PremiumHeader` montado muestra [title].
bool headerShows(WidgetTester tester, String title) => tester
    .widgetList<PremiumHeader>(find.byType(PremiumHeader))
    .any((h) => h.title == title);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Barman: login → redirect /barman → tabs → pantalla Bar',
      (tester) async {
    // Sesión limpia: aunque la app haya quedado logueada de una corrida previa.
    await const FlutterSecureStorage().deleteAll();

    await app.main();

    // 1) Arranque: pantalla de login visible.
    await pumpUntilFound(tester, find.text('Iniciar Sesión'));
    expect(find.text('Iniciar Sesión'), findsOneWidget,
        reason: 'La app debe abrir en el login');

    if (_nick.isEmpty || _pass.isEmpty) {
      debugPrint(
        'SMOKE (sin credenciales): arranque hasta login OK. '
        'Reejecuta con --dart-define=SMOKE_NICK/SMOKE_PASSWORD para el smoke completo.',
      );
      return;
    }

    // 2) Login con credenciales reales.
    await tester.enterText(find.byType(TextFormField).at(0), _nick);
    await tester.enterText(find.byType(TextFormField).at(1), _pass);
    await tester.ensureVisible(find.text('Iniciar Sesión'));
    await tester.tap(find.text('Iniciar Sesión'));
    debugPrint('SMOKE: login enviado con nick "$_nick"');

    // 3) Redirección por rol → home del barman (`/barman`).
    try {
      await pumpUntilFound(tester, find.text('Operaciones del Bar'),
          timeout: const Duration(seconds: 30));
    } catch (_) {
      // Diagnóstico: dónde quedó la app tras el login.
      debugPrint('SMOKE DIAG: path=${currentPath(tester)}');
      debugPrint('SMOKE DIAG: header=${headerTitle(tester)}');
      debugPrint('SMOKE DIAG: exception=${tester.takeException()}');
      final visible = <String>[];
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final t = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (t.trim().isNotEmpty) visible.add(t.trim());
      }
      debugPrint('SMOKE DIAG: texts=${visible.take(25).toList()}');
      rethrow;
    }
    expect(currentPath(tester), '/barman',
        reason: 'El rol Barman debe caer en /barman');
    expect(find.byType(NavigationBar), findsOneWidget,
        reason: 'Debe renderizar el NavigationBar del shell barman');
    debugPrint('SMOKE: redirect OK → /barman');

    // 4) Los 5 tabs del shell: label del nav → ruta + pantalla esperada.
    // `ready` es un predicado (no solo "header no nulo"): durante la transición
    // el header de la pantalla anterior sigue montado y satisface cualquier
    // comprobación vaga.
    Future<void> tapTab(String label, String path, bool Function() ready,
        String readyDesc) async {
      final navLabel = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      expect(navLabel, findsOneWidget, reason: 'Falta el tab "$label"');
      await tester.ensureVisible(navLabel);
      await tester.tap(navLabel);
      await pumpUntil(tester, () => currentPath(tester) == path,
          reason: 'ruta $path tras tocar "$label" (va en ${currentPath(tester)})');
      await pumpUntil(tester, ready, reason: readyDesc);
      debugPrint('SMOKE: tab "$label" → $path OK');
    }

    await tapTab('Asistencia', '/barman/asistencia',
        () => headerShows(tester, 'Asistencia'), 'header "Asistencia"');

    await tapTab('Anticipos', '/barman/anticipos',
        () => headerShows(tester, 'Anticipos'), 'header "Anticipos"');

    await tapTab('Inicio', '/barman',
        () => tester.any(find.text('Operaciones del Bar')),
        'home "Operaciones del Bar"');
    expect(find.text('Operaciones del Bar'), findsOneWidget);

    await tapTab('Propinas', '/barman/propinas',
        () => headerShows(tester, 'Propinas'), 'header "Propinas"');

    await tapTab('Extras', '/barman/horas-extras',
        () => headerShows(tester, 'Horas Extras'), 'header "Horas Extras"');

    // Vuelta a Inicio para entrar a la pantalla Bar.
    final inicioLabel = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Inicio'),
    );
    await tester.tap(inicioLabel);
    await pumpUntil(tester, () => currentPath(tester) == '/barman',
        reason: 'vuelta a /barman');

    // 5) Pantalla Bar: tarjeta "BAR" del grid de operaciones.
    // Espera con pumpUntil (no expect inmediato): tras volver a Inicio el home
    // puede estar aún en spinner de refresh (refresh.isLoading) o con el grid
    // sin construir.
    final cardBar = find.text('BAR');
    await pumpUntil(tester, () => tester.any(cardBar),
        timeout: const Duration(seconds: 15),
        reason: 'tarjeta BAR en el home');
    await tester.ensureVisible(cardBar);
    await tester.pump();
    await tester.tap(cardBar, warnIfMissed: true);
    debugPrint('SMOKE DIAG: tap BAR enviado, path=${currentPath(tester)}');
    try {
      // `context.push` no actualiza currentConfiguration.uri (imperative match):
      // se comprueba la pantalla montada, no la ruta.
      await pumpUntil(tester, () => tester.any(find.byType(BarScreen)),
          timeout: const Duration(seconds: 15),
          reason: 'BarScreen montada tras tocar la tarjeta BAR');
    } catch (_) {
      debugPrint('SMOKE DIAG: path final=${currentPath(tester)}');
      debugPrint('SMOKE DIAG: exc=${tester.takeException()}');
      final visible = <String>[];
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final t = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (t.trim().isNotEmpty) visible.add(t.trim());
      }
      debugPrint('SMOKE DIAG: texts=${visible.take(25).toList()}');
      rethrow;
    }
    await pumpUntilFound(tester, find.byType(TabBar),
        timeout: const Duration(seconds: 15));
    expect(find.text('Bar'), findsOneWidget, reason: 'Título de la pantalla Bar');
    expect(find.textContaining('unidades en barra'), findsOneWidget,
        reason: 'Subtítulo con el stock total');
    expect(find.descendant(of: find.byType(TabBar), matching: find.text('Stock')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(TabBar), matching: find.textContaining('Pendientes')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(TabBar), matching: find.text('Historial')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(TabBar), matching: find.textContaining('Envases')),
        findsOneWidget);
    debugPrint('SMOKE: pantalla Bar con sus 4 subtabs OK');

    // 6) Subtab Envases: al seleccionarlo aparece la acción del escáner en el AppBar.
    final envasesTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.textContaining('Envases'),
    );
    await tester.tap(envasesTab);
    await pumpUntil(
      tester,
      () => tester.any(find.widgetWithIcon(IconButton, Icons.qr_code_scanner_rounded)),
      reason: 'icono de escáner en el AppBar sobre el tab Envases',
    );
    debugPrint('SMOKE: subtab Envases + acción escáner OK');

    // 7) Sin excepciones renderizadas durante todo el recorrido.
    expect(tester.takeException(), isNull,
        reason: 'No debe haber excepciones de render durante el smoke');
    debugPrint('SMOKE: ¡COMPLETADO SIN ERRORES!');
  });
}
