import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:lasmunecasderamon_flutter/core/router.dart';
import 'package:lasmunecasderamon_flutter/main.dart' as app;

/// Smoke e2e de la pantalla «Eventos Financieros» sobre el dispositivo Windows
/// (dispositivo real, no widget test), al estilo de `barman_smoke_test.dart`:
///
///   login contra el backend local → `/garzon/financieros` (type=propinas)
///   → `/anfitriona/financieros` (type=comisiones).
///
/// Usa los fixtures idempotentes de `tool/seed_financial_fixtures.mjs`
/// (ejecútalo una vez contra la BD local del dashboard):
///
///   · propinas    → SMOKE-TIPS-1 (estado 1, Pendiente), SMOKE-TIPS-2 (estado 0, Pagado)
///   · comisiones  → SMOKE-COMM   (estado 1, Pendiente), SMOKE-TIPS-1 (estado 2, Pagado)
///
/// Se comprueba: carga inicial al montar (initState), badges de estado, los
/// chips de filtro (Todos/Pendiente/Pagado), el modal de detalle con sus
/// campos y la sección «Detalle de Venta» (solo en propinas), y cero
/// excepciones de render.
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

/// Ruta actual del GoRouter de la app bajo test (ver nota en barman_smoke_test).
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

/// Chip de filtro: es el único `Text` con esa etiqueta y fontSize 13 (los
/// badges de estado de las filas usan 10 y los campos del modal, 14), así se
/// evita la ambigüedad de `find.text('Pendiente')`.
Finder chip(String label) => find.byWidgetPredicate(
      (w) => w is Text && w.data == label && w.style?.fontSize == 13,
      description: 'chip de filtro "$label"',
    );

/// Fila-card de un código concreto: el `Row` ancestro más cercano del texto del
/// código (cabecera/chips/modal no comparten esa cadena de ancestros).
Finder cardRow(String code) => find.ancestor(
      of: find.text(code),
      matching: find.byType(Row),
    );

/// Badges/textos dentro de la fila de [code].
Finder inCard(String code, String text) => find.descendant(
      of: cardRow(code),
      matching: find.text(text),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Eventos Financieros: login → propinas → comisiones → detalle',
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

    // 3) Redirección por rol → home del rol (Damo es Barman → /barman).
    //    Los 4 shells (garzón/anfitriona/cajero/barman) montan NavigationBar:
    //    esperarlo + una ruta resuelta evita continuar con la sesión a medias
    //    (recién tras el tap, currentConfiguration aún puede devolver '').
    try {
      await pumpUntil(
        tester,
        () => tester.any(find.byType(NavigationBar)) &&
            currentPath(tester).isNotEmpty &&
            currentPath(tester) != '/login' &&
            currentPath(tester) != '/',
        timeout: const Duration(seconds: 30),
        reason: 'shell del rol tras el login (path=${currentPath(tester)})',
      );
    } catch (_) {
      debugPrint('SMOKE DIAG: path=${currentPath(tester)}');
      debugPrint('SMOKE DIAG: exception=${tester.takeException()}');
      rethrow;
    }
    debugPrint('SMOKE: login OK → ${currentPath(tester)}');

    // 3b) El home del barman enlaza a la pantalla financiera (paridad con
    //     el tab «Propinas» de Expo, que ES esta pantalla). Se aserta por
    //     widget porque go_router 14 no refleja context.push en
    //     currentConfiguration.uri.
    await pumpUntil(
      tester,
      () => tester.any(find.text('FINANCIERO')),
      timeout: const Duration(seconds: 30),
      reason: 'tarjeta FINANCIERO en el home del barman',
    );
    await tester.ensureVisible(find.text('FINANCIERO'));
    await tester.tap(find.text('FINANCIERO'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('Eventos Financieros')) &&
          tester.any(find.text('SMOKE-TIPS-1')),
      timeout: const Duration(seconds: 30),
      reason: 'pantalla financiera con las propinas tras el tap del home',
    );
    debugPrint('SMOKE: enlace home FINANCIERO → pantalla financiera OK');

    // Volvemos al home (pop) antes de continuar: mezclar este push con el
    // go() posterior dejaba la ruta pusheada montada debajo y los finders
    // ambiguos veían dos pantallas financieras (flake «Too many elements»).
    Navigator.of(tester.element(find.text('Eventos Financieros'))).pop();
    await pumpUntil(
      tester,
      () => !tester.any(find.text('Eventos Financieros')),
      timeout: const Duration(seconds: 15),
      reason: 'el pop vuelve al home del barman',
    );

    // ── 4) Pantalla de propinas (/garzon/financieros, type=propinas) ────────
    await goTo(tester, '/garzon/financieros');
    await pumpUntilFound(tester, find.text('Eventos Financieros'));
    // La carga inicial la dispara initState: sin datos aún no hay filas.
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-TIPS-1')),
      timeout: const Duration(seconds: 30),
      reason: 'fila SMOKE-TIPS-1 tras el fetch de initState',
    );
    expect(find.text('Eventos Financieros'), findsOneWidget,
        reason: 'Título de la pantalla');
    expect(find.text('SMOKE-TIPS-1'), findsOneWidget);
    expect(find.text('SMOKE-TIPS-2'), findsOneWidget);
    expect(chip('Todos'), findsOneWidget);
    expect(chip('Pendiente'), findsOneWidget);
    expect(chip('Pagado'), findsOneWidget);

    // Badges de estado por fila (1 = pendiente, 0 = pagada en propinas).
    expect(inCard('SMOKE-TIPS-1', 'Pendiente'), findsOneWidget,
        reason: 'SMOKE-TIPS-1 está pendiente (estado 1)');
    expect(inCard('SMOKE-TIPS-2', 'Pagado'), findsOneWidget,
        reason: 'SMOKE-TIPS-2 está pagada (estado 0)');
    // Fecha formateada con locale es (initializeDateFormatting en main()).
    expect(inCard('SMOKE-TIPS-1', '5 ene 2026 21:30'), findsOneWidget,
        reason: 'Fecha de la fila con formato "d MMM yyyy HH:mm" (es)');
    debugPrint('SMOKE: /garzon/financieros con sus 2 filas y badges OK');

    // 5) Chips de filtro.
    await tester.ensureVisible(chip('Pendiente'));
    await tester.tap(chip('Pendiente'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-TIPS-1')) &&
          !tester.any(find.text('SMOKE-TIPS-2')),
      reason: 'chip "Pendiente" deja solo SMOKE-TIPS-1',
    );
    debugPrint('SMOKE: filtro Pendiente OK');

    await tester.ensureVisible(chip('Pagado'));
    await tester.tap(chip('Pagado'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-TIPS-2')) &&
          !tester.any(find.text('SMOKE-TIPS-1')),
      reason: 'chip "Pagado" deja solo SMOKE-TIPS-2',
    );
    debugPrint('SMOKE: filtro Pagado OK');

    await tester.ensureVisible(chip('Todos'));
    await tester.tap(chip('Todos'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-TIPS-1')) &&
          tester.any(find.text('SMOKE-TIPS-2')),
      reason: 'chip "Todos" restaura ambas filas',
    );

    // 6) Modal de detalle de una propina.
    await tester.ensureVisible(find.text('SMOKE-TIPS-1'));
    await tester.tap(find.text('SMOKE-TIPS-1'), warnIfMissed: true);
    try {
      await pumpUntilFound(tester, find.text('Detalle del Evento'),
          timeout: const Duration(seconds: 15));
      // El sheet arranca en spinner hasta que resuelven /tips/{id} + /ventas/{id}.
      await pumpUntil(tester, () => tester.any(find.text('Código')),
          timeout: const Duration(seconds: 20),
          reason: 'campos del modal tras cargar el detalle');
    } catch (_) {
      debugPrint('SMOKE DIAG: path=${currentPath(tester)}');
      debugPrint('SMOKE DIAG: exc=${tester.takeException()}');
      rethrow;
    }

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget, reason: 'ModalBottomSheet del detalle');
    expect(find.descendant(of: sheet, matching: find.text('Detalle del Evento')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Código')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('SMOKE-TIPS-1')),
        findsOneWidget,
        reason: 'El modal muestra el código de la venta');
    expect(find.descendant(of: sheet, matching: find.text('Estado')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Pendiente')),
        findsOneWidget);
    expect(
        find.descendant(of: sheet, matching: find.text('Detalle de Venta')),
        findsOneWidget,
        reason: 'La venta asociada (smoke-fin-v1) se muestra en el modal');
    debugPrint('SMOKE: modal de detalle de propina OK');

    // Cierre del modal.
    await tester.tap(
        find.descendant(of: sheet, matching: find.byIcon(Icons.close_rounded)),
        warnIfMissed: true);
    await pumpUntil(tester, () => !tester.any(find.text('Detalle del Evento')),
        reason: 'el modal se cierra con la X');

    // ── 7) Pantalla de comisiones (/anfitriona/financieros, type=comisiones)
    await goTo(tester, '/anfitriona/financieros');
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-COMM')),
      timeout: const Duration(seconds: 30),
      reason: 'fila SMOKE-COMM en la pantalla de comisiones',
    );
    expect(find.text('Eventos Financieros'), findsOneWidget);
    expect(find.text('SMOKE-COMM'), findsOneWidget);
    expect(find.text('SMOKE-TIPS-1'), findsOneWidget,
        reason: 'La comisión pagada cuelga de la venta SMOKE-TIPS-1');
    // 1 = 'Por pagar' → Pendiente; 2 = 'Pagado' → Pagado (paridad con Expo).
    expect(inCard('SMOKE-COMM', 'Pendiente'), findsOneWidget);
    expect(inCard('SMOKE-TIPS-1', 'Pagado'), findsOneWidget,
        reason: 'Una comisión con estado 2 no debe etiquetarse Pendiente');
    debugPrint('SMOKE: /anfitriona/financieros con sus 2 filas y badges OK');

    // 8) Chips de filtro en comisiones.
    await tester.ensureVisible(chip('Pendiente'));
    await tester.tap(chip('Pendiente'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-COMM')) &&
          !tester.any(find.text('SMOKE-TIPS-1')),
      reason: 'chip "Pendiente" deja solo SMOKE-COMM',
    );
    await tester.ensureVisible(chip('Pagado'));
    await tester.tap(chip('Pagado'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-TIPS-1')) &&
          !tester.any(find.text('SMOKE-COMM')),
      reason: 'chip "Pagado" deja solo la comisión pagada (estado 2)',
    );
    await tester.ensureVisible(chip('Todos'));
    await tester.tap(chip('Todos'), warnIfMissed: true);
    await pumpUntil(
      tester,
      () => tester.any(find.text('SMOKE-COMM')) &&
          tester.any(find.text('SMOKE-TIPS-1')),
      reason: 'chip "Todos" restaura ambas filas',
    );
    debugPrint('SMOKE: filtros de comisiones OK');

    // 9) Modal de detalle de la comisión PAGADA: estado 2 → «Pagado», y sin
    //    «Detalle de Venta» (solo el tipo propinas resuelve /tips/{id} →
    //    /ventas/{id}, igual que en Expo).
    await tester.ensureVisible(find.text('SMOKE-TIPS-1'));
    await tester.tap(find.text('SMOKE-TIPS-1'), warnIfMissed: true);
    await pumpUntilFound(tester, find.text('Detalle del Evento'),
        timeout: const Duration(seconds: 15));
    await pumpUntil(tester, () => tester.any(find.text('Código')),
        timeout: const Duration(seconds: 15),
        reason: 'campos del modal de comisión');
    expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.text('Código')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('SMOKE-TIPS-1')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Pagado')),
        findsOneWidget,
        reason: 'La comisión con estado 2 se muestra como Pagada');
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Detalle de Venta')),
        findsNothing,
        reason: 'Las comisiones no traen detalle de venta (paridad con Expo)');
    await tester.tap(
        find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byIcon(Icons.close_rounded)),
        warnIfMissed: true);
    await pumpUntil(tester, () => !tester.any(find.text('Detalle del Evento')),
        reason: 'cierre del modal de comisión');

    // 10) Sin excepciones renderizadas durante todo el recorrido.
    expect(tester.takeException(), isNull,
        reason: 'No debe haber excepciones de render durante el smoke');
    debugPrint('SMOKE: ¡COMPLETADO SIN ERRORES!');
  });
}
