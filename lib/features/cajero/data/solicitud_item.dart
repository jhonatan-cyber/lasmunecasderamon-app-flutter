



class SolicitudItem {
  final String idUnificado;
  final String tipoItem; 
  final String id;
  final String codigo;
  final double monto;
  final String roomName;
  final String solicitadoPor;
  final DateTime fechaOrden;
  final int estado;
  final String motivo;
  final String? fechaMod;

  
  final List<dynamic>? anfitrionasIds;
  final List<dynamic>? anfitrionasConNicks;
  final double? comisionAnfitriona;
  final double? precioServicio;
  final double? precioHabitacion;
  final double? iva;
  final int? tiempo;
  final String? metodoPago;

  SolicitudItem({
    required this.idUnificado,
    required this.tipoItem,
    required this.id,
    required this.codigo,
    required this.monto,
    required this.roomName,
    required this.solicitadoPor,
    required this.fechaOrden,
    required this.estado,
    required this.motivo,
    this.fechaMod,
    this.anfitrionasIds,
    this.anfitrionasConNicks,
    this.comisionAnfitriona,
    this.precioServicio,
    this.precioHabitacion,
    this.iva,
    this.tiempo,
    this.metodoPago,
  });

  factory SolicitudItem.fromService(Map<String, dynamic> json) {
    final id =
        json['id_solicitud']?.toString() ?? json['id']?.toString() ?? '';
    final totalVal =
        double.tryParse(
              json['total']?.toString() ?? json['monto']?.toString() ?? '0',
            ) ??
            0.0;

    return SolicitudItem(
      idUnificado: 'solicitud_$id',
      tipoItem: 'solicitud',
      id: id,
      codigo: json['codigo']?.toString() ?? '#$id',
      monto: totalVal,
      roomName: json['habitacion_nombre']?.toString() ?? 'N/A',
      solicitadoPor:
          json['solicitado_por_nombre']?.toString() ?? 'Desconocido',
      fechaOrden: DateTime.tryParse(
            json['fecha_solicitud']?.toString() ??
                json['fecha_crea']?.toString() ??
                '',
          )?.toLocal() ??
          DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 0,
      motivo: json['motivo_rechazo']?.toString() ?? json['motivo']?.toString() ?? '',
      anfitrionasIds:
          json['anfitrionas_ids'] is List ? json['anfitrionas_ids'] : null,
      anfitrionasConNicks:
          json['anfitrionas_con_nicks'] is List
              ? json['anfitrionas_con_nicks']
              : null,
      comisionAnfitriona:
          double.tryParse(json['comision_anfitriona']?.toString() ?? '0'),
      precioServicio:
          double.tryParse(json['precio_servicio']?.toString() ?? '0'),
      precioHabitacion:
          double.tryParse(json['precio_habitacion']?.toString() ?? '0'),
      iva: double.tryParse(json['iva']?.toString() ?? '0'),
      tiempo:
          int.tryParse(
                json['tiempo']?.toString() ?? json['time']?.toString() ?? '0',
              ) ??
              0,
      metodoPago: json['metodo_pago']?.toString() ?? 'efectivo',
    );
  }

  factory SolicitudItem.fromOrder(Map<String, dynamic> json) {
    final id =
        json['id_pedido']?.toString() ?? json['id']?.toString() ?? '';

    return SolicitudItem(
      idUnificado: 'pedido_$id',
      tipoItem: 'pedido',
      id: id,
      codigo: json['codigo']?.toString() ?? '#$id',
      monto: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      roomName: json['habitacion_nombre']?.toString() ??
          json['mesa']?.toString() ??
          'Mesa/Sala',
      solicitadoPor: json['mesero_nick']?.toString() ??
          json['mesero_nombre']?.toString() ??
          json['garzon']?.toString() ??
          'Desconocido',
      fechaOrden: DateTime.tryParse(json['fecha_crea']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 0,
      motivo: '',
      metodoPago: json['metodo_pago']?.toString(),
    );
  }

  factory SolicitudItem.fromAnticipo(Map<String, dynamic> json) {
    final id =
        json['id_anticipo']?.toString() ?? json['id']?.toString() ?? '';
    final codeVal = json['codigo']?.toString() ??
        'ANT-${id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';
    final userVal = json['usuario']?.toString() ??
        json['nick']?.toString() ??
        '${json['nombre'] ?? json['name'] ?? ''} ${json['apellido'] ?? json['lastName'] ?? ''}'
            .trim();

    return SolicitudItem(
      idUnificado: 'anticipo_$id',
      tipoItem: 'anticipo',
      id: id,
      codigo: codeVal,
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      roomName: 'Anticipo',
      solicitadoPor: userVal.isNotEmpty ? userVal : 'Desconocido',
      fechaOrden: DateTime.tryParse(json['fecha_crea']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      estado: json['estado'] is int ? json['estado'] : 1,
      motivo: json['motivo']?.toString() ?? '',
      fechaMod: json['fecha_mod']?.toString(),
    );
  }
}
