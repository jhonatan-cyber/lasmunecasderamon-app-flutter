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

    
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));

    
    await tester.pumpAndSettle();
  }



  
  
  

  testWidgets('renders all dashboard sections after loading completes', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    
    expect(find.byType(SkeletonStatCard), findsNothing);

    
    expect(find.text('Métricas del Período'), findsOneWidget);

    
    expect(find.text('Total Propinas'), findsOneWidget);
    expect(find.text('Comandas con Propina'), findsOneWidget);

    
    expect(find.text('Acumulado para Retiro'), findsOneWidget);
    expect(find.text('Liquidación'), findsOneWidget);

    
    expect(find.text('Calendario Operativo'), findsOneWidget);

    
    expect(find.text('PEDIDOS'), findsOneWidget);
    expect(find.text('SERVICIOS'), findsOneWidget);
    expect(find.text('Comandas de Mesa'), findsOneWidget);
    expect(find.text('Registro de Atención'), findsOneWidget);
  });

  testWidgets('stats card shows zero values when no API data', (
    WidgetTester tester,
  ) async {
    await pumpHomeScreen(tester);

    
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

    
    expect(find.text('LU'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);
    expect(find.text('MI'), findsOneWidget);
    expect(find.text('JU'), findsOneWidget);
    expect(find.text('VI'), findsOneWidget);
    expect(find.text('SÁ'), findsOneWidget);
    expect(find.text('DO'), findsOneWidget);
  });

  
  
  

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
