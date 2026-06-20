
class Cuenta {
  final int idCuenta;
  final String codigo;
  final int estado;
  final double total;
  final double subtotal;
  final double descuento;
  final String? roomName;
  final String? clienteNombre;
  final String? anfitrionaNombre;
  final String? garzonNombre;
  final String? fechaApertura;
  final String? metodoPago;

  Cuenta({
    required this.idCuenta,
    required this.codigo,
    required this.estado,
    required this.total,
    required this.subtotal,
    this.descuento = 0,
    this.roomName,
    this.clienteNombre,
    this.anfitrionaNombre,
    this.garzonNombre,
    this.fechaApertura,
    this.metodoPago,
  });

  factory Cuenta.fromJson(Map<String, dynamic> json) {
    return Cuenta(
      idCuenta: int.tryParse(json['id_cuenta']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '1') ?? 1,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      descuento: double.tryParse(json['descuento']?.toString() ?? '0') ?? 0.0,
      roomName: json['room_name']?.toString() ?? json['room_number']?.toString(),
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente General',
      anfitrionaNombre: json['anfitriona_nombre']?.toString(),
      garzonNombre: json['garzon_nombre']?.toString(),
      fechaApertura: json['fecha_apertura']?.toString(),
      metodoPago: json['metodo_pago']?.toString(),
    );
  }
}


class CuentaDetalle {
  final int? id;
  final String productoNombre;
  final int cantidad;
  final double precio;

  CuentaDetalle({
    this.id,
    required this.productoNombre,
    required this.cantidad,
    required this.precio,
  });

  factory CuentaDetalle.fromJson(Map<String, dynamic> json) {
    return CuentaDetalle(
      id: int.tryParse(json['id']?.toString() ?? ''),
      productoNombre: json['producto_nombre']?.toString() ?? json['nombre']?.toString() ?? 'Producto',
      cantidad: int.tryParse(json['cantidad']?.toString() ?? '1') ?? 1,
      precio: double.tryParse(json['precio']?.toString() ?? '0') ?? 0.0,
    );
  }
}


class CuentaDetail {
  final int idCuenta;
  final String? roomName;
  final String? clienteNombre;
  final String? anfitrionaNombre;
  final String? garzonNombre;
  final String? fechaApertura;
  final double subtotal;
  final double descuento;
  final double total;
  final List<CuentaDetalle> items;

  CuentaDetail({
    required this.idCuenta,
    this.roomName,
    this.clienteNombre,
    this.anfitrionaNombre,
    this.garzonNombre,
    this.fechaApertura,
    required this.subtotal,
    this.descuento = 0,
    required this.total,
    this.items = const [],
  });

  factory CuentaDetail.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>?;
    return CuentaDetail(
      idCuenta: int.tryParse(json['id_cuenta']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      roomName: json['room_name']?.toString() ?? json['room_number']?.toString(),
      clienteNombre: json['cliente_nombre']?.toString(),
      anfitrionaNombre: json['anfitriona_nombre']?.toString(),
      garzonNombre: json['garzon_nombre']?.toString(),
      fechaApertura: json['fecha_apertura']?.toString(),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      descuento: double.tryParse(json['descuento']?.toString() ?? '0') ?? 0.0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      items: itemsRaw != null
          ? itemsRaw.map((e) => CuentaDetalle.fromJson(e as Map<String, dynamic>)).toList()
          : [],
    );
  }
}


class CuentaResumen {
  final double totalEstimado;
  final int mesasOcupadas;

  CuentaResumen({
    this.totalEstimado = 0,
    this.mesasOcupadas = 0,
  });

  factory CuentaResumen.fromJson(Map<String, dynamic> json) {
    return CuentaResumen(
      totalEstimado: double.tryParse(json['total_estimado']?.toString() ?? '0') ?? 0.0,
      mesasOcupadas: int.tryParse(json['mesas_ocupadas']?.toString() ?? '0') ?? 0,
    );
  }
}
