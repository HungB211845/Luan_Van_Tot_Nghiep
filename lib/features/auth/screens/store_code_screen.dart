import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/routing/route_names.dart';
import '../models/auth_state.dart';

class StoreCodeScreen extends StatefulWidget {
  const StoreCodeScreen({super.key});

  @override
  State<StoreCodeScreen> createState() => _StoreCodeScreenState();
}

class _StoreCodeScreenState extends State<StoreCodeScreen> {
  final _storeCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _storeCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    final storeCode = _storeCodeController.text.trim();

    final store = await authProvider.validateAndSetStore(storeCode);

    if (store != null && mounted) {
      // On success, navigate to the actual login screen
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
    } 
    // Error is handled by the provider and will be shown on the UI if any
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TODO: Replace with actual Logo widget
                  const Icon(Icons.store_mall_directory, color: Colors.green, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Chào mừng đến với AgriPOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vui lòng nhập mã cửa hàng của bạn để tiếp tục',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _storeCodeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: 3),
                    decoration: const InputDecoration(
                      labelText: 'Mã cửa hàng',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Mã cửa hàng không được để trống';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (auth.state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        auth.state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.state.isLoading ? null : _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: auth.state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Tiếp tục', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
