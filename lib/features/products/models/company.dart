// lib/models/company.dart

class Company {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? note;
  final String storeId; // Add storeId
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Metadata fields (optional)
  final int? productsCount;
  final int? ordersCount;

  Company({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.note,
    required this.storeId, // Add storeId
    this.createdAt,
    this.updatedAt,
    this.productsCount,
    this.ordersCount,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      contactPerson: json['contact_person'],
      note: json['note'],
      storeId: json['store_id'], // Add storeId
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      productsCount: json['products_count'],
      ordersCount: json['orders_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // không gửi id, createdAt, updatedAt vì chúng được quản lý bởi DB
      'name': name,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
      'note': note,
      'store_id': storeId, // Add storeId
    };
  }

  // Helper getters
  bool get hasProducts => (productsCount ?? 0) > 0;
  bool get hasOrders => (ordersCount ?? 0) > 0;
}
