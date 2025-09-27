import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/store.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

/// Service for managing stores and staff assignments
class StoreManagementService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  /// Create a new store with owner assignment
  Future<Store?> createStore({
    required String storeCode,
    required String storeName,
    required String ownerName,
    required String ownerEmail,
    String? phone,
    String? address,
  }) async {
    try {
      // Create store record
      final storeRow = await _supabase
          .from('stores')
          .insert({
            'store_code': storeCode,
            'store_name': storeName,
            'owner_name': ownerName,
            'email': ownerEmail,
            'phone': phone,
            'address': address,
            'is_active': true,
          })
          .select()
          .single();

      return Store.fromJson(storeRow);
    } catch (e) {
      return null;
    }
  }

  /// Get all staff members for a store (only accessible by store owner/manager)
  Future<List<UserProfile>> getStoreStaff(String storeId) async {
    try {
      final staffRows = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return staffRows
          .map<UserProfile>((row) => UserProfile.fromJson(row))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Invite a new staff member to store
  Future<bool> inviteStaffToStore({
    required String storeId,
    required String email,
    required String fullName,
    required UserRole role,
    String? phone,
    Map<String, dynamic>? permissions,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _supabase
          .from('user_profiles')
          .select('id, email')
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        // User exists, assign to store
        return await _authService.assignUserToStore(
          userId: existingUser['id'],
          storeId: storeId,
          role: role.toString().split('.').last,
          permissions: permissions,
        );
      } else {
        // Create invitation record for new user signup
        await _supabase.from('store_invitations').insert({
          'store_id': storeId,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'role': role.toString().split('.').last,
          'permissions': permissions ?? {},
          'invited_at': DateTime.now().toIso8601String(),
          'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        });

        // TODO: Send invitation email
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  /// Accept store invitation (called during signup)
  Future<bool> acceptStoreInvitation(String email, String userId) async {
    try {
      // Find valid invitation
      final invitation = await _supabase
          .from('store_invitations')
          .select('*')
          .eq('email', email)
          .gt('expires_at', DateTime.now().toIso8601String())
          .eq('is_accepted', false)
          .maybeSingle();

      if (invitation == null) return false;

      // Assign user to store
      final success = await _authService.assignUserToStore(
        userId: userId,
        storeId: invitation['store_id'],
        role: invitation['role'],
        permissions: invitation['permissions'],
      );

      if (success) {
        // Mark invitation as accepted
        await _supabase
            .from('store_invitations')
            .update({
              'is_accepted': true,
              'accepted_at': DateTime.now().toIso8601String(),
              'accepted_by': userId,
            })
            .eq('id', invitation['id']);
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Update staff member role/permissions
  Future<bool> updateStaffRole({
    required String userId,
    required String storeId,
    required UserRole role,
    Map<String, dynamic>? permissions,
  }) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'role': role.toString().split('.').last,
            'permissions': permissions ?? {},
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .eq('store_id', storeId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove staff member from store
  Future<bool> removeStaffFromStore(String userId, String storeId) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .eq('store_id', storeId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's role in store
  Future<UserRole?> getCurrentUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await _authService.getUserProfile(user.id);
      if (profile?.role == null) return null;

      return UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == profile!.role,
        orElse: () => UserRole.CASHIER,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if current user has permission to perform action
  Future<bool> hasPermission(String permission) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final profile = await _authService.getUserProfile(user.id);
      if (profile == null) return false;

      // Owner and Manager have all permissions
      if (profile.role == 'OWNER' || profile.role == 'MANAGER') {
        return true;
      }

      // Check specific permission in profile.permissions
      return profile.permissions?[permission] == true;
    } catch (e) {
      return false;
    }
  }
}