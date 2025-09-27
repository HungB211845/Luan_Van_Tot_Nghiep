import 'package:flutter/material.dart';
import '../../auth/services/session_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final _sessionService = SessionService();
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _sessionService.isBiometricEnabledOnThisDevice();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _loading = true);
    await _sessionService.setBiometricEnabled(value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập sinh trắc học')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bật Face/Touch ID để đăng nhập nhanh trên thiết bị này.'),
            const SizedBox(height: 16),
            Card(
              child: SwitchListTile(
                title: const Text('Đăng nhập bằng Face/Touch ID'),
                value: _enabled,
                onChanged: _loading ? null : _toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
