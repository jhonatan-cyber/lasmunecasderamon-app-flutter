class Category {
  final String id;
  final String name;
  final int status;
  final int displayOrder;

  Category({
    required this.id,
    required this.name,
    required this.status,
    required this.displayOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      status: json['status'] is int ? json['status'] : int.tryParse(json['status']?.toString() ?? '') ?? 0,
      displayOrder: json['display_order'] is int 
          ? json['display_order'] 
          : int.tryParse(json['display_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'display_order': displayOrder,
    };
  }
}
