
class Client {
  final String id;
  final String run;
  final String name;
  final String lastName;
  final String phone;
  final double saldo;
  final double deuda;
  final int status;

  const Client({
    this.id = '',
    this.run = '',
    this.name = '',
    this.lastName = '',
    this.phone = '',
    this.saldo = 0.0,
    this.deuda = 0.0,
    this.status = 1,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id']?.toString() ?? '',
      run: json['run']?.toString() ?? json['rut']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nombre']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['apellido']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['telefono']?.toString() ?? '',
      saldo: double.tryParse(json['saldo']?.toString() ?? '0') ?? 0.0,
      deuda: double.tryParse(json['deuda']?.toString() ?? '0') ?? 0.0,
      status: json['status'] is int ? json['status'] : 1,
    );
  }

  String get fullName => '$name $lastName';
}


class ClientHistory {
  final String id;
  final String category; 
  final double monto;
  final String metodoPago;
  final DateTime fechaCrea;
  final String motivo;
  final Map<String, dynamic>? detalle;

  const ClientHistory({
    this.id = '',
    this.category = '',
    this.monto = 0.0,
    this.metodoPago = '',
    required this.fechaCrea,
    this.motivo = '',
    this.detalle,
  });

  factory ClientHistory.fromJson(Map<String, dynamic> json) {
    return ClientHistory(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      metodoPago: json['metodo_pago']?.toString() ?? json['metodoPago']?.toString() ?? '',
      fechaCrea: DateTime.tryParse(
            json['fecha_crea']?.toString() ?? json['fechaCrea']?.toString() ?? '',
          ) ??
          DateTime.now(),
      motivo: json['motivo']?.toString() ?? '',
      detalle: json['detalle'] is Map ? Map<String, dynamic>.from(json['detalle']) : null,
    );
  }
}
