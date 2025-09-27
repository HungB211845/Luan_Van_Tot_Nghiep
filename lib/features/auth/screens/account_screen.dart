import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _sessionService = SessionService();
  bool _biometricEnabled = false;
  bool _loadingBio = true;
  final _secure = SecureStorageService();
  bool _rememberFlag = true;
  bool _loadingRemember = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricFlag();
    _loadRememberFlag();
  }

  Future<void> _loadBiometricFlag() async {
    final enabled = await _sessionService.isBiometricEnabledOnThisDevice();
    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled;
      _loadingBio = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _loadingBio = true);
    await _sessionService.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() {
      _biometricEnabled = value;
      _loadingBio = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? 'Đã bật đăng nhập sinh trắc học' : 'Đã tắt đăng nhập sinh trắc học')),
    );
  }

  Future<void> _loadRememberFlag() async {
    final raw = await _secure.read('remember_flag');
    final remember = raw == null ? true : await _secure.getRememberFlag();
    if (!mounted) return;
    setState(() {
      _rememberFlag = remember;
      _loadingRemember = false;
    });
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
    final state = context.watch<AuthProvider>().state;
    final user = state.userProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user?.fullName ?? 'Người dùng'),
              subtitle: Text('Email: ${state.userProfile != null ? 'Đã đăng nhập' : 'Chưa đăng nhập'}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Đăng nhập bằng Face/Touch ID'),
              subtitle: const Text('Bật để cho phép đăng nhập nhanh trên thiết bị này'),
              value: _biometricEnabled,
              onChanged: _loadingBio ? null : _toggleBiometric,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Ghi nhớ email đăng nhập'),
              subtitle: const Text('Lưu email để tự điền ở màn Đăng nhập'),
              value: _rememberFlag,
              onChanged: _loadingRemember ? null : _toggleRemember,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
