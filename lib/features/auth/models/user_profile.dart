// Removed unused imports

enum UserRole {
  owner('OWNER'),
  manager('MANAGER'),
  cashier('CASHIER'),
  inventoryStaff('INVENTORY_STAFF');

  const UserRole(this.value);
  final String value;
}

class UserProfile {
  final String id; // auth.users.id
  final String storeId;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final Map<String, dynamic> permissions;

  final String? googleId;
  final String? facebookId;
  final String? zaloId;

  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.storeId,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.permissions = const {},
    this.googleId,
    this.facebookId,
    this.zaloId,
    this.isActive = true,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOwner => role == UserRole.owner;
  bool get canManageUsers => role == UserRole.owner || role == UserRole.manager;
  bool get canAccessInventory => role != UserRole.cashier;
  bool hasPermission(String permission) => permissions[permission] == true;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: _roleFromString(json['role'] as String?),
      permissions: (json['permissions'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      googleId: json['google_id'] as String?,
      facebookId: json['facebook_id'] as String?,
      zaloId: json['zalo_id'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      lastLoginAt: json['last_login_at'] != null ? DateTime.parse(json['last_login_at']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role.value,
        'permissions': permissions,
        'google_id': googleId,
        'facebook_id': facebookId,
        'zalo_id': zaloId,
        'is_active': isActive,
        'last_login_at': lastLoginAt?.toIso8601String(),
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
