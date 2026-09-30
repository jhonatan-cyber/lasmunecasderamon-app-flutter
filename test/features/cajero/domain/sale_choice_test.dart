import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/features/cajero/domain/sale_choice.dart';

void main() {
  final Map<String, dynamic> conShotAnfitriona = {
    'precio': 180000,
    'comision': 5000,
    'stock_bar': 4,
    'opciones_venta': [
      {'tipo': 'botella', 'precio': 180000, 'comision': 5000},
      {
        'tipo': 'shot',
        'precio': 6000,
        'comision': 0,
        'precio_anfitriona': 3500,
      },
    ],
  };

  final Map<String, dynamic> soloBotella = {'precio': 5000, 'comision': 0, 'stock_bar': 12};

  group('parseOpcionesVenta', () {
    test('acepta la lista tal cual', () {
      final opciones = parseOpcionesVenta([
        {'tipo': 'shot', 'precio': 100, 'comision': 0},
      ]);
      expect(opciones, hasLength(1));
      expect(opciones.first.tipo, 'shot');
      expect(opciones.first.precio, 100);
    });

    test('acepta el JSON guardado por Configuraciones', () {
      final opciones = parseOpcionesVenta(
        '[{"tipo":"shot","precio":100,"comision":0,"precio_anfitriona":50}]',
      );
      expect(opciones, hasLength(1));
      expect(opciones.first.precioAnfitriona, 50);
    });

    test('sin opciones o con JSON inválido devuelve lista vacía', () {
      expect(parseOpcionesVenta(null), isEmpty);
      expect(parseOpcionesVenta('no-es-json'), isEmpty);
      expect(parseOpcionesVenta(42), isEmpty);
    });
  });

  group('resolverVentaProducto', () {
    test('solo con botella ofrece una opción y vende a precio de botella', () {
      final venta = resolverVentaProducto(soloBotella);

      expect(venta.opciones, hasLength(1));
      expect(venta.tipoVenta, SaleChoice.botella);
      expect(venta.esShot, isFalse);
      expect(venta.precio, 5000);
      expect(venta.comision, 0);
      expect(venta.maxCantidad, 12);
    });

    test('con shot ofrece botella, shot cliente y shot anfitriona', () {
      final venta = resolverVentaProducto(conShotAnfitriona);

      expect(
        venta.opciones.map((o) => o.tipo).toList(),
        ['botella', 'shot', 'shot_anfitriona'],
      );
      expect(venta.tieneShot, isTrue);
      expect(venta.tieneShotAnfitriona, isTrue);
      // Por defecto se vende botella, como siempre.
      expect(venta.tipoVenta, SaleChoice.botella);
      expect(venta.precio, 180000);
    });

    test('elige shot de anfitriona con su precio y shot de cliente con el suyo', () {
      final anfitriona = resolverVentaProducto(conShotAnfitriona, SaleChoice.shotAnfitriona);
      expect(anfitriona.tipoVenta, SaleChoice.shotAnfitriona);
      expect(anfitriona.esShot, isTrue);
      expect(anfitriona.precio, 3500);
      expect(anfitriona.comision, 0);

      final cliente = resolverVentaProducto(conShotAnfitriona, SaleChoice.shot);
      expect(cliente.tipoVenta, SaleChoice.shot);
      expect(cliente.precio, 6000);
    });

    test('la comisión de la botella no la hereda el shot', () {
      final venta = resolverVentaProducto(conShotAnfitriona, SaleChoice.shot);
      expect(venta.comisionBotella, 5000);
      expect(venta.comision, 0);
    });

    test('cae a la forma más parecida cuando el producto no la ofrece', () {
      // Sin precio de anfitriona no se puede cobrar como anfitriona.
      final sinAnfitriona = resolverVentaProducto(
        {
          'precio': 1000,
          'comision': 0,
          'opciones_venta': [
            {'tipo': 'botella', 'precio': 1000, 'comision': 0},
            {'tipo': 'shot', 'precio': 500, 'comision': 0},
          ],
        },
        SaleChoice.shotAnfitriona,
      );
      expect(sinAnfitriona.tipoVenta, SaleChoice.shot);

      // Sin shot no se vende por ml.
      expect(resolverVentaProducto(soloBotella, SaleChoice.shot).tipoVenta, SaleChoice.botella);
    });

    test('el shot no gasta botellas: tope 99; la botella usa el stock del bar', () {
      expect(resolverVentaProducto(conShotAnfitriona, SaleChoice.shot).maxCantidad, 99);
      expect(
        resolverVentaProducto(conShotAnfitriona, SaleChoice.shotAnfitriona).maxCantidad,
        99,
      );
      expect(resolverVentaProducto(conShotAnfitriona, SaleChoice.botella).maxCantidad, 4);
    });

    test('las opciones llegan también como string JSON', () {
      final venta = resolverVentaProducto({
        'precio': 180000,
        'comision': 5000,
        'stock_bar': 4,
        'opciones_venta':
            '[{"tipo":"botella","precio":180000,"comision":5000},'
            '{"tipo":"shot","precio":6000,"comision":0,"precio_anfitriona":3500}]',
      });

      expect(venta.tieneShot, isTrue);
      expect(venta.tieneShotAnfitriona, isTrue);
    });
  });

  group('SaleChoice', () {
    test('normaliza ids conocidos y desconocidos', () {
      expect(SaleChoice.byId('shot'), SaleChoice.shot);
      expect(SaleChoice.byId('shot_anfitriona'), SaleChoice.shotAnfitriona);
      expect(SaleChoice.byId('otra'), SaleChoice.botella);
      expect(SaleChoice.byId(null), SaleChoice.botella);
    });
  });
}
