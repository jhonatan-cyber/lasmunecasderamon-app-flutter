
class GratificacionItem {
  final String id;
  final String usuario;
  final String usuarioId;
  final double monto;
  final String descripcion;
  final int estado;
  final String? estadoTexto;
  final DateTime fechaCrea;
  final DateTime? fechaMod;

  const GratificacionItem({
    this.id = '',
    this.usuario = '',
    this.usuarioId = '',
    this.monto = 0.0,
    this.descripcion = '',
    this.estado = 0,
    this.estadoTexto,
    required this.fechaCrea,
    this.fechaMod,
  });

  factory GratificacionItem.fromJson(Map<String, dynamic> json) {
    return GratificacionItem(
      id: (json['id'] ?? '').toString(),
      usuario: json['usuario'] ?? '',
      usuarioId: (json['id_usuario'] ?? json['usuario_id'] ?? '').toString(),
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      descripcion: json['descripcion'] ?? '',
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      estadoTexto: json['estado_texto'],
      fechaCrea: DateTime.tryParse(json['fecha_crea'] ?? json['fecha_hora'] ?? '') ?? DateTime.now(),
      fechaMod: json['fecha_mod'] != null ? DateTime.tryParse(json['fecha_mod']) : null,
    );
  }
}


class GratificacionEmployee {
  final String id;
  final String name;
  final String lastName;
  final String nick;
  final String role;
  final int status;

  const GratificacionEmployee({
    this.id = '',
    this.name = '',
    this.lastName = '',
    this.nick = '',
    this.role = '',
    this.status = 1,
  });

  factory GratificacionEmployee.fromJson(Map<String, dynamic> json) {
    String roleName = '';
    final roleValue = json['role'] ?? json['rol'];
    if (roleValue is String) {
      roleName = roleValue;
    } else if (roleValue is Map && roleValue['name'] is String) {
      roleName = roleValue['name'] as String;
    }

    return GratificacionEmployee(
      id: (json['id'] ?? json['id_usuario'] ?? '').toString(),
      name: json['name'] ?? json['nombre'] ?? '',
      lastName: json['lastName'] ?? json['apellido'] ?? '',
      nick: json['nick'] ?? '',
      role: roleName,
      status: int.tryParse((json['status'] ?? json['estado'] ?? '1').toString()) ?? 1,
    );
  }

  String get fullName => '$name $lastName';
}


extension GratificacionEstadoX on int {
  String get gratLabel {
    switch (this) {
      case 0: return 'Pagado';
      case 1: return 'Por pagar';
      case 2: return 'Pendiente';
      case 3: return 'Rechazada';
      default: return 'Desconocido';
    }
  }

  String get gratFilterValue {
    switch (this) {
      case 2: return 'pendiente';
      case 1: return 'por_pagar';
      case 0: return 'pagado';
      case 3: return 'rechazada';
      default: return '';
    }
  }
}
