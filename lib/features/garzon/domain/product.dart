class Product {
  final String id;
  final String code;
  final String name;
  final String categoryId;
  final double price;
  final double commission;
  final String description;
  final int status;
  final String foto;
  final String categoria;

  Product({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.commission,
    required this.description,
    required this.status,
    required this.foto,
    required this.categoria,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      commission: json['commission'] is num ? (json['commission'] as num).toDouble() : double.tryParse(json['commission']?.toString() ?? '') ?? 0.0,
      description: json['description'] ?? '',
      status: json['status'] is int ? json['status'] : int.tryParse(json['status']?.toString() ?? '') ?? 0,
      foto: json['foto'] ?? '',
      categoria: json['categoria'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category_id': categoryId,
      'price': price,
      'commission': commission,
      'description': description,
      'status': status,
      'foto': foto,
      'categoria': categoria,
    };
  }
}
