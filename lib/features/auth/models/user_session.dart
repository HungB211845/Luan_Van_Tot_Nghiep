class UserSession {
  final String id;
  final String userId;
  final String deviceId;
  final String? deviceName;
  final DeviceType? deviceType;
  final String? fcmToken;
  final bool isBiometricEnabled;
  final DateTime lastAccessedAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  const UserSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    this.deviceName,
    this.deviceType,
    this.fcmToken,
    this.isBiometricEnabled = false,
    required this.lastAccessedAt,
    required this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String?,
        deviceType: _deviceTypeFromString(json['device_type'] as String?),
        fcmToken: json['fcm_token'] as String?,
        isBiometricEnabled: (json['is_biometric_enabled'] as bool?) ?? false,
        lastAccessedAt: DateTime.parse(json['last_accessed_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'device_id': deviceId,
        'device_name': deviceName,
        'device_type': deviceType?.name,
        'fcm_token': fcmToken,
        'is_biometric_enabled': isBiometricEnabled,
        'last_accessed_at': lastAccessedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

enum DeviceType { mobile, tablet, desktop }

DeviceType? _deviceTypeFromString(String? v) {
  switch (v) {
    case 'mobile':
      return DeviceType.mobile;
    case 'tablet':
      return DeviceType.tablet;
    case 'desktop':
      return DeviceType.desktop;
    default:
      return null;
  }
}
