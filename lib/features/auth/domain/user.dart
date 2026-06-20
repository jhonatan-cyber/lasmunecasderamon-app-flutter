class User {
  final String id;
  final String email;
  final String nombre;
  final String role;
  final String nick;
  final String phone;
  final String address;
  final String estadoCivil;
  final String foto;

  User({
    required this.id,
    required this.email,
    required this.nombre,
    required this.role,
    this.nick = '',
    this.phone = '',
    this.address = '',
    this.estadoCivil = 'Soltero/a',
    this.foto = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String roleName = '';
    final roleValue = json['role'];
    if (roleValue is String) {
      roleName = roleValue;
    } else if (roleValue is Map && roleValue['name'] is String) {
      roleName = roleValue['name'] as String;
    }
    
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      nombre: json['nombre'] ?? json['name'] ?? '',
      role: roleName,
      nick: json['nick']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['telefono']?.toString() ?? '',
      address: json['address']?.toString() ?? json['direccion']?.toString() ?? '',
      estadoCivil: json['maritalStatus']?.toString() ?? json['estado_civil']?.toString() ?? 'Soltero/a',
      foto: json['foto']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'role': role,
      'nick': nick,
      'phone': phone,
      'address': address,
      'maritalStatus': estadoCivil,
      'foto': foto,
    };
  }

  
  bool get isGarzon {
    final r = role.trim().toLowerCase();
    return r.contains('garzon') || r.contains('mesero');
  }

  bool get isHostess {
    final r = role.trim().toLowerCase();
    return r.contains('anfitriona');
  }

  bool get isCajero {
    final r = role.trim().toLowerCase();
    return r == 'cajero' || r == 'cajera';
  }

  bool get isAdmin {
    final r = role.trim().toLowerCase();
    return r.contains('admin') || r.contains('manager') || r.contains('administrador');
  }

  bool get isCajeroOrAdmin => isCajero || isAdmin;
}
