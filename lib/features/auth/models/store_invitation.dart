import '../models/user_profile.dart';

class StoreInvitation {
  final String id;
  final String storeId;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final Map<String, dynamic> permissions;
  final DateTime invitedAt;
  final String? invitedBy;
  final DateTime expiresAt;
  final bool isAccepted;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  StoreInvitation({
    required this.id,
    required this.storeId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    required this.permissions,
    required this.invitedAt,
    this.invitedBy,
    required this.expiresAt,
    required this.isAccepted,
    this.acceptedAt,
    this.acceptedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreInvitation.fromJson(Map<String, dynamic> json) {
    return StoreInvitation(
      id: json['id'],
      storeId: json['store_id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (r) => r.toString().split('.').last == json['role'],
        orElse: () => UserRole.cashier,
      ),
      permissions: Map<String, dynamic>.from(json['permissions'] ?? {}),
      invitedAt: DateTime.parse(json['invited_at']),
      invitedBy: json['invited_by'],
      expiresAt: DateTime.parse(json['expires_at']),
      isAccepted: json['is_accepted'] ?? false,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      acceptedBy: json['accepted_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role.toString().split('.').last,
      'permissions': permissions,
      'invited_at': invitedAt.toIso8601String(),
      'invited_by': invitedBy,
      'expires_at': expiresAt.toIso8601String(),
      'is_accepted': isAccepted,
      'accepted_at': acceptedAt?.toIso8601String(),
      'accepted_by': acceptedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if invitation is still valid
  bool get isValid => !isAccepted && expiresAt.isAfter(DateTime.now());

  /// Check if invitation has expired
  bool get isExpired => expiresAt.isBefore(DateTime.now());

  /// Get role display name in Vietnamese
  String get roleDisplayName {
    switch (role) {
      case UserRole.owner:
        return 'Chủ cửa hàng';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.cashier:
        return 'Thu ngân';
      case UserRole.inventoryStaff:
        return 'Nhân viên kho';
    }
  }

  StoreInvitation copyWith({
    String? id,
    String? storeId,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    Map<String, dynamic>? permissions,
    DateTime? invitedAt,
    String? invitedBy,
    DateTime? expiresAt,
    bool? isAccepted,
    DateTime? acceptedAt,
    String? acceptedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreInvitation(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      invitedAt: invitedAt ?? this.invitedAt,
      invitedBy: invitedBy ?? this.invitedBy,
      expiresAt: expiresAt ?? this.expiresAt,
      isAccepted: isAccepted ?? this.isAccepted,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}