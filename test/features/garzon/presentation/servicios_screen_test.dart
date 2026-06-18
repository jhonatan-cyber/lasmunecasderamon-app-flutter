import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lasmunecasderamon_flutter/core/api_client.dart';
import 'package:lasmunecasderamon_flutter/core/widgets/skeleton_loader.dart';
import 'package:lasmunecasderamon_flutter/features/auth/data/auth_notifier.dart';
import 'package:lasmunecasderamon_flutter/features/garzon/presentation/servicios_screen.dart';
import 'package:lasmunecasderamon_flutter/core/theme.dart';
import '../../../helpers/test_setup.dart';

void main() {
  setUp(() {
    setupTestEnvironment();
  });

  tearDown(() {
    tearDownTestEnvironment();
  });

  /// Pumps [ServiciosScreen] wrapped in a [MaterialApp] for Directionality
  /// and theme support, with mocked providers.
  ///
  /// Uses [tester.runAsync] to let Dio's mock interceptor complete without
  /// leaving pending timers in the test framework.
  Future<void> pumpServiciosScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(Brightness.dark, AppTheme.primaryColor),
        home: createTestApp(
          child: const ServiciosScreen(),
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

    // Process frames — no animations to settle, just flush builders
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }



  // ---------------------------------------------------------------------------
  // Loaded state – form sections
  // ---------------------------------------------------------------------------

  testWidgets('renders all form sections after data loads', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    // Skeleton should be gone
    expect(find.byType(SkeletonCard), findsNothing);

    // Section titles
    expect(find.text('Habitación'), findsOneWidget);
    expect(find.textContaining('Anfitrionas'), findsOneWidget);
    expect(find.textContaining('Clientes'), findsOneWidget);

    // Empty-state labels (rooms/anfitrionas/clientes are empty lists)
    expect(find.text('Selecciona una habitación'), findsOneWidget);
    expect(find.text('Asociar clientes (Opcional)'), findsOneWidget);

    // Payment method section title
    expect(find.text('Método de Pago'), findsOneWidget);

    // Payment method options
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Tarjeta (+20%)'), findsOneWidget);
    expect(find.text('Prepago (Saldo)'), findsOneWidget);

    // Summary card
    expect(find.text('Resumen del Servicio'), findsOneWidget);
  });

  testWidgets('summary shows when no room is selected', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    // With no room selected, the summary shows zero totals
    expect(find.text('TOTAL COBRO'), findsOneWidget);
    expect(find.text('Resumen del Servicio'), findsOneWidget);
  });

  testWidgets('confirm button is enabled initially', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    // The CONFIRMAR Y REGISTRAR button should be rendered
    final confirmButton = find.text('CONFIRMAR Y REGISTRAR');
    expect(confirmButton, findsOneWidget);

    // The button is enabled initially (not submitting)
    final elevatedButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: confirmButton,
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(elevatedButton.onPressed, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  testWidgets('shows error banner when API call fails', (
    WidgetTester tester,
  ) async {
    // Create a Dio that rejects all requests
    final failingDio = Dio();
    failingDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              message: 'Test connection error',
            ),
          );
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: createTestApp(
          child: const ServiciosScreen(),
          overrides: [
            authProvider.overrideWith(
              (ref) => TestAuthNotifier(ref.watch(apiClientProvider)),
            ),
            apiClientProvider.overrideWith(
              (ref) => ApiClient(dio: failingDio),
            ),
          ],
        ),
      ),
    );

    // Let the failing Dio reject
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The catch block sets _error = 'Error al cargar los datos del formulario: ...'
    // DioException message appears in the formatted error
    expect(find.textContaining('Error al cargar'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Payment method interaction
  // ---------------------------------------------------------------------------

  testWidgets('Efectivo payment method is tappable', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    // Tap "Efectivo" payment method
    await tester.tap(find.text('Efectivo'));
    await tester.pump();

    // Should not crash — verify button still exists
    expect(find.text('Efectivo'), findsOneWidget);
  });
}
