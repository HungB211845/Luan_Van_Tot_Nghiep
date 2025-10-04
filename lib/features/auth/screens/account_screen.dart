import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_service.dart';
import '../services/secure_storage_service.dart';
import '../../../core/routing/route_names.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // final _sessionService = SessionService(); // COMMENTED OUT: Unused field
  // COMMENTED OUT: Biometric functionality removed
  // bool _biometricEnabled = false;
  // bool _loadingBio = true;
  final _secure = SecureStorageService();
  bool _rememberFlag = true;
  bool _loadingRemember = true;

  @override
  void initState() {
    super.initState();
    // _loadBiometricFlag(); // COMMENTED OUT: Biometric functionality removed
    _loadRememberFlag();
  }

  // COMMENTED OUT: Biometric functionality removed
  // Future<void> _loadBiometricFlag() async {
  //   final enabled = await _sessionService.isBiometricEnabledOnThisDevice();
  //   if (!mounted) return;
  //   setState(() {
  //     _biometricEnabled = enabled;
  //     _loadingBio = false;
  //   });
  // }

  // COMMENTED OUT: Biometric functionality removed
  // Future<void> _toggleBiometric(bool value) async {
  //   setState(() => _loadingBio = true);
  //   await _sessionService.setBiometricEnabled(value);
  //   if (!mounted) return;
  //   setState(() {
  //     _biometricEnabled = value;
  //     _loadingBio = false;
  //   });
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(content: Text(value ? 'Đã bật đăng nhập sinh trắc học' : 'Đã tắt đăng nhập sinh trắc học')),
  //   );
  // }

  Future<void> _loadRememberFlag() async {
    try {
      final raw = await _secure.read('remember_flag');
      bool remember;
      if (raw == null) {
        // Default to true if no preference is set
        remember = true;
      } else {
        remember = raw.toLowerCase() == 'true';
      }
      if (!mounted) return;
      setState(() {
        _rememberFlag = remember;
        _loadingRemember = false;
      });
    } catch (e) {
      // If there's any error, default to true and stop loading
      debugPrint('Error loading remember flag: $e');
      if (!mounted) return;
      setState(() {
        _rememberFlag = true;
        _loadingRemember = false;
      });
    }
  }

  Future<void> _toggleRemember(bool value) async {
    setState(() => _loadingRemember = true);
    await _secure.setRememberFlag(value);
    if (!value) {
      await _secure.delete('remember_email');
    }
    if (!mounted) return;
    setState(() {
      _rememberFlag = value;
      _loadingRemember = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Đã bật ghi nhớ email' : 'Đã tắt ghi nhớ email')),
    );
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProfile = authProvider.currentUser;
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final storeName = authProvider.currentStore?.storeName ?? 'hiện tại';

    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // User Profile Section
          if (userProfile != null)
            Container(
              color: Colors.white,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    (userProfile.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  userProfile.fullName ?? 'Người dùng',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(supabaseUser?.email ?? 'Chưa đăng nhập'),
                trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                onTap: () {
                  debugPrint('🔍 DEBUG: Navigating to editProfile: ${RouteNames.editProfile}');
                  Navigator.pushNamed(context, RouteNames.editProfile);
                },
              ),
            ),

          const SizedBox(height: 35),

          // Store Group Section
          _buildSectionHeader('CỬA HÀNG'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildListTile(
                  icon: CupertinoIcons.building_2_fill,
                  iconColor: Colors.green,
                  title: 'Thông tin cửa hàng',
                  onTap: () {
                    debugPrint('🔍 DEBUG: Navigating to editStoreInfo: ${RouteNames.editStoreInfo}');
                    Navigator.pushNamed(context, RouteNames.editStoreInfo);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: CupertinoIcons.person_2_fill,
                  iconColor: Colors.green,
                  title: 'Quản lý nhân viên',
                  onTap: () {
                    debugPrint('🔍 DEBUG: Navigating to employeeManagement: ${RouteNames.employeeManagement}');
                    Navigator.pushNamed(context, RouteNames.employeeManagement);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: CupertinoIcons.doc_text_fill,
                  iconColor: Colors.green,
                  title: 'Cài đặt hóa đơn & Thuế',
                  onTap: () {
                    debugPrint('🔍 DEBUG: Navigating to invoiceSettings: ${RouteNames.invoiceSettings}');
                    Navigator.pushNamed(context, RouteNames.invoiceSettings);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          // Settings & Security Section
          _buildSectionHeader('CÀI ĐẶT & BẢO MẬT'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // COMMENTED OUT: Biometric functionality removed
                // SwitchListTile(
                //   title: const Text('Đăng nhập bằng Face/Touch ID'),
                //   subtitle: const Text('Thiết bị không hỗ trợ hoặc chưa thiết lập'),
                //   value: _biometricEnabled,
                //   onChanged: _loadingBio ? null : _toggleBiometric,
                //   secondary: Container(
                //     width: 32,
                //     height: 32,
                //     decoration: BoxDecoration(
                //       color: Colors.green.withOpacity(0.1),
                //       borderRadius: BorderRadius.circular(6),
                //     ),
                //     child: const Icon(CupertinoIcons.lock_shield_fill, color: Colors.green, size: 18),
                //   ),
                // ),
                // const Divider(height: 1, indent: 56),
                SwitchListTile(
                  title: const Text('Ghi nhớ email đăng nhập'),
                  subtitle: const Text('Lưu email để tự điền ở màn Đăng nhập'),
                  value: _rememberFlag,
                  onChanged: _loadingRemember ? null : _toggleRemember,
                  secondary: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(CupertinoIcons.mail_solid, color: Colors.green, size: 18),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: CupertinoIcons.lock_fill,
                  iconColor: Colors.green,
                  title: 'Đổi mật khẩu',
                  onTap: () {
                    debugPrint('🔍 DEBUG: Navigating to changePassword: ${RouteNames.changePassword}');
                    Navigator.pushNamed(context, RouteNames.changePassword);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _showSignOutDialog(context, authProvider),
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _showSwitchStoreDialog(context, authProvider),
                    child: const Text(
                      'Chuyển cửa hàng khác',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title),
      trailing: const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showSignOutDialog(BuildContext context, AuthProvider authProvider) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Đăng xuất'),
        message: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.login,
                  (route) => false,
                );
              }
            },
            child: const Text('Đăng xuất'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }

  void _showSwitchStoreDialog(BuildContext context, AuthProvider authProvider) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Chuyển cửa hàng khác'),
        message: const Text('Bạn sẽ được đăng xuất và quay về màn hình nhập mã cửa hàng.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.switchStore();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.storeCode,
                  (route) => false,
                );
              }
            },
            child: const Text('Tiếp tục'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ),
    );
  }
}