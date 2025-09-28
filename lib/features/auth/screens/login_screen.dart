import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/oauth_service.dart';
import '../services/secure_storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storeCodeController = TextEditingController(); // ADD: Store code field
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _rememberMe = false;
  final _oauth = OAuthService();
  final _secure = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _restoreRemembered();
  }

  Future<void> _restoreRemembered() async {
    // If flag not set yet, default to true on first run
    final raw = await _secure.read('remember_flag');
    final remember = raw == null ? true : await _secure.getRememberFlag();
    if (raw == null) {
      await _secure.setRememberFlag(true);
    }
    final email = await _secure.getRememberedEmail();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && (email ?? '').isNotEmpty) {
        _emailController.text = email!;
      }
    });
  }

  Future<void> _onRememberChanged(bool? v) async {
    final newVal = v ?? false;
    setState(() => _rememberMe = newVal);
    await _secure.setRememberFlag(newVal);
    if (newVal) {
      // Immediately persist current email if any and notify user
      final email = _emailController.text.trim();
      if (email.isNotEmpty) {
        await _secure.storeRememberedEmail(email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu email đăng nhập')),
      );
    }
  }

  Future<void> _clearRememberedEmail() async {
    await _secure.delete('remember_email');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa email đã lưu')),
    );
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthProvider>().signInWithStore(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      storeCode: _storeCodeController.text.trim(), // ADD: Store code validation
    );
    if (!mounted) return;
    if (ok) {
      // handle remember me
      if (_rememberMe) {
        await _secure.setRememberFlag(true);
        await _secure.storeRememberedEmail(_emailController.text.trim());
      } else {
        await _secure.setRememberFlag(false);
        await _secure.delete('remember_email');
      }
      Navigator.of(context).pushReplacementNamed(RouteNames.homeAlias);
    }
  }

  Future<void> _handleBiometricLogin() async {
    // Điều hướng tới màn BiometricLogin hoặc xác thực trực tiếp nếu muốn.
    Navigator.of(context).pushNamed(RouteNames.biometricLogin);
  }

  Future<void> _handleGoogle() async {
    final res = await _oauth.signInWithGoogle();
    if (!mounted) return;
    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Đăng nhập Google thất bại')),
      );
    } else {
      // OAuth sẽ quay lại app qua deep link, Splash/AuthProvider sẽ xử lý session.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang mở Google để xác thực...')),
      );
    }
  }

  Future<void> _handleFacebook() async {
    final res = await _oauth.signInWithFacebook();
    if (!mounted) return;
    if (!res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.errorMessage ?? 'Đăng nhập Facebook thất bại')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang mở Facebook để xác thực...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>().state;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Welcome Back',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Hey! Rất vui được gặp lại bạn',
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Store Code
                _RoundedField(
                  controller: _storeCodeController,
                  hint: 'Mã cửa hàng (ví dụ: ABC123)',
                  keyboardType: TextInputType.text,
                  prefixIcon: Icons.store_outlined,
                  validator: (v) => (v==null||v.isEmpty||v.length<3) ? 'Mã cửa hàng không hợp lệ' : null,
                ),
                const SizedBox(height: 14),

                // Email
                _RoundedField(
                  controller: _emailController,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) => (v==null||v.isEmpty||!v.contains('@')) ? 'Email không hợp lệ' : null,
                ),
                const SizedBox(height: 14),

                // Password
                _RoundedField(
                  controller: _passwordController,
                  hint: 'Mật khẩu',
                  prefixIcon: Icons.lock_outline,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) => (v==null||v.length<6) ? 'Tối thiểu 6 ký tự' : null,
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed(RouteNames.forgotPassword),
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),

                const SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: _onRememberChanged,
                    ),
                    const Text('Ghi nhớ tôi'),
                  ],
                ),

                // Description + quick clear button
                Padding(
                  padding: const EdgeInsets.only(left: 12.0, bottom: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Nếu bật, email của bạn sẽ được lưu an toàn để tự điền lần sau.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearRememberedEmail,
                        child: const Text('Xóa email đã lưu'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text(auth.isLoading ? 'Đang đăng nhập...' : 'Đăng nhập'),
                  ),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _handleBiometricLogin,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Đăng nhập bằng sinh trắc học'),
                  ),
                ),

                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
                ],

                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('hoặc'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: auth.isLoading ? null : _handleGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: auth.isLoading ? null : _handleFacebook,
                        icon: const Icon(Icons.facebook, size: 20),
                        label: const Text('Facebook'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamed(RouteNames.register),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    child: const Text('Sign Up'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _RoundedField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.keyboardType,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(prefixIcon),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.purple),
        ),
      ),
    );
  }
}
