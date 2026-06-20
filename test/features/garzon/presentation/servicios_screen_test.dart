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

    
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));

    
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }



  
  
  

  testWidgets('renders all form sections after data loads', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    
    expect(find.byType(SkeletonCard), findsNothing);

    
    expect(find.text('Habitación'), findsOneWidget);
    expect(find.textContaining('Anfitrionas'), findsOneWidget);
    expect(find.textContaining('Clientes'), findsOneWidget);

    
    expect(find.text('Selecciona una habitación'), findsOneWidget);
    expect(find.text('Asociar clientes (Opcional)'), findsOneWidget);

    
    expect(find.text('Método de Pago'), findsOneWidget);

    
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Tarjeta (+20%)'), findsOneWidget);
    expect(find.text('Prepago (Saldo)'), findsOneWidget);

    
    expect(find.text('Resumen del Servicio'), findsOneWidget);
  });

  testWidgets('summary shows when no room is selected', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    
    expect(find.text('TOTAL COBRO'), findsOneWidget);
    expect(find.text('Resumen del Servicio'), findsOneWidget);
  });

  testWidgets('confirm button is enabled initially', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    
    final confirmButton = find.text('CONFIRMAR Y REGISTRAR');
    expect(confirmButton, findsOneWidget);

    
    final elevatedButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: confirmButton,
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(elevatedButton.onPressed, isNotNull);
  });

  
  
  

  testWidgets('shows error banner when API call fails', (
    WidgetTester tester,
  ) async {
    
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

    
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    
    
    expect(find.textContaining('Error al cargar'), findsOneWidget);
  });

  
  
  

  testWidgets('Efectivo payment method is tappable', (
    WidgetTester tester,
  ) async {
    await pumpServiciosScreen(tester);

    
    await tester.tap(find.text('Efectivo'));
    await tester.pump();

    
    expect(find.text('Efectivo'), findsOneWidget);
  });
}
