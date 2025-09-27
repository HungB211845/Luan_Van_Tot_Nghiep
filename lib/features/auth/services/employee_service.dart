import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../../../shared/services/base_service.dart';
import '../models/employee_invitation.dart';
import '../models/user_profile.dart';
import '../models/permission.dart';

class EmployeeService extends BaseService {
  
  /// Send invitation to employee via email
  Future<EmployeeInvitation> inviteEmployee({
    required String email,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    requirePermission(Permission.manageUsers);
    
    // Check if email already exists in this store
    final existingUser = await supabase
        .from('user_profiles')
        .select('id')
        .eq('store_id', currentStoreId!)
        .eq('email', email)
        .maybeSingle();
    
    if (existingUser != null) {
      throw Exception('Email đã được sử dụng trong cửa hàng này');
    }
    
    // Check for pending invitation
    final pendingInvite = await supabase
        .from('employee_invitations')
        .select('id')
        .eq('store_id', currentStoreId!)
        .eq('email', email)
        .eq('status', 'PENDING')
        .maybeSingle();
    
    if (pendingInvite != null) {
      throw Exception('Đã có lời mời chờ phê duyệt cho email này');
    }
    
    // Generate invitation token
    final token = _generateInvitationToken();
    
    // Create invitation record
    final data = {
      'store_id': currentStoreId!,
      'email': email,
      'full_name': fullName,
      'invited_by_user_id': supabase.auth.currentUser!.id,
      'role': role.value,
      'phone': phone,
      'status': 'PENDING',
      'invitation_token': token,
      'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    };
    
    final response = await supabase
        .from('employee_invitations')
        .insert(data)
        .select()
        .single();
    
    final invitation = EmployeeInvitation.fromJson(response);
    
    // TODO: Send email notification
    await _sendInvitationEmail(invitation);
    
    return invitation;
  }
  
  /// Accept invitation and create user account
  Future<UserProfile> acceptInvitation({
    required String invitationToken,
    required String password,
  }) async {
    // Find and validate invitation
    final inviteData = await supabase
        .from('employee_invitations')
        .select('*')
        .eq('invitation_token', invitationToken)
        .eq('status', 'PENDING')
        .single();
    
    final invitation = EmployeeInvitation.fromJson(inviteData);
    
    if (invitation.isExpired) {
      throw Exception('Lời mời đã hết hạn');
    }
    
    // Create auth user
    final authResult = await supabase.auth.signUp(
      email: invitation.email,
      password: password,
    );
    
    if (authResult.user == null) {
      throw Exception('Không thể tạo tài khoản');
    }
    
    // Create user profile
    final profileData = {
      'id': authResult.user!.id,
      'store_id': invitation.storeId,
      'full_name': invitation.fullName,
      'phone': invitation.phone,
      'role': invitation.role,
      'permissions': Permission.defaultPermissions[_roleFromString(invitation.role)] ?? [],
      'is_active': true,
    };
    
    final profileResponse = await supabase
        .from('user_profiles')
        .insert(profileData)
        .select()
        .single();
    
    // Update invitation status
    await supabase
        .from('employee_invitations')
        .update({
          'status': 'ACCEPTED',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', invitation.id);
    
    return UserProfile.fromJson(profileResponse);
  }
  
  /// Get all employees in current store
  Future<List<UserProfile>> getStoreEmployees() async {
    requirePermission(Permission.manageUsers);
    
    final response = await supabase
        .from('user_profiles')
        .select('*')
        .eq('store_id', currentStoreId!)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => UserProfile.fromJson(json))
        .toList();
  }
  
  /// Get pending invitations for current store
  Future<List<EmployeeInvitation>> getPendingInvitations() async {
    requirePermission(Permission.manageUsers);
    
    final response = await supabase
        .from('employee_invitations')
        .select('*')
        .eq('store_id', currentStoreId!)
        .eq('status', 'PENDING')
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => EmployeeInvitation.fromJson(json))
        .toList();
  }
  
  /// Update employee role and permissions
  Future<UserProfile> updateEmployeeRole({
    required String userId,
    required UserRole newRole,
    Map<String, bool>? customPermissions,
  }) async {
    requirePermission(Permission.manageUsers);
    
    // Cannot demote store owner
    final targetUser = await supabase
        .from('user_profiles')
        .select('role')
        .eq('id', userId)
        .eq('store_id', currentStoreId!)
        .single();
    
    if (targetUser['role'] == 'OWNER' && newRole != UserRole.owner) {
      throw Exception('Không thể thay đổi quyền của chủ cửa hàng');
    }
    
    final permissions = customPermissions ?? 
        Map.fromEntries(
          (Permission.defaultPermissions[newRole] ?? [])
              .map((p) => MapEntry(p, true))
        );
    
    final response = await supabase
        .from('user_profiles')
        .update({
          'role': newRole.value,
          'permissions': permissions,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .eq('store_id', currentStoreId!)
        .select()
        .single();
    
    return UserProfile.fromJson(response);
  }
  
  /// Deactivate employee (soft delete)
  Future<void> deactivateEmployee(String userId) async {
    requirePermission(Permission.manageUsers);
    
    // Cannot deactivate store owner
    final targetUser = await supabase
        .from('user_profiles')
        .select('role')
        .eq('id', userId)
        .eq('store_id', currentStoreId!)
        .single();
    
    if (targetUser['role'] == 'OWNER') {
      throw Exception('Không thể vô hiệu hóa tài khoản chủ cửa hàng');
    }
    
    await supabase
        .from('user_profiles')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .eq('store_id', currentStoreId!);
  }
  
  /// Cancel pending invitation
  Future<void> cancelInvitation(String invitationId) async {
    requirePermission(Permission.manageUsers);
    
    await supabase
        .from('employee_invitations')
        .update({'status': 'CANCELLED'})
        .eq('id', invitationId)
        .eq('store_id', currentStoreId!);
  }
  
  /// Resend invitation email
  Future<void> resendInvitation(String invitationId) async {
    requirePermission(Permission.manageUsers);
    
    final inviteData = await supabase
        .from('employee_invitations')
        .select('*')
        .eq('id', invitationId)
        .eq('store_id', currentStoreId!)
        .single();
    
    final invitation = EmployeeInvitation.fromJson(inviteData);
    
    if (!invitation.canResend) {
      throw Exception('Không thể gửi lại lời mời này');
    }
    
    // Generate new token and extend expiry
    final newToken = _generateInvitationToken();
    
    await supabase
        .from('employee_invitations')
        .update({
          'invitation_token': newToken,
          'status': 'PENDING',
          'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        })
        .eq('id', invitationId);
    
    // TODO: Send new email
    final updatedInvitation = invitation.copyWith(
      invitationToken: newToken,
      status: InvitationStatus.pending,
    );
    await _sendInvitationEmail(updatedInvitation);
  }
  
  String _generateInvitationToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }
  
  Future<void> _sendInvitationEmail(EmployeeInvitation invitation) async {
    // TODO: Integrate with email service (SendGrid, AWS SES, etc.)
    // For now, just log the invitation details
    print('INVITATION EMAIL:');
    print('To: ${invitation.email}');
    print('Store: ${invitation.storeId}');
    print('Token: ${invitation.invitationToken}');
    print('Expires: ${invitation.expiresAt}');
  }
  
  UserRole _roleFromString(String value) {
    switch (value) {
      case 'OWNER':
        return UserRole.owner;
      case 'MANAGER':
        return UserRole.manager;
      case 'INVENTORY_STAFF':
        return UserRole.inventoryStaff;
      default:
        return UserRole.cashier;
    }
  }
}

// Extension for copying EmployeeInvitation
extension EmployeeInvitationExtension on EmployeeInvitation {
  EmployeeInvitation copyWith({
    String? invitationToken,
    InvitationStatus? status,
    DateTime? expiresAt,
  }) {
    return EmployeeInvitation(
      id: id,
      storeId: storeId,
      email: email,
      fullName: fullName,
      invitedByUserId: invitedByUserId,
      role: role,
      phone: phone,
      status: status ?? this.status,
      invitationToken: invitationToken ?? this.invitationToken,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt,
      createdAt: createdAt,
    );
  }
}