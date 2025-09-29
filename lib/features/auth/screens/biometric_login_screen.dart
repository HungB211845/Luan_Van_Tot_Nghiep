import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/services/biometric_service.dart';
import '../../../core/routing/route_names.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen> {
  bool _checking = false;
  String? _error;

  Future<void> _tryBiometric() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      // Use store-aware biometric login (includes biometric authentication)
      final success = await context.read<AuthProvider>().signInWithBiometric();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacementNamed(RouteNames.homeAlias);
      } else {
        final authProvider = context.read<AuthProvider>();
        setState(() => _error = authProvider.state.errorMessage ?? 'Không thể đăng nhập với sinh trắc học.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng sinh trắc học')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.fingerprint, size: 88, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Sử dụng Face ID / Touch ID để đăng nhập nhanh vào AgriPOS',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _checking ? null : _tryBiometric,
              icon: const Icon(Icons.fingerprint),
              label: Text(_checking ? 'Đang xác thực...' : 'Xác thực và đăng nhập'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed(RouteNames.login),
              child: const Text('Đăng nhập thường'),
            ),
          ],
        ),
      ),
    );
  }
}
