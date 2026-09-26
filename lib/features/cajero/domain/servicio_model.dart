class Servicio {
  // varchar(36) en el dashboard (UUID): un int dejaba todo servicio en 0.
  final String idServicio;
  final int estado;
  final String? roomName;
  final String? anfitrionaNombre;
  final String? clienteNombre;
  final String? fechaInicio;

  Servicio({
    required this.idServicio,
    required this.estado,
    this.roomName,
    this.anfitrionaNombre,
    this.clienteNombre,
    this.fechaInicio,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      idServicio: (json['id_servicio'] ?? json['id'] ?? '').toString(),
      estado: int.tryParse(json['estado']?.toString() ?? '0') ?? 0,
      roomName: json['room_name']?.toString() ?? json['habitacion_nombre']?.toString() ?? 'Sin Habitación',
      anfitrionaNombre: json['anfitriona_nombre']?.toString(),
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Cliente General',
      fechaInicio: json['fecha_inicio']?.toString(),
    );
  }
}
