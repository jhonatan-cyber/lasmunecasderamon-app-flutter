
class Venta {
  final int idVenta;
  final String codigo;
  final int estado;
  final double total;
  final double subtotal;
  final String metodoPago;
  final String clienteNombre;
  final String? habitacionNombre;
  final String? fechaCrea;
  final String? usuariosNicks;
  final double? descuento;
  final double? propina;

  Venta({
    required this.idVenta,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.subtotal,
    required this.metodoPago,
    required this.clienteNombre,
    this.habitacionNombre,
    this.fechaCrea,
    this.usuariosNicks,
    this.descuento,
    this.propina,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      idVenta: int.tryParse(json['id_venta']?.toString() ?? '') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '1') ?? 1,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      metodoPago: json['metodo_pago']?.toString().toUpperCase() ?? 'EFECTIVO',
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente General',
      habitacionNombre: json['habitacion_nombre']?.toString(),
      fechaCrea: json['fecha_crea']?.toString(),
      usuariosNicks: json['usuarios_nicks']?.toString(),
      descuento: double.tryParse(json['descuento']?.toString() ?? ''),
      propina: double.tryParse(json['propina']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_venta': idVenta,
        'codigo': codigo,
        'estado': estado,
        'total': total,
        'subtotal': subtotal,
        'metodo_pago': metodoPago,
        'cliente_nombre': clienteNombre,
        if (habitacionNombre != null) 'habitacion_nombre': habitacionNombre,
        if (fechaCrea != null) 'fecha_crea': fechaCrea,
        if (usuariosNicks != null) 'usuarios_nicks': usuariosNicks,
        if (descuento != null) 'descuento': descuento,
        if (propina != null) 'propina': propina,
      };

  Venta copyWith({
    int? idVenta,
    String? codigo,
    int? estado,
    double? total,
    double? subtotal,
    String? metodoPago,
    String? clienteNombre,
    String? habitacionNombre,
    String? fechaCrea,
    String? usuariosNicks,
    double? descuento,
    double? propina,
  }) {
    return Venta(
      idVenta: idVenta ?? this.idVenta,
      codigo: codigo ?? this.codigo,
      estado: estado ?? this.estado,
      total: total ?? this.total,
      subtotal: subtotal ?? this.subtotal,
      metodoPago: metodoPago ?? this.metodoPago,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      habitacionNombre: habitacionNombre ?? this.habitacionNombre,
      fechaCrea: fechaCrea ?? this.fechaCrea,
      usuariosNicks: usuariosNicks ?? this.usuariosNicks,
      descuento: descuento ?? this.descuento,
      propina: propina ?? this.propina,
    );
  }
}


class VentaDetalle {
  final int? id;
  final String productoNombre;
  final int cantidad;
  final double precio;

  VentaDetalle({
    this.id,
    required this.productoNombre,
    required this.cantidad,
    required this.precio,
  });

  factory VentaDetalle.fromJson(Map<String, dynamic> json) {
    return VentaDetalle(
      id: int.tryParse(json['id']?.toString() ?? json['id_detalle']?.toString() ?? ''),
      productoNombre: json['producto_nombre']?.toString() ?? json['nombre']?.toString() ?? 'Producto',
      cantidad: int.tryParse(json['cantidad']?.toString() ?? '1') ?? 1,
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
    );
  }
}


class ComisionDetalle {
  final int usuarioId;
  final String anfitrionaNombre;
  final double montoComision;

  ComisionDetalle({
    required this.usuarioId,
    required this.anfitrionaNombre,
    required this.montoComision,
  });

  factory ComisionDetalle.fromJson(Map<String, dynamic> json) {
    return ComisionDetalle(
      usuarioId: int.tryParse(json['usuario_id']?.toString() ?? '0') ?? 0,
      anfitrionaNombre: json['anfitriona_nombre']?.toString() ?? json['usuario_nombre']?.toString() ?? '',
      montoComision: double.tryParse(json['monto_comision']?.toString() ?? '0') ?? 0.0,
    );
  }
}


class PropinaDetalle {
  final int usuarioId;
  final String usuarioNombre;
  final double montoPropina;

  PropinaDetalle({
    required this.usuarioId,
    required this.usuarioNombre,
    required this.montoPropina,
  });

  factory PropinaDetalle.fromJson(Map<String, dynamic> json) {
    return PropinaDetalle(
      usuarioId: int.tryParse(json['usuario_id']?.toString() ?? '0') ?? 0,
      usuarioNombre: json['usuario_nombre']?.toString() ?? '',
      montoPropina: double.tryParse(json['monto_propina']?.toString() ?? '0') ?? 0.0,
    );
  }
}


class VentaDetail {
  final int idVenta;
  final String codigo;
  final int estado;
  final double total;
  final double subtotal;
  final double descuento;
  final double propina;
  final String metodoPago;
  final String clienteNombre;
  final String? habitacionNombre;
  final String? fechaCrea;
  final int? tiempo;
  final int? pedidoId;
  final String? garzonNombre;
  final List<VentaDetalle> items;

  VentaDetail({
    required this.idVenta,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.subtotal,
    required this.descuento,
    required this.propina,
    required this.metodoPago,
    required this.clienteNombre,
    this.habitacionNombre,
    this.fechaCrea,
    this.tiempo,
    this.pedidoId,
    this.garzonNombre,
    this.items = const [],
  });

  factory VentaDetail.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>?;
    return VentaDetail(
      idVenta: int.tryParse(json['id_venta']?.toString() ?? '') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '1') ?? 1,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      descuento: double.tryParse(json['descuento']?.toString() ?? '0') ?? 0.0,
      propina: double.tryParse(json['propina']?.toString() ?? '0') ?? 0.0,
      metodoPago: json['metodo_pago']?.toString().toUpperCase() ?? 'EFECTIVO',
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente General',
      habitacionNombre: json['habitacion_nombre']?.toString(),
      fechaCrea: json['fecha_crea']?.toString(),
      tiempo: int.tryParse(json['tiempo']?.toString() ?? ''),
      pedidoId: int.tryParse(json['pedido_id']?.toString() ?? ''),
      garzonNombre: json['garzon_nombre']?.toString(),
      items: itemsRaw != null
          ? itemsRaw.map((e) => VentaDetalle.fromJson(e as Map<String, dynamic>)).toList()
          : [],
    );
  }
}


class VentaResumen {
  final double totalVentas;
  final int cantidadVentas;
  final int cantidadAnuladas;

  VentaResumen({
    this.totalVentas = 0,
    this.cantidadVentas = 0,
    this.cantidadAnuladas = 0,
  });

  factory VentaResumen.fromJson(Map<String, dynamic> json) {
    return VentaResumen(
      totalVentas: double.tryParse(json['total_ventas']?.toString() ?? '0') ?? 0.0,
      cantidadVentas: int.tryParse(json['cantidad_ventas']?.toString() ?? '0') ?? 0,
      cantidadAnuladas: int.tryParse(json['cantidad_anuladas']?.toString() ?? '0') ?? 0,
    );
  }
}
