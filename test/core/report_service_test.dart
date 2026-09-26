import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lasmunecasderamon_flutter/core/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('report_service_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('calculateLiquidationTotal', () {
    LiquidationEvent event({
      required String type,
      required double amount,
      int? estado,
      String codigo = 'DEV-001',
    }) {
      return LiquidationEvent(
        type: type,
        codigo: codigo,
        date: DateTime(2026, 9, 26, 20, 15),
        amount: amount,
        estado: estado,
      );
    }

    test('suma los eventos con estado 1 y ignora el resto', () {
      final total = calculateLiquidationTotal([
        event(type: 'servicio', amount: 50000, estado: 1),
        event(type: 'comision', amount: 5000, estado: 0),
        event(type: 'propina', amount: 3000, estado: 2),
      ]);

      expect(total, 50000);
    });

    test('los anticipos restan del total', () {
      final total = calculateLiquidationTotal([
        event(type: 'servicio', amount: 50000, estado: 1),
        event(type: 'anticipo', amount: 20000, estado: 1),
      ]);

      expect(total, 30000);
    });

    test('un evento sin estado cuenta (semántica de Expo)', () {
      final total = calculateLiquidationTotal([
        event(type: 'comision', amount: 7500),
      ]);

      expect(total, 7500);
    });
  });

  group('liquidationEventLabel / liquidationUserLabel', () {
    test('etiquetas por tipo y subType', () {
      expect(liquidationEventLabel('comision', 'venta'), 'Comisión de Venta');
      expect(
        liquidationEventLabel('comision', 'servicio'),
        'Comisión de Servicio',
      );
      expect(liquidationEventLabel('comision'), 'Comisión');
      expect(liquidationEventLabel('propina', 'venta'), 'Propina de Venta');
      expect(liquidationEventLabel('venta'), 'Venta de Producto');
      expect(liquidationEventLabel('hora_extra'), 'Hora Extra');
      expect(liquidationEventLabel('otro'), 'OTRO');
    });

    test('rótulo del usuario con y sin nick', () {
      expect(liquidationUserLabel('Sebas Rojas', nick: 'sebas'), 'Sebas Rojas - sebas');
      expect(liquidationUserLabel('Sebas'), 'Sebas');
      expect(liquidationUserLabel('  ', nick: '  '), '');
    });
  });

  group('LiquidationEvent.fromJson', () {
    test('normaliza el shape de /events/user', () {
      final event = LiquidationEvent.fromJson({
        'type': 'comision',
        'id': '8a1b',
        'codigo': 'DEV-FIN-001',
        'date': '2026-09-26T20:15:00.000Z',
        'amount': '2500.50',
        'estado': 1,
        'subType': 'venta',
      });

      expect(event.id, '8a1b');
      expect(event.type, 'comision');
      expect(event.subType, 'venta');
      expect(event.codigo, 'DEV-FIN-001');
      expect(event.date.year, 2026);
      expect(event.amount, 2500.50);
      expect(event.estado, 1);
      expect(event.signedAmount, 2500.50);
      expect(event.label, 'Comisión de Venta');
    });

    test('las etiquetas de estado coinciden con Expo', () {
      expect(liquidationStatusLabel(1, 'comision'), 'Por cobrar');
      expect(liquidationStatusLabel(0, 'comision'), 'Pagado');
      expect(liquidationStatusLabel(3, 'propina'), 'Rechazado');
      expect(liquidationStatusLabel(4, 'servicio'), 'Completado');
      expect(liquidationStatusLabel(1, 'anticipo'), 'Confirmado');
      expect(liquidationStatusLabel(2, 'anticipo'), 'Pendiente');
      expect(liquidationStatusLabel(null, 'comision'), '');
    });

    test('un anticipo resta', () {
      final event = LiquidationEvent.fromJson({
        'type': 'anticipo',
        'monto': 1500,
      });

      expect(event.isAnticipo, isTrue);
      expect(event.signedAmount, -1500);
      expect(event.estado, isNull);
    });
  });

  test('exportLiquidationReport genera un PDF con los eventos', () async {
    final path = await reportService.exportLiquidationReport(
      userLabel: 'Sebas Rojas - sebas',
      events: [
        LiquidationEvent(
          type: 'servicio',
          codigo: 'DEV-001',
          date: DateTime(2026, 9, 26, 20, 15),
          amount: 50000,
          estado: 1,
        ),
        LiquidationEvent(
          type: 'anticipo',
          codigo: 'DEV-002',
          date: DateTime(2026, 9, 26, 21, 15),
          amount: 20000,
          estado: 1,
        ),
      ],
      total: 30000,
    );

    expect(path, isNotNull);

    final file = File(path!);
    expect(file.existsSync(), isTrue);

    // Un PDF válido arranca con la firma %PDF-.
    final header = String.fromCharCodes(await file.readAsBytes().then((b) => b.take(5)));
    expect(header, '%PDF-');
  });
}
