import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/skeleton_loader.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/presentation/garzon_home_screen.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() async {
    setupTestEnvironment();
    await initializeDateFormatting('es_CL', null);
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  /// Pumps [GarzonHomeScreen] wrapped in a [MaterialApp] for Directionality
  /// and theme support, with mocked providers.
  ///
  /// Uses [tester.runAsync] to let Dio's mock interceptor complete without
  /// leaving pending timers in the test framework.
  Future<void> pumpHomeScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
        home: createTestApp(
          child: const GarzonHomeScreen(),
          overrides: [
            authProvider.overrideWith(
              (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
            ),
            apiClientProvider.overrideWith(
              (ref) => ApiClient(dio: createMockDio()),
            ),
          ],
        ),
      ),
    );

    // Let Dio's interceptors resolve (they use internal timers)
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));

    // Process frames — FadeLoadingSwitcher uses 500ms transition
    await tester.pumpAndSettle();
  }



  // ---------------------------------------------------------------------------
  // Loaded state – UI sections
  // ---------------------------------------------------------------------------

  testWidgets('renders all dashboard sections after loading completes', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    // Skeleton should be gone
    expect(find.byType(SkeletonStatCard), findsNothing);

    // Section title: Métricas del Período
    expect(find.text('Métricas del Período'), findsOneWidget);

    // Stats card labels
    expect(find.text('Total Propinas'), findsOneWidget);
    expect(find.text('Comandas con Propina'), findsOneWidget);

    // Payout card
    expect(find.text('Acumulado para Retiro'), findsOneWidget);
    expect(find.text('Liquidación'), findsOneWidget);

    // Calendar
    expect(find.text('Calendario Operativo'), findsOneWidget);

    // Quick action cards
    expect(find.text('PEDIDOS'), findsOneWidget);
    expect(find.text('SERVICIOS'), findsOneWidget);
    expect(find.text('Comandas de Mesa'), findsOneWidget);
    expect(find.text('Registro de Atención'), findsOneWidget);
  });

  testWidgets('stats card shows zero values when no API data', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    // With mock Dio, totalEarnings = 0 so "0 ventas" should appear
    expect(find.text('0 ventas'), findsOneWidget);
  });

  testWidgets('payout card container is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('Acumulado para Retiro'), findsOneWidget);
  });

  testWidgets('calendar shows weekday headers', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    // Calendar weekday headers
    expect(find.text('LU'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);
    expect(find.text('MI'), findsOneWidget);
    expect(find.text('JU'), findsOneWidget);
    expect(find.text('VI'), findsOneWidget);
    expect(find.text('SÁ'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Action cards (render only — navigation requires GoRouter ancestor)
  // ---------------------------------------------------------------------------

  testWidgets('PEDIDOS action card is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('PEDIDOS'), findsOneWidget);
    expect(find.text('Comandas de Mesa'), findsOneWidget);
  });

  testWidgets('SERVICIOS action card is rendered', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    expect(find.text('SERVICIOS'), findsOneWidget);
    expect(find.text('Registro de Atención'), findsOneWidget);
  });
}
