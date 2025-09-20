// lib/models/company.dart

class Company {
  final String id; // Đây là UUID thật từ Supabase
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      address: json['address'],
      contactPerson: json['contact_person'],
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // toJson không thực sự cần thiết nếu mày không tạo/cập nhật company từ app
  // nhưng có sẵn cũng tốt.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'contact_person': contactPerson,
      'note': note,
    };
  }
}
