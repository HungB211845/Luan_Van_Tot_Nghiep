// lib/models/company.dart

class Company {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Company({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      contactPerson: json['contact_person'],
      note: json['note'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
    };
  }
}
