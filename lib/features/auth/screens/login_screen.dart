import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/secure_storage_service.dart';
import '../models/auth_state.dart';
import '../../../shared/widgets/grouped_text_fields.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passwordFocusNode = FocusNode();
  bool _obscure = true;
  String? _storeName;

  static const Color primaryTextColor = Color(0xFF1D1D1F);
  static const Color secondaryTextColor = Color(0xFF8A8A8E);
  static const FontWeight titleWeight = FontWeight.w600;
  static const FontWeight regularWeight = FontWeight.w400;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final email = await SecureStorageService().getRememberedEmail();
    final storeName = await SecureStorageService().getLastStoreName();
    if (!mounted) return;
    setState(() {
      if (email != null) _emailController.text = email;
      _storeName = storeName;
    });
  }

  Future<void> _handleLogin() async {
    // Unfocus to dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    final storeCode = await SecureStorageService().getLastStoreCode();

    if (storeCode == null || storeCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi: Không tìm thấy mã cửa hàng.'), backgroundColor: Colors.red),
      );
      Navigator.of(context).pushReplacementNamed(RouteNames.storeCode);
      return;
    }

    final ok = await authProvider.signInWithStore(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      storeCode: storeCode,
    );

    if (ok && mounted) {
      await SecureStorageService().storeRememberedEmail(_emailController.text.trim());
      Navigator.of(context).pushReplacementNamed(RouteNames.home);
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.signInWithBiometric();
    if (ok && mounted) {
      Navigator.of(context).pushReplacementNamed(RouteNames.home);
    }
  }

 @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Top spacer for 3:5 ratio
                          const Spacer(flex: 3),

                          // Main content block
                          const Icon(Icons.store_mall_directory, color: Colors.green, size: 50),
                          const SizedBox(height: 24),
                          Text(
                            _storeName != null ? 'Cửa hàng $_storeName' : 'Đăng Nhập',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 32, fontWeight: titleWeight, color: primaryTextColor, height: 1.2),
                          ),
                          const SizedBox(height: 32),
                          GroupedTextFields(
                            topController: _emailController,
                            bottomController: _passwordController,
                            bottomFocusNode: _passwordFocusNode,
                            isBottomObscured: _obscure,
                            onTopFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            onBottomFieldSubmitted: (_) => _handleLogin(), // Login on enter
                            topValidator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                            bottomValidator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
                            bottomSuffixIcon: FutureBuilder<bool>(
                              future: context.read<AuthProvider>().isBiometricAvailableAndEnabled(),
                              builder: (context, snapshot) {
                                final bool biometricAvailable = snapshot.data ?? false;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (biometricAvailable)
                                      IconButton(
                                        icon: const Icon(Icons.fingerprint, color: Colors.green),
                                        onPressed: _handleBiometricLogin,
                                      ),
                                    IconButton(
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[500]),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (auth.state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Center(child: Text(auth.state.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: auth.state.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: auth.state.isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                  : Text('Đăng nhập', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),

                          // Bottom spacer for 3:5 ratio
                          const Spacer(flex: 5),

                          // Bottom-pinned action links
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed(RouteNames.forgotPassword),
                            child: Text('Quên mật khẩu?', style: GoogleFonts.inter(color: secondaryTextColor, fontWeight: regularWeight)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Chưa có tài khoản?', style: GoogleFonts.inter(color: secondaryTextColor, fontWeight: regularWeight)),
                              TextButton(
                                onPressed: () => Navigator.of(context).pushNamed(RouteNames.signupStep1),
                                child: Text('Tạo cửa hàng mới', style: GoogleFonts.inter(color: Colors.green.withOpacity(0.9), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16), // Padding from bottom
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
