import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/secure_storage_service.dart';
import '../../../shared/widgets/grouped_text_fields.dart';
import '../../../shared/utils/responsive.dart';
import '../models/auth_state.dart' as auth;

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



 @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    // 🎯 SỬ DỤNG RESPONSIVE AUTH WRAPPER
    return ResponsiveAuthScaffold(
      title: 'Đăng nhập',
      child: _buildLoginForm(auth),
    );
  }

  Widget _buildLoginForm(AuthProvider auth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.sectionPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: context.formAlignment,
                    children: [
                      context.adaptiveWidget(
                        mobile: const Spacer(flex: 3),
                        tablet: const Spacer(flex: 2),
                        desktop: const SizedBox(height: 60),
                      ),
                      const Icon(Icons.store_mall_directory, color: Colors.green, size: 50),
                      SizedBox(height: context.cardSpacing * 3),
                      Container(
                        constraints: BoxConstraints(maxWidth: context.maxFormWidth),
                        child: Column(
                          crossAxisAlignment: context.formAlignment,
                          children: [
                            Text(
                              _storeName != null ? 'Cửa hàng $_storeName' : 'Đăng Nhập',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: context.adaptiveValue(
                                  mobile: 28.0,
                                  tablet: 32.0,
                                  desktop: 36.0,
                                ),
                                fontWeight: titleWeight,
                                color: primaryTextColor,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: context.cardSpacing * 4),
                            GroupedTextFields(
                              topController: _emailController,
                              bottomController: _passwordController,
                              bottomFocusNode: _passwordFocusNode,
                              isBottomObscured: _obscure,
                              onTopFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                              onBottomFieldSubmitted: (_) => _handleLogin(),
                              topValidator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                              bottomValidator: (v) => (v == null || v.length < 6) ? 'Mật khẩu phải có ít nhất 6 ký tự' : null,
                              bottomSuffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                            if (auth.state.errorMessage != null)
                              Padding(
                                padding: EdgeInsets.only(top: context.cardSpacing * 2),
                                child: Center(
                                  child: Text(
                                    auth.state.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            SizedBox(height: context.cardSpacing * 3),
                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: auth.state.isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: auth.state.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                      )
                                    : Text(
                                        'Đăng nhập',
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      context.adaptiveWidget(
                        mobile: const Spacer(flex: 5),
                        tablet: const Spacer(flex: 3),
                        desktop: const SizedBox(height: 60),
                      ),
                      if (!context.isDesktop) ...[
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
                        SizedBox(height: context.cardSpacing * 2),
                      ],
                      if (context.isDesktop) ...[
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed(RouteNames.forgotPassword),
                              child: Text('Quên mật khẩu?', style: GoogleFonts.inter(color: secondaryTextColor, fontWeight: regularWeight)),
                            ),
                            const Text(' • '),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushNamed(RouteNames.signupStep1),
                              child: Text('Tạo cửa hàng mới', style: GoogleFonts.inter(color: Colors.green.withOpacity(0.9), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
