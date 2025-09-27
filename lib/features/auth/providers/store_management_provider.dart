import 'package:flutter/foundation.dart';
import '../models/store.dart';
import '../models/user_profile.dart';
import '../models/store_invitation.dart';
import '../services/store_management_service.dart';

enum StoreManagementStatus { idle, loading, success, error }

class StoreManagementProvider extends ChangeNotifier {
  final StoreManagementService _storeService = StoreManagementService();

  StoreManagementStatus _status = StoreManagementStatus.idle;
  String _errorMessage = '';

  Store? _currentStore;
  List<UserProfile> _storeStaff = [];
  List<StoreInvitation> _pendingInvitations = [];
  UserRole? _currentUserRole;

  // Getters
  StoreManagementStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == StoreManagementStatus.loading;
  bool get hasError => _status == StoreManagementStatus.error;

  Store? get currentStore => _currentStore;
  List<UserProfile> get storeStaff => _storeStaff;
  List<StoreInvitation> get pendingInvitations => _pendingInvitations;
  UserRole? get currentUserRole => _currentUserRole;

  /// Load current user's store information
  Future<void> loadCurrentStore() async {
    _setStatus(StoreManagementStatus.loading);

    try {
      _currentStore = await _storeService._authService.getCurrentUserStore();
      _currentUserRole = await _storeService.getCurrentUserRole();
      _setStatus(StoreManagementStatus.success);
    } catch (e) {
      _setError('Không thể tải thông tin cửa hàng: $e');
    }
    notifyListeners();
  }

  /// Load all staff members for current store
  Future<void> loadStoreStaff() async {
    if (_currentStore == null) return;

    _setStatus(StoreManagementStatus.loading);

    try {
      _storeStaff = await _storeService.getStoreStaff(_currentStore!.id);
      _setStatus(StoreManagementStatus.success);
    } catch (e) {
      _setError('Không thể tải danh sách nhân viên: $e');
    }
    notifyListeners();
  }

  /// Invite new staff member to store
  Future<bool> inviteStaff({
    required String email,
    required String fullName,
    required UserRole role,
    String? phone,
    Map<String, dynamic>? permissions,
  }) async {
    if (_currentStore == null) return false;

    _setStatus(StoreManagementStatus.loading);

    try {
      final success = await _storeService.inviteStaffToStore(
        storeId: _currentStore!.id,
        email: email,
        fullName: fullName,
        role: role,
        phone: phone,
        permissions: permissions,
      );

      if (success) {
        await loadStoreStaff(); // Refresh staff list
        _setStatus(StoreManagementStatus.success);
      } else {
        _setError('Không thể gửi lời mời');
      }

      return success;
    } catch (e) {
      _setError('Lỗi gửi lời mời: $e');
      return false;
    }
  }

  /// Update staff member role
  Future<bool> updateStaffRole({
    required String userId,
    required UserRole role,
    Map<String, dynamic>? permissions,
  }) async {
    if (_currentStore == null) return false;

    _setStatus(StoreManagementStatus.loading);

    try {
      final success = await _storeService.updateStaffRole(
        userId: userId,
        storeId: _currentStore!.id,
        role: role,
        permissions: permissions,
      );

      if (success) {
        await loadStoreStaff(); // Refresh staff list
        _setStatus(StoreManagementStatus.success);
      } else {
        _setError('Không thể cập nhật quyền');
      }

      return success;
    } catch (e) {
      _setError('Lỗi cập nhật quyền: $e');
      return false;
    }
  }

  /// Remove staff member from store
  Future<bool> removeStaff(String userId) async {
    if (_currentStore == null) return false;

    _setStatus(StoreManagementStatus.loading);

    try {
      final success = await _storeService.removeStaffFromStore(
        userId,
        _currentStore!.id,
      );

      if (success) {
        await loadStoreStaff(); // Refresh staff list
        _setStatus(StoreManagementStatus.success);
      } else {
        _setError('Không thể xóa nhân viên');
      }

      return success;
    } catch (e) {
      _setError('Lỗi xóa nhân viên: $e');
      return false;
    }
  }

  /// Check if current user has specific permission
  Future<bool> hasPermission(String permission) async {
    return await _storeService.hasPermission(permission);
  }

  /// Check if current user can manage staff
  bool get canManageStaff {
    return _currentUserRole == UserRole.OWNER ||
           _currentUserRole == UserRole.MANAGER;
  }

  /// Check if current user is store owner
  bool get isStoreOwner {
    return _currentUserRole == UserRole.OWNER;
  }

  void _setStatus(StoreManagementStatus status) {
    _status = status;
    if (status != StoreManagementStatus.error) {
      _errorMessage = '';
    }
  }

  void _setError(String message) {
    _status = StoreManagementStatus.error;
    _errorMessage = message;
  }

  void clearError() {
    _errorMessage = '';
    if (_status == StoreManagementStatus.error) {
      _status = StoreManagementStatus.idle;
    }
    notifyListeners();
  }

  /// Reset all data (called on logout)
  void reset() {
    _currentStore = null;
    _storeStaff.clear();
    _pendingInvitations.clear();
    _currentUserRole = null;
    _status = StoreManagementStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }
}