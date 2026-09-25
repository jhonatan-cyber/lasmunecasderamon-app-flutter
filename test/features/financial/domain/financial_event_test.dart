import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/features/financial/domain/financial_event.dart';

/// Bloquea el bug real: los IDs de este dominio son varchar(36) (UUID) en el
/// esquema del dashboard y llegan como STRING. Los casts `as int?` lanzaban
/// TypeError en cada fila y la pantalla de eventos quedaba en estado de error.
void main() {
  group('FinancialEvent.fromJson', () {
    test('parsea una fila real de /tips?tipo=detalle (UUIDs string)', () {
      // Shape exacto de TipRepository.getDetails: propina_id, id_detalle_propina,
      // fecha_crea, fecha_venta, total, monto, estado, metodo_pago,
      // codigo_venta, venta_id, fecha_pago. Sin campo `tipo`.
      final row = <String, dynamic>{
        'propina_id': '3f1a9c02-7d4e-4b21-9a6c-1e5d8b7f0a11',
        'id_detalle_propina': 'b8e2d4a6-1c3f-4e5a-8b7d-9f0a2c4e6f80',
        'fecha_crea': '2026-09-20 22:15:00',
        'fecha_venta': '2026-09-20 22:10:00',
        'total': 85000,
        'monto': 8500,
        'estado': 1,
        'metodo_pago': 'efectivo',
        'codigo_venta': 'VENTA42',
        'venta_id': 'c1d2e3f4-a5b6-4c7d-8e9f-0a1b2c3d4e5f',
        'fecha_pago': null
      };

      final event = FinancialEvent.fromJson(row);

      expect(event.propinaId, '3f1a9c02-7d4e-4b21-9a6c-1e5d8b7f0a11');
      expect(event.idDetallePropina, 'b8e2d4a6-1c3f-4e5a-8b7d-9f0a2c4e6f80');
      expect(event.codigoVenta, 'VENTA42');
      expect(event.monto, 8500.0);
      expect(event.estado, 1);
      // Las filas de tips no traen `tipo`: el default es 'otro' y la pantalla
      // decide el detalle por el tipo de pantalla (widget.type), no por esto.
      expect(event.tipo, 'otro');
      expect(event.fechaCrea, '2026-09-20 22:15:00');
    });

    test('parsea una fila real de /commissions/user?tipo=detalle', () {
      final row = <String, dynamic>{
        'id': '9a8b7c6d-5e4f-4321-8765-0fedcba98765',
        'fecha_crea': '2026-09-19 21:00:00',
        'codigo_venta': 'VENTA07',
        'tipo': 'venta',
        'monto': 12000,
        'estado': 1
      };

      final event = FinancialEvent.fromJson(row);

      expect(event.id, '9a8b7c6d-5e4f-4321-8765-0fedcba98765');
      expect(event.tipo, 'venta'); // filtra == 'venta' en la pantalla
      expect(event.estado, 1);
      expect(event.monto, 12000.0);
      expect(event.propinaId, isNull); // tips no viene en esta fila
    });

    test('tolera estado numérico y IDs opcionales ausentes', () {
      final event = FinancialEvent.fromJson({
        'id': 42, // id numérico no debe reventar
        'monto': 100,
        'fecha_crea': '2026-01-01 00:00:00',
        'estado': 2.0, // num vía JSON
        'tipo': 'propina'
      });

      expect(event.id, '42');
      expect(event.estado, 2);
      expect(event.idComision, isNull);
      expect(event.idDetallePropina, isNull);
      expect(event.propinaId, isNull);
    });
  });
}
