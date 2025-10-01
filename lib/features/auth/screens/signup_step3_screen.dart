import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/route_names.dart';
import '../providers/auth_provider.dart';

class SignupStep3Screen extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;
  final String storeName;
  final String storeCode;

  const SignupStep3Screen({
    super.key,
    required this.fullName,
    required this.email,
    required this.password,
    required this.storeName,
    required this.storeCode,
  });

  @override
  State<SignupStep3Screen> createState() => _SignupStep3ScreenState();
}

class _SignupStep3ScreenState extends State<SignupStep3Screen> {
  final _phoneController = TextEditingController();

  static const Color primaryTextColor = Color(0xFF1D1D1F);
  static const FontWeight titleWeight = FontWeight.w600;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _finishSignup() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      email: widget.email,
      password: widget.password,
      storeCode: widget.storeCode,
      fullName: widget.fullName,
      storeName: widget.storeName,
      phone: _phoneController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Bước 3/3', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: primaryTextColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: primaryTextColor)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gần xong rồi!', style: GoogleFonts.inter(fontSize: 32, fontWeight: titleWeight, color: primaryTextColor)),
            const SizedBox(height: 12),
            Text('Bạn có thể bỏ qua bước này và cập nhật thông tin sau trong phần tài khoản.', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5)),
            const SizedBox(height: 48),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Số điện thoại (tùy chọn)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.state.isLoading ? null : _finishSignup,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: auth.state.isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text('Hoàn tất & Đăng nhập', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            if (auth.state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(auth.state.errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              )
          ],
        ),
      ),
    );
  }
}
