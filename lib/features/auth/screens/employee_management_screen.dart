import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/employee_provider.dart';
import '../models/user_profile.dart';
import '../models/employee_invitation.dart';
import 'create_employee_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().loadEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Quản lý nhân viên'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateEmployee,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Consumer<EmployeeProvider>(
        builder: (context, provider, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  constraints.maxWidth > 800 ? 600.0 : constraints.maxWidth;

              return Center(
                child: Container(
                  width: contentWidth,
                  child: _buildBody(provider, isDesktop),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(EmployeeProvider provider, bool isDesktop) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.status == EmployeeStatus.error) {
      return _buildErrorState(provider.errorMessage, isDesktop);
    }

    if (provider.employees.isEmpty && provider.pendingInvitations.isEmpty) {
      return _buildEmptyState(isDesktop);
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 0 : 16,
        vertical: isDesktop ? 24 : 16,
      ),
      children: [
        if (isDesktop) ...[
          const Text(
            'Quản lý nhân viên',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quản lý tài khoản nhân viên và phân quyền',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Employee list section
        if (provider.employees.isNotEmpty) ...[
          _buildSectionHeader('NHÂN VIÊN (${provider.employees.length})', isDesktop),
          _buildEmployeeList(provider.employees, isDesktop),
        ],

        if (provider.employees.isNotEmpty &&
            provider.pendingInvitations.isNotEmpty)
          const SizedBox(height: 35),

        // Pending invitations section
        if (provider.pendingInvitations.isNotEmpty) ...[
          _buildSectionHeader(
              'LỜI MỜI CHỜ XỬ LÝ (${provider.pendingInvitations.length})', isDesktop),
          _buildInvitationList(provider.pendingInvitations, isDesktop),
        ],

        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(
        left: isDesktop ? 0 : 0,
        right: isDesktop ? 0 : 0,
        bottom: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  Widget _buildEmployeeList(List<UserProfile> employees, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < employees.length; i++) ...[
            _buildEmployeeTile(employees[i]),
            if (i < employees.length - 1) _buildDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeTile(UserProfile employee) {
    final initial =
        employee.fullName.isNotEmpty ? employee.fullName[0].toUpperCase() : 'N';
    final isOwner = employee.role == UserRole.owner;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to employee detail screen
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _getRoleColor(employee.role),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          employee.fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(employee.role),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.phone ?? 'Chưa có số điện thoại',
                      style: const TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Action menu (không hiển thị cho OWNER)
              if (!isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(
                    CupertinoIcons.ellipsis,
                    color: CupertinoColors.systemGrey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.lock_rotation, size: 20),
                          SizedBox(width: 12),
                          Text('Reset mật khẩu'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            employee.isActive
                                ? CupertinoIcons.xmark_circle
                                : CupertinoIcons.checkmark_circle,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(employee.isActive
                              ? 'Vô hiệu hóa'
                              : 'Kích hoạt'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'change_role',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.person_badge_plus, size: 20),
                          SizedBox(width: 12),
                          Text('Đổi chức vụ'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.trash, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Xóa tài khoản', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) => _handleEmployeeAction(value, employee),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationList(
      List<EmployeeInvitation> invitations, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < invitations.length; i++) ...[
            _buildInvitationTile(invitations[i]),
            if (i < invitations.length - 1) _buildDivider(),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitationTile(EmployeeInvitation invitation) {
    final initial =
        invitation.fullName.isNotEmpty ? invitation.fullName[0].toUpperCase() : 'N';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Show invitation details
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar with pending indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: CupertinoColors.systemGrey3,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invitation.fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Chờ phản hồi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invitation.email,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Action menu
              PopupMenuButton<String>(
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: CupertinoColors.systemGrey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'resend',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.arrow_clockwise, size: 20),
                        SizedBox(width: 12),
                        Text('Gửi lại lời mời'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.xmark_circle,
                            size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Hủy lời mời',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) => _handleInvitationAction(value, invitation),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 72),
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    final config = _getRoleBadgeConfig(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config['bgColor'],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        config['label'],
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config['textColor'],
        ),
      ),
    );
  }

  Map<String, dynamic> _getRoleBadgeConfig(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return {
          'label': 'CHỦ',
          'bgColor': Colors.purple.shade100,
          'textColor': Colors.purple.shade900,
        };
      case UserRole.manager:
        return {
          'label': 'QL',
          'bgColor': Colors.blue.shade100,
          'textColor': Colors.blue.shade900,
        };
      case UserRole.cashier:
        return {
          'label': 'TN',
          'bgColor': Colors.green.shade100,
          'textColor': Colors.green.shade900,
        };
      case UserRole.inventoryStaff:
        return {
          'label': 'KHO',
          'bgColor': Colors.orange.shade100,
          'textColor': Colors.orange.shade900,
        };
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.cashier:
        return Colors.green;
      case UserRole.inventoryStaff:
        return Colors.orange;
    }
  }

  Widget _buildEmptyState(bool isDesktop) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.person_2_fill,
              size: 80,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có nhân viên',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn nút + để thêm nhân viên vào cửa hàng',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? errorMessage, bool isDesktop) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Lỗi tải danh sách',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Đã xảy ra lỗi không xác định',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<EmployeeProvider>().loadEmployees(),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Actions
  void _navigateToCreateEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateEmployeeScreen(),
      ),
    );

    if (result == true && mounted) {
      context.read<EmployeeProvider>().loadEmployees();
    }
  }

  Future<void> _handleEmployeeAction(
      String action, UserProfile employee) async {
    final provider = context.read<EmployeeProvider>();

    switch (action) {
      case 'reset_password':
        final newPassword = await _showPasswordDialog();
        if (newPassword != null && mounted) {
          try {
            await provider.resetPassword(employee.id, newPassword);
            if (mounted) {
              _showSuccessDialog('Đã reset mật khẩu', 'Mật khẩu mới: $newPassword');
            }
          } catch (e) {
            if (mounted) {
              _showErrorDialog(e.toString());
            }
          }
        }
        break;

      case 'toggle_active':
        final confirm = await _showConfirmDialog(
          employee.isActive ? 'Vô hiệu hóa tài khoản?' : 'Kích hoạt tài khoản?',
          employee.isActive
              ? 'Nhân viên sẽ không thể đăng nhập vào hệ thống'
              : 'Nhân viên sẽ có thể đăng nhập trở lại',
        );
        if (confirm == true && mounted) {
          try {
            await provider.toggleActive(employee.id, !employee.isActive);
            if (mounted) {
              _showSnackBar(employee.isActive ? 'Đã vô hiệu hóa' : 'Đã kích hoạt');
            }
          } catch (e) {
            if (mounted) {
              _showErrorDialog(e.toString());
            }
          }
        }
        break;

      case 'change_role':
        _showSnackBar('Chức năng đang phát triển');
        break;

      case 'delete':
        final confirm = await _showConfirmDialog(
          'Xóa tài khoản ${employee.fullName}?',
          'Hành động này không thể hoàn tác',
        );
        if (confirm == true && mounted) {
          try {
            await provider.deleteEmployee(employee.id);
            if (mounted) {
              _showSnackBar('Đã xóa tài khoản');
            }
          } catch (e) {
            if (mounted) {
              _showErrorDialog(e.toString());
            }
          }
        }
        break;
    }
  }

  Future<void> _handleInvitationAction(
      String action, EmployeeInvitation invitation) async {
    final provider = context.read<EmployeeProvider>();

    switch (action) {
      case 'resend':
        try {
          await provider.resendInvitation(invitation.id);
          if (mounted) {
            _showSnackBar('Đã gửi lại lời mời');
          }
        } catch (e) {
          if (mounted) {
            _showErrorDialog(e.toString());
          }
        }
        break;

      case 'cancel':
        final confirm = await _showConfirmDialog(
          'Hủy lời mời?',
          '${invitation.fullName} sẽ không thể tham gia cửa hàng',
        );
        if (confirm == true && mounted) {
          try {
            await provider.cancelInvitation(invitation.id);
            if (mounted) {
              _showSnackBar('Đã hủy lời mời');
            }
          } catch (e) {
            if (mounted) {
              _showErrorDialog(e.toString());
            }
          }
        }
        break;
    }
  }

  // Dialogs
  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Nhập mật khẩu mới'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Mật khẩu mới (tối thiểu 6 ký tự)',
              obscureText: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text('Xác nhận'),
            onPressed: () {
              if (controller.text.length >= 6) {
                Navigator.pop(ctx, controller.text);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Xác nhận'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Đóng'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Đóng'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
