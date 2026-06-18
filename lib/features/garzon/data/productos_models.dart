// ─────────────────────────────────────────────────────────────────────────────
// Helper models for local dropdowns/modales
// ─────────────────────────────────────────────────────────────────────────────

class LocalHostess {
  final String id;
  final String nick;
  final String name;

  LocalHostess({required this.id, required this.nick, required this.name});

  factory LocalHostess.fromMap(Map<String, dynamic> map) {
    return LocalHostess(
      id: map['id']?.toString() ?? '',
      nick: map['nick'] ?? map['name'] ?? 'Anfitriona',
      name: map['name'] ?? '',
    );
  }
}

class LocalRoom {
  final String id;
  final String name;

  LocalRoom({required this.id, required this.name});

  factory LocalRoom.fromMap(Map<String, dynamic> map) {
    return LocalRoom(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? 'HabitaciÃ³n',
    );
  }
}

class LocalClient {
  final String id;
  final String name;
  final String lastName;

  LocalClient(
      {required this.id, required this.name, required this.lastName});

  factory LocalClient.fromMap(Map<String, dynamic> map) {
    return LocalClient(
      id: map['id']?.toString() ?? map['id_cliente']?.toString() ?? '',
      name: map['name'] ?? map['nombre'] ?? '',
      lastName: map['lastName'] ?? map['apellido'] ?? '',
    );
  }

  String get fullName => '$name $lastName'.trim();
}
