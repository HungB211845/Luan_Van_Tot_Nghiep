import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../../../shared/utils/responsive.dart';

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
    
    // 🎯 SỬ DỤNG RESPONSIVE AUTH WRAPPER 
    return ResponsiveAuthScaffold(
      title: 'Đăng ký cửa hàng mới',
      child: _buildRegisterForm(state),
    );
  }

  Widget _buildRegisterForm(AuthState state) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sectionPadding),
      child: Container(
        constraints: BoxConstraints(maxWidth: context.maxFormWidth),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: context.formAlignment,
            children: [
              // RESPONSIVE TITLE
              Text(
                'Tạo cửa hàng mới',
                style: TextStyle(
                  fontSize: context.adaptiveValue(
                    mobile: 24.0,
                    tablet: 28.0,
                    desktop: 32.0,
                  ),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.cardSpacing * 3),
              
              // FORM FIELDS WITH RESPONSIVE SPACING
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v==null||v.isEmpty||!v.contains('@')) ? 'Email không hợp lệ' : null,
              ),
              SizedBox(height: context.cardSpacing * 1.5),
              
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
              SizedBox(height: context.cardSpacing * 1.5),
              
              TextFormField(
                controller: _storeCode,
                decoration: const InputDecoration(labelText: 'Mã cửa hàng (ví dụ: abc123)'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập mã cửa hàng' : null,
              ),
              SizedBox(height: context.cardSpacing * 1.5),
              
              TextFormField(
                controller: _storeName,
                decoration: const InputDecoration(labelText: 'Tên cửa hàng'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập tên cửa hàng' : null,
              ),
              SizedBox(height: context.cardSpacing * 1.5),
              
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Họ tên chủ cửa hàng'),
                validator: (v) => (v==null||v.isEmpty) ? 'Nhập họ tên' : null,
              ),
              SizedBox(height: context.cardSpacing * 1.5),
              
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại (tuỳ chọn)'),
              ),
              SizedBox(height: context.cardSpacing * 3),
              
              // RESPONSIVE BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    state.isLoading ? 'Đang tạo...' : 'Tạo cửa hàng',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              
              if (state.errorMessage != null) ...[
                SizedBox(height: context.cardSpacing * 2),
                Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              
              // RESPONSIVE BOTTOM SPACING
              SizedBox(height: context.adaptiveValue(
                mobile: 16.0,
                tablet: 24.0,
                desktop: 32.0,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
