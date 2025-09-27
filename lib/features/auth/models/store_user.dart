import 'user_profile.dart';

class StoreUser {
  final String id; // junction id
  final String storeId;
  final String userId; // auth.users.id
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreUser({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreUser.fromJson(Map<String, dynamic> json) => StoreUser(
        id: json['id'] as String,
        storeId: json['store_id'] as String,
        userId: json['user_id'] as String,
        role: _roleFromString(json['role'] as String?),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'user_id': userId,
        'role': role.value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

UserRole _roleFromString(String? value) {
  switch (value) {
    case 'OWNER':
      return UserRole.owner;
    case 'MANAGER':
      return UserRole.manager;
    case 'CASHIER':
      return UserRole.cashier;
    case 'INVENTORY_STAFF':
      return UserRole.inventoryStaff;
    default:
      return UserRole.cashier;
  }
}
