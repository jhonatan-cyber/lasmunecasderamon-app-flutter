
class CajaInfo {
  final String? idCaja;
  final String? fechaApertura;

  const CajaInfo({this.idCaja, this.fechaApertura});

  factory CajaInfo.fromJson(Map<String, dynamic> json) {
    return CajaInfo(
      idCaja: json['id_caja']?.toString(),
      fechaApertura: json['fecha_apertura']?.toString(),
    );
  }
}


class CajaStats {
  final double balanceTotal;
  final double totalVentas;
  final double totalServicios;
  final double totalEfectivo;
  final double totalTarjeta;
  final double totalTransferencia;
  final double totalIva;
  final double totalComisiones;
  final double totalPropina;
  final double totalAnticipo;
  final double efectivoEnCaja;
  final double montoApertura;
  final int cantidadVentas;
  final int cantidadServicios;
  final double totalDevoluciones;

  const CajaStats({
    this.balanceTotal = 0.0,
    this.totalVentas = 0.0,
    this.totalServicios = 0.0,
    this.totalEfectivo = 0.0,
    this.totalTarjeta = 0.0,
    this.totalTransferencia = 0.0,
    this.totalIva = 0.0,
    this.totalComisiones = 0.0,
    this.totalPropina = 0.0,
    this.totalAnticipo = 0.0,
    this.efectivoEnCaja = 0.0,
    this.montoApertura = 0.0,
    this.cantidadVentas = 0,
    this.cantidadServicios = 0,
    this.totalDevoluciones = 0.0,
  });

  factory CajaStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CajaStats();
    return CajaStats(
      balanceTotal: _parseDouble(json['balance_total']),
      totalVentas: _parseDouble(json['total_ventas']),
      totalServicios: _parseDouble(json['total_servicios']),
      totalEfectivo: _parseDouble(json['total_efectivo']),
      totalTarjeta: _parseDouble(json['total_tarjeta']),
      totalTransferencia: _parseDouble(json['total_transferencia']),
      totalIva: _parseDouble(json['total_iva']),
      totalComisiones: _parseDouble(json['total_comisiones']),
      totalPropina: _parseDouble(json['total_propina']),
      totalAnticipo: _parseDouble(json['total_anticipo']),
      efectivoEnCaja: _parseDouble(json['efectivo_en_caja']),
      montoApertura: _parseDouble(json['monto_apertura']),
      cantidadVentas: _parseInt(json['cantidad_ventas']),
      cantidadServicios: _parseInt(json['cantidad_servicios']),
      totalDevoluciones: _parseDouble(json['total_devoluciones']),
    );
  }

  static double _parseDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  static int _parseInt(dynamic value) =>
      int.tryParse(value?.toString() ?? '0') ?? 0;

  @override
  String toString() =>
      'CajaStats(balanceTotal: $balanceTotal, totalVentas: $totalVentas, ...)';
}
