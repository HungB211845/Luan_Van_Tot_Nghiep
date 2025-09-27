// Removed unused import

enum SubscriptionType { free, premium, enterprise }

class Store {
  final String id;
  final String storeCode;
  final String storeName;
  final String ownerName;
  final String? phone;
  final String? email;
  final String? address;
  final String? businessLicense;
  final String? taxCode;
  final SubscriptionType subscriptionType;
  final DateTime? subscriptionExpiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Store({
    required this.id,
    required this.storeCode,
    required this.storeName,
    required this.ownerName,
    this.phone,
    this.email,
    this.address,
    this.businessLicense,
    this.taxCode,
    required this.subscriptionType,
    this.subscriptionExpiresAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSubscriptionActive => subscriptionExpiresAt?.isAfter(DateTime.now()) ?? false;
  bool get isPremiumStore => subscriptionType != SubscriptionType.free;

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      storeCode: json['store_code'] as String,
      storeName: json['store_name'] as String,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      businessLicense: json['business_license'] as String?,
      taxCode: json['tax_code'] as String?,
      subscriptionType: _subscriptionTypeFromString(json['subscription_type'] as String?),
      subscriptionExpiresAt: json['subscription_expires_at'] != null ? DateTime.parse(json['subscription_expires_at']) : null,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_code': storeCode,
      'store_name': storeName,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'address': address,
      'business_license': businessLicense,
      'tax_code': taxCode,
      'subscription_type': subscriptionType.name,
      'subscription_expires_at': subscriptionExpiresAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

SubscriptionType _subscriptionTypeFromString(String? v) {
  switch (v) {
    case 'premium':
      return SubscriptionType.premium;
    case 'enterprise':
      return SubscriptionType.enterprise;
    default:
      return SubscriptionType.free;
  }
}
