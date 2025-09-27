import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _storeCode = TextEditingController();
  final _storeName = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthProvider>().signUp(
          email: _email.text.trim(),
          password: _password.text,
          storeCode: _storeCode.text.trim(),
          fullName: _fullName.text.trim(),
          storeName: _storeName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đăng ký thành công'),
          content: const Text('Tài khoản và cửa hàng đã được tạo. Bạn có muốn chuyển sang màn hình đăng nhập không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Để sau'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
              },
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthProvider>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký cửa hàng mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v==null||v.isEmpty||!v.contains('@')) ? 'Email không hợp lệ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) => (v==null||v.length<6) ? 'Tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storeCode,
                decoration: const InputDecoration(labelText: 'Mã cửa hàng (ví dụ: abc123)'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập mã cửa hàng' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _storeName,
                decoration: const InputDecoration(labelText: 'Tên cửa hàng'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập tên cửa hàng' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ tên chủ cửa hàng'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập họ tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại (tuỳ chọn)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: state.isLoading ? null : _submit,
                child: Text(state.isLoading ? 'Đang tạo...' : 'Tạo cửa hàng'),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
