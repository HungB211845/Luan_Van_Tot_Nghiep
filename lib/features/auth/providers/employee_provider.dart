import 'package:flutter/foundation.dart';
import '../services/employee_service.dart';
import '../models/user_profile.dart';
import '../models/employee_invitation.dart';

enum EmployeeStatus { loading, loaded, error }

class EmployeeProvider extends ChangeNotifier {
  final EmployeeService _service = EmployeeService();

  List<UserProfile> _employees = [];
  List<EmployeeInvitation> _pendingInvitations = [];
  EmployeeStatus _status = EmployeeStatus.loading;
  String? _errorMessage;

  List<UserProfile> get employees => _employees;
  List<EmployeeInvitation> get pendingInvitations => _pendingInvitations;
  EmployeeStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == EmployeeStatus.loading;

  /// Load danh sách nhân viên và lời mời
  Future<void> loadEmployees() async {
    _status = EmployeeStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _employees = await _service.getStoreEmployees();
      _pendingInvitations = await _service.getPendingInvitations();
      _status = EmployeeStatus.loaded;
    } catch (e) {
      _status = EmployeeStatus.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Tạo nhân viên mới (manual creation)
  Future<UserProfile> createEmployee({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    // Note: createEmployeeAccount chưa có trong EmployeeService
    // Sẽ throw exception nếu gọi
    throw UnimplementedError('createEmployeeAccount chưa được implement trong EmployeeService');

    // TODO: Uncomment khi đã implement RPC function
    // final newEmployee = await _service.createEmployeeAccount(
    //   email: email,
    //   password: password,
    //   fullName: fullName,
    //   role: role,
    //   phone: phone,
    // );

    // // Optimistic update
    // _employees.insert(0, newEmployee);
    // notifyListeners();

    // return newEmployee;
  }

  /// Reset mật khẩu
  Future<void> resetPassword(String userId, String newPassword) async {
    // TODO: Implement khi có RPC function
    throw UnimplementedError('resetEmployeePassword chưa được implement');

    // await _service.resetEmployeePassword(
    //   userId: userId,
    //   newPassword: newPassword,
    // );
  }

  /// Khóa/mở tài khoản
  Future<void> toggleActive(String userId, bool isActive) async {
    // TODO: Implement khi có RPC function
    throw UnimplementedError('toggleEmployeeActive chưa được implement');

    // await _service.toggleEmployeeActive(
    //   userId: userId,
    //   isActive: isActive,
    // );

    // // Reload để đơn giản
    // await loadEmployees();
  }

  /// Xóa nhân viên
  Future<void> deleteEmployee(String userId) async {
    // TODO: Implement khi có RPC function
    throw UnimplementedError('deleteEmployeeAccount chưa được implement');

    // await _service.deleteEmployeeAccount(userId);

    // // Remove from local state
    // _employees.removeWhere((e) => e.id == userId);
    // notifyListeners();
  }

  /// Gửi lời mời (invitation-based flow - đã có)
  Future<EmployeeInvitation> inviteEmployee({
    required String email,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    final invitation = await _service.inviteEmployee(
      email: email,
      fullName: fullName,
      role: role,
      phone: phone,
    );

    // Add to pending list
    _pendingInvitations.insert(0, invitation);
    notifyListeners();

    return invitation;
  }

  /// Hủy lời mời
  Future<void> cancelInvitation(String invitationId) async {
    await _service.cancelInvitation(invitationId);

    // Remove from pending list
    _pendingInvitations.removeWhere((inv) => inv.id == invitationId);
    notifyListeners();
  }

  /// Gửi lại lời mời
  Future<void> resendInvitation(String invitationId) async {
    await _service.resendInvitation(invitationId);

    // Reload invitations
    await loadEmployees();
  }

  /// Vô hiệu hóa nhân viên (soft delete)
  Future<void> deactivateEmployee(String userId) async {
    await _service.deactivateEmployee(userId);

    // Reload employees
    await loadEmployees();
  }

  /// Cập nhật role của nhân viên
  Future<UserProfile> updateEmployeeRole({
    required String userId,
    required UserRole newRole,
    Map<String, bool>? customPermissions,
  }) async {
    final updatedProfile = await _service.updateEmployeeRole(
      userId: userId,
      newRole: newRole,
      customPermissions: customPermissions,
    );

    // Update local state
    final index = _employees.indexWhere((e) => e.id == userId);
    if (index != -1) {
      _employees[index] = updatedProfile;
      notifyListeners();
    }

    return updatedProfile;
  }
}
