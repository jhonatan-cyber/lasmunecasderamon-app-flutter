



class FinancialEvent {
  final String id;
  final int? idComision;
  final int? idDetallePropina;
  final String? codigo;
  final String? codigoVenta;
  final double monto;
  final double? comision;
  final String fechaCrea;
  final String? fechaMod;
  final String? propinaFechaCrea;
  final int estado; 
  final String tipo; 
  final String? subType;
  final String? clienteNombre;
  final String? habitacionNombre;
  final dynamic productos;
  final int? propinaId;

  const FinancialEvent({
    required this.id,
    this.idComision,
    this.idDetallePropina,
    this.codigo,
    this.codigoVenta,
    required this.monto,
    this.comision,
    required this.fechaCrea,
    this.fechaMod,
    this.propinaFechaCrea,
    required this.estado,
    required this.tipo,
    this.subType,
    this.clienteNombre,
    this.habitacionNombre,
    this.productos,
    this.propinaId,
  });

  factory FinancialEvent.fromJson(Map<String, dynamic> json) {
    return FinancialEvent(
      id: (json['id'] ?? '').toString(),
      idComision: json['id_comision'] as int?,
      idDetallePropina: json['id_detalle_propina'] as int?,
      codigo: json['codigo'] as String?,
      codigoVenta: json['codigo_venta'] as String?,
      monto: (json['monto'] ?? 0).toDouble(),
      comision: (json['comision'] as num?)?.toDouble(),
      fechaCrea: json['fecha_crea'] as String? ?? '',
      fechaMod: json['fecha_mod'] as String?,
      propinaFechaCrea: json['propina_fecha_crea'] as String?,
      estado: json['estado'] as int? ?? 1,
      tipo: json['tipo'] as String? ?? 'otro',
      subType: json['subType'] as String?,
      clienteNombre: json['cliente_nombre'] as String?,
      habitacionNombre: json['habitacion_nombre'] as String?,
      productos: json['productos'],
      propinaId: json['propina_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (idComision != null) 'id_comision': idComision,
        if (idDetallePropina != null) 'id_detalle_propina': idDetallePropina,
        if (codigo != null) 'codigo': codigo,
        if (codigoVenta != null) 'codigo_venta': codigoVenta,
        'monto': monto,
        if (comision != null) 'comision': comision,
        'fecha_crea': fechaCrea,
        if (fechaMod != null) 'fecha_mod': fechaMod,
        if (propinaFechaCrea != null) 'propina_fecha_crea': propinaFechaCrea,
        'estado': estado,
        'tipo': tipo,
        if (subType != null) 'subType': subType,
        if (clienteNombre != null) 'cliente_nombre': clienteNombre,
        if (habitacionNombre != null) 'habitacion_nombre': habitacionNombre,
        if (propinaId != null) 'propina_id': propinaId,
      };

  
  String get estadoLabel => estado == 0 ? 'Pagado' : 'Pendiente';

  
  bool get isPagado => estado == 0;

  
  bool get isPendiente => estado == 1;
}
