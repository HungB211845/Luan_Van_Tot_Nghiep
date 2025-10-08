import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../services/secure_storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _isLoading = true;
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    try {
      final isEnabled = await _secureStorage.isBiometricCredentialsStored();
      if (mounted) {
        setState(() {
          _biometricEnabled = isEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🚨 DEBUG: Error loading biometric state: $e');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    
    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: isDesktop ? null : AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          final store = authProvider.currentStore;

          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 800 ? 600.0 : constraints.maxWidth;
              
              return Center(
                child: Container(
                  width: contentWidth,
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 0 : 16,
                      vertical: isDesktop ? 24 : 0,
                    ),
                    children: [
                      if (isDesktop) ...[
                        const Text(
                          'Tài khoản',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 20),

              // Group 1: User Profile (Tappable)
              _buildGroupedList([
                _buildUserProfileTile(
                  context,
                  name: user?.fullName ?? 'Người dùng',
                  email: Supabase.instance.client.auth.currentUser?.email ?? '',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editProfile);
                  },
                ),
              ]),

              const SizedBox(height: 35),

              // Group 2: Store Management
              _buildSectionHeader('CỬA HÀNG'),
              _buildGroupedList([
                _buildMenuTile(
                  icon: CupertinoIcons.building_2_fill,
                  title: 'Thông tin cửa hàng',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.editStoreInfo);
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: CupertinoIcons.person_2_fill,
                  title: 'Quản lý nhân viên',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.employeeManagement);
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: CupertinoIcons.doc_text_fill,
                  title: 'Cài đặt hóa đơn & Thuế',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.invoiceSettings);
                  },
                ),
              ]),

              const SizedBox(height: 35),

              // Group 3: Settings & Security
              _buildSectionHeader('CÀI ĐẶT & BẢO MẬT'),
              _buildGroupedList([
                _buildBiometricToggle(context, authProvider),
                _buildDivider(),
                _buildMenuTile(
                  icon: CupertinoIcons.lock_fill,
                  title: 'Đổi mật khẩu',
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.changePassword),
                ),
              ]),

              const SizedBox(height: 35),

              // Group 4: Actions (Logout & Switch Store)
              _buildGroupedList([
                _buildActionTile(
                  title: 'Đăng xuất',
                  color: Colors.red,
                  onTap: () => _handleLogout(context, authProvider),
                ),
                _buildDivider(),
                _buildActionTile(
                  title: 'Chuyển cửa hàng khác',
                  color: Colors.green,
                  onTap: () => _handleSwitchStore(context, authProvider),
                ),
              ]),

              const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Section Header (like "CỬA HÀNG", "CÀI ĐẶT & BẢO MẬT")
  Widget _buildSectionHeader(String title) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Padding(
      padding: EdgeInsets.only(
        left: isDesktop ? 0 : 16,
        right: isDesktop ? 0 : 16,
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

  // Grouped List Container (white background with rounded corners)
  Widget _buildGroupedList(List<Widget> children) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Container(
      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  // Divider between list items
  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }

  // User Profile Tile (with avatar, name, email, chevron)
  Widget _buildUserProfileTile(
    BuildContext context, {
    required String name,
    required String email,
    required VoidCallback onTap,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Menu Tile (with icon, title, chevron)
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.green, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Biometric Toggle
  Widget _buildBiometricToggle(BuildContext context, AuthProvider authProvider) {
    // Use local state instead of AuthProvider user state
    final isEnabled = _biometricEnabled;

    return FutureBuilder<bool>(
      future: authProvider.isBiometricAvailableAndEnabled(),
      builder: (context, snapshot) {
        final isAvailable = snapshot.data ?? false;
        final isLoading = _isLoading || authProvider.state.isLoading;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.lock_shield_fill,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đăng nhập bằng Face/Touch ID',
                      style: TextStyle(fontSize: 17),
                    ),
                    Text(
                      isAvailable
                          ? 'Bật để cho phép đăng nhập nhanh trên thiết bị này'
                          : 'Thiết bị không hỗ trợ hoặc chưa thiết lập',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : CupertinoSwitch(
                      value: isEnabled,
                      onChanged: isLoading
                          ? null
                          : (value) async {
                              bool success = false;

                              if (value) {
                                // Enable Face ID - need password verification
                                final password = await _showPasswordDialog(context);
                                if (password != null && context.mounted) {
                                  // Get current credentials
                                  final secureStorage = SecureStorageService();
                                  final email = Supabase.instance.client.auth.currentUser?.email;
                                  final storeCode = await secureStorage.getLastStoreCode();

                                  if (email != null && storeCode != null) {
                                    success = await authProvider.enableBiometricWithPassword(
                                      email: email,
                                      password: password,
                                      storeCode: storeCode,
                                    );
                                  } else {
                                    success = false;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Không thể lấy thông tin tài khoản. Vui lòng đăng nhập lại.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } else {
                                // Disable Face ID - direct call
                                success = await authProvider.disableBiometric();
                              }

                              if (context.mounted) {
                                if (success) {
                                  // Update local state immediately
                                  setState(() {
                                    _biometricEnabled = value;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(value ? 'Đã bật đăng nhập sinh trắc học' : 'Đã tắt đăng nhập sinh trắc học'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );

                                } else if (authProvider.state.errorMessage != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi: ${authProvider.state.errorMessage}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
            ],
          ),
        );
      },
    );
  }


  // Action Tile (centered text, colored)
  Widget _buildActionTile({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Show Password Dialog for Face ID Setup
  Future<String?> _showPasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();

    return showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Thiết lập Face ID'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Nhập mật khẩu để xác thực thiết lập Face ID',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: passwordController,
              placeholder: 'Mật khẩu',
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(context, null),
          ),
          CupertinoDialogAction(
            child: const Text('Xác nhận'),
            onPressed: () {
              final password = passwordController.text.trim();
              if (password.isNotEmpty) {
                Navigator.pop(context, password);
              }
            },
          ),
        ],
      ),
    );
  }

  // Handle Logout
  Future<void> _handleLogout(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Đăng xuất'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.signOut();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          RouteNames.login,
          (route) => false,
        );
      }
    }
  }

  // Handle Switch Store
  Future<void> _handleSwitchStore(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Chuyển cửa hàng'),
        content: const Text('Bạn sẽ được đưa về màn hình nhập mã cửa hàng'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: const Text('Chuyển cửa hàng'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.switchStore();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          RouteNames.storeCode,
          (route) => false,
        );
      }
    }
  }
}
