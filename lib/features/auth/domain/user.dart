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
  final bool forcePasswordChange;

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
    this.forcePasswordChange = false,
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
      forcePasswordChange: json['forcePasswordChange'] == true ||
          json['force_password_change'] == true ||
          json['force_password_change'] == 1,
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
      'forcePasswordChange': forcePasswordChange,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? nombre,
    String? role,
    String? nick,
    String? phone,
    String? address,
    String? estadoCivil,
    String? foto,
    bool? forcePasswordChange,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      role: role ?? this.role,
      nick: nick ?? this.nick,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      estadoCivil: estadoCivil ?? this.estadoCivil,
      foto: foto ?? this.foto,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
    );
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

  bool get isBarman {
    final r = role.trim().toLowerCase();
    return r.contains('barman') || r.contains('bartender');
  }
}
