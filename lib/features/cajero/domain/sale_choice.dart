import 'dart:convert';

/// Formas de venta de una presentación del bar (espejo de
/// `lib/sales/saleChoice` del dashboard, que es quien manda: `POST /sales`
/// acepta `tipo_venta` y `shot_anfitriona` en `lib/business/schemas/sale.ts`).

/// Forma de venta elegida: botella entera o shot, a precio de cliente o de
/// anfitriona.
enum SaleChoice {
  botella('botella', 'Botella'),
  shot('shot', 'Shot cliente'),
  shotAnfitriona('shot_anfitriona', 'Shot anfitriona');

  const SaleChoice(this.id, this.nombre);

  /// Valor que viaja en el payload (`tipo_venta` / `shot_anfitriona`).
  final String id;

  /// Etiqueta para el selector y el carrito.
  final String nombre;

  /// Normaliza un id guardado; lo desconocido cae a botella.
  static SaleChoice byId(String? id) => SaleChoice.values.firstWhere(
    (c) => c.id == id,
    orElse: () => SaleChoice.botella,
  );
}

/// Opción guardada en `productos.opciones_venta` (Configuraciones > Bar).
class SaleOption {
  SaleOption({
    required this.tipo,
    required this.precio,
    required this.comision,
    this.precioAnfitriona,
  });

  factory SaleOption.fromJson(Map<String, dynamic> json) {
    final double anfitriona =
        double.tryParse(json['precio_anfitriona']?.toString() ?? '') ?? 0;
    return SaleOption(
      tipo: (json['tipo'] ?? '').toString(),
      precio: double.tryParse(json['precio']?.toString() ?? '') ?? 0,
      comision: double.tryParse(json['comision']?.toString() ?? '') ?? 0,
      precioAnfitriona: anfitriona > 0 ? anfitriona : null,
    );
  }

  final String tipo;
  final double precio;
  final double comision;
  final double? precioAnfitriona;
}

/// `opciones_venta` puede llegar como lista o como el JSON que guarda
/// Configuraciones; sin parsear, el selector no aparecería.
List<SaleOption> parseOpcionesVenta(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return <SaleOption>[];
    try {
      value = jsonDecode(trimmed);
    } catch (_) {
      return <SaleOption>[];
    }
  }
  if (value is! List) return <SaleOption>[];
  return value
      .whereType<Map>()
      .map((o) => SaleOption.fromJson(Map<String, dynamic>.from(o)))
      .where((o) => o.tipo.isNotEmpty)
      .toList();
}

/// Resultado de resolver cómo se vende una presentación.
class VentaResuelta {
  const VentaResuelta({
    required this.opciones,
    required this.tieneShot,
    required this.tieneShotAnfitriona,
    required this.tipoVenta,
    required this.precio,
    required this.comision,
    required this.precioBotella,
    required this.comisionBotella,
    required this.maxCantidad,
  });

  /// Opciones para el selector: botella y, si corresponde, shot de las dos audiencias.
  final List<SaleOption> opciones;
  final bool tieneShot;
  final bool tieneShotAnfitriona;
  final SaleChoice tipoVenta;
  final double precio;
  final double comision;
  final double precioBotella;
  final double comisionBotella;

  /// Tope de unidades: el shot sale de la botella abierta (99) y la botella
  /// usa el stock del bar (0 = catálogo legacy, sin tope declarado).
  final int maxCantidad;

  bool get esShot => tipoVenta != SaleChoice.botella;
}

double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

/// Resuelve las opciones de venta de una presentación. `eleccion` es lo que
/// eligió quien vende; si el producto no ofrece esa forma (sin precio de
/// anfitriona, sin shot), cae a la más parecida en vez de romper.
VentaResuelta resolverVentaProducto(dynamic producto, [SaleChoice? eleccion]) {
  final Map<String, dynamic> product = producto is Map
      ? Map<String, dynamic>.from(producto)
      : <String, dynamic>{};
  final List<SaleOption> opcionesVenta = parseOpcionesVenta(product['opciones_venta']);
  final List<SaleOption> shots = opcionesVenta.where((o) => o.tipo == 'shot').toList();
  final List<SaleOption> botellas = opcionesVenta.where((o) => o.tipo == 'botella').toList();
  final SaleOption? shot = shots.isEmpty ? null : shots.first;
  final SaleOption? botella = botellas.isEmpty ? null : botellas.first;

  final double precioBotella = botella?.precio ?? _num(product['precio'] ?? product['price']);
  final double comisionBotella =
      botella?.comision ?? _num(product['comision'] ?? product['commission']);
  final double precioShotCliente = shot?.precio ?? 0;
  final double comisionShot = shot?.comision ?? 0;
  final double precioAnfitriona = shot?.precioAnfitriona ?? 0;
  final bool tieneShot = shot != null && precioShotCliente > 0;
  final bool tieneShotAnfitriona = tieneShot && precioAnfitriona > 0;

  final List<SaleOption> opciones = <SaleOption>[
    SaleOption(tipo: 'botella', precio: precioBotella, comision: comisionBotella),
    if (tieneShot)
      SaleOption(tipo: 'shot', precio: precioShotCliente, comision: comisionShot),
    if (tieneShotAnfitriona)
      SaleOption(
        tipo: 'shot_anfitriona',
        precio: precioAnfitriona,
        comision: comisionShot,
      ),
  ];

  final SaleChoice tipoVenta;
  if (eleccion == SaleChoice.shotAnfitriona && tieneShotAnfitriona) {
    tipoVenta = SaleChoice.shotAnfitriona;
  } else if ((eleccion == SaleChoice.shot || eleccion == SaleChoice.shotAnfitriona) &&
      tieneShot) {
    tipoVenta = SaleChoice.shot;
  } else {
    tipoVenta = SaleChoice.botella;
  }

  final SaleOption elegida = opciones.firstWhere(
    (o) => o.tipo == tipoVenta.id,
    orElse: () => opciones.first,
  );
  final int maxCantidad = elegida.tipo == 'botella'
      ? (int.tryParse(product['stock_bar']?.toString() ?? '') ?? 0)
      : 99;

  return VentaResuelta(
    opciones: opciones,
    tieneShot: tieneShot,
    tieneShotAnfitriona: tieneShotAnfitriona,
    tipoVenta: tipoVenta,
    precio: elegida.precio,
    comision: elegida.comision,
    precioBotella: precioBotella,
    comisionBotella: comisionBotella,
    maxCantidad: maxCantidad,
  );
}
