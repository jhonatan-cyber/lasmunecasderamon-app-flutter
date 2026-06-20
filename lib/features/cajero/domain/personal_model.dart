
class UserStaff {
  final String id;
  final String name;
  final String lastName;
  final String nick;
  final String role;
  final String? foto;
  final int status;
  final String? qrToken;

  const UserStaff({
    this.id = '',
    this.name = '',
    this.lastName = '',
    this.nick = '',
    this.role = '',
    this.foto,
    this.status = 1,
    this.qrToken,
  });

  factory UserStaff.fromJson(Map<String, dynamic> json) {
    return UserStaff(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['nombre'] ?? '',
      lastName: json['lastName'] ?? json['apellido'] ?? '',
      nick: json['nick'] ?? json['username'] ?? '',
      role: json['role'] is Map ? (json['role']['name'] ?? '') : (json['role'] ?? ''),
      foto: json['foto'],
      status: json['status'] is int ? json['status'] : 1,
      qrToken: json['qr_token'],
    );
  }

  UserStaff copyWith({String? qrToken}) {
    return UserStaff(
      id: id,
      name: name,
      lastName: lastName,
      nick: nick,
      role: role,
      foto: foto,
      status: status,
      qrToken: qrToken ?? this.qrToken,
    );
  }

  String get fullName => '$name $lastName';

  String get initials {
    final f = name.isNotEmpty ? name[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }
}
