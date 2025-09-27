class Customer {
  final String id;
  final String storeId; // ADD: For multi-tenant isolation
  final String name;
  final String? phone;
  final String? address;
  final double debtLimit;
  final double interestRate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.storeId, // ADD: Required field
    required this.name,
    this.phone,
    this.address,
    required this.debtLimit,
    required this.interestRate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      storeId: json['store_id'], // ADD: Map store_id field
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      debtLimit: (json['debt_limit'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0.5).toDouble(),
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'debt_limit': debtLimit,
      'interest_rate': interestRate,
      'note': note,
      'store_id': storeId, // Add storeId
    };
  }

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    double? debtLimit,
    double? interestRate,
    String? note,
  }) {
    return Customer(
      id: id,
      storeId: storeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      debtLimit: debtLimit ?? this.debtLimit,
      interestRate: interestRate ?? this.interestRate,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}