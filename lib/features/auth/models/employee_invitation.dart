enum InvitationStatus { 
  pending('PENDING'), 
  accepted('ACCEPTED'), 
  expired('EXPIRED'),
  cancelled('CANCELLED');
  
  const InvitationStatus(this.value);
  final String value;
}

class EmployeeInvitation {
  final String id;
  final String storeId;
  final String email;
  final String fullName;
  final String invitedByUserId;
  final String role;
  final String? phone;
  final InvitationStatus status;
  final String invitationToken;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const EmployeeInvitation({
    required this.id,
    required this.storeId,
    required this.email,
    required this.fullName,
    required this.invitedByUserId,
    required this.role,
    this.phone,
    required this.status,
    required this.invitationToken,
    required this.expiresAt,
    this.acceptedAt,
    required this.createdAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == InvitationStatus.pending && !isExpired;
  bool get canResend => status == InvitationStatus.expired || status == InvitationStatus.cancelled;

  factory EmployeeInvitation.fromJson(Map<String, dynamic> json) {
    return EmployeeInvitation(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      invitedByUserId: json['invited_by_user_id'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      status: _statusFromString(json['status'] as String?),
      invitationToken: json['invitation_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'email': email,
        'full_name': fullName,
        'invited_by_user_id': invitedByUserId,
        'role': role,
        'phone': phone,
        'status': status.value,
        'invitation_token': invitationToken,
        'expires_at': expiresAt.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}

InvitationStatus _statusFromString(String? value) {
  switch (value) {
    case 'ACCEPTED':
      return InvitationStatus.accepted;
    case 'EXPIRED':
      return InvitationStatus.expired;
    case 'CANCELLED':
      return InvitationStatus.cancelled;
    default:
      return InvitationStatus.pending;
  }
}