import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'signup_step3_screen.dart';

enum StoreCodeStatus { idle, checking, available, unavailable }

class SignupStep2Screen extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;

  const SignupStep2Screen({
    super.key,
    required this.fullName,
    required this.email,
    required this.password,
  });

  @override
  State<SignupStep2Screen> createState() => _SignupStep2ScreenState();
}

class _SignupStep2ScreenState extends State<SignupStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeCodeController = TextEditingController();
  Timer? _debounce;
  StoreCodeStatus _storeCodeStatus = StoreCodeStatus.idle;
  String _storeCodeError = '';

  static const Color primaryTextColor = Color(0xFF1D1D1F);
  static const FontWeight titleWeight = FontWeight.w600;

  @override
  void initState() {
    super.initState();
    _storeCodeController.addListener(_onStoreCodeChanged);
  }

  @override
  void dispose() {
    _storeCodeController.removeListener(_onStoreCodeChanged);
    _storeNameController.dispose();
    _storeCodeController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onStoreCodeChanged() {
    setState(() => _storeCodeStatus = StoreCodeStatus.idle);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _validateStoreCode);
  }

  Future<void> _validateStoreCode() async {
    final storeCode = _storeCodeController.text.trim();
    if (storeCode.length < 3) {
      setState(() => _storeCodeStatus = StoreCodeStatus.idle);
      return;
    }
    setState(() => _storeCodeStatus = StoreCodeStatus.checking);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.checkStoreCodeAvailability(storeCode);
    if (!mounted) return;
    if (result['isAvailable']) {
      setState(() {
        _storeCodeStatus = StoreCodeStatus.available;
        _storeCodeError = '';
      });
    } else {
      setState(() {
        _storeCodeStatus = StoreCodeStatus.unavailable;
        _storeCodeError = result['message'] ?? 'Mã này đã được sử dụng';
      });
    }
  }

  void _continue() {
    if (_formKey.currentState!.validate() && _storeCodeStatus == StoreCodeStatus.available) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SignupStep3Screen(
            fullName: widget.fullName,
            email: widget.email,
            password: widget.password,
            storeName: _storeNameController.text.trim(),
            storeCode: _storeCodeController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Bước 2/3', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: primaryTextColor)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: primaryTextColor)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thông tin cửa hàng', style: GoogleFonts.inter(fontSize: 32, fontWeight: titleWeight, color: primaryTextColor)),
              const SizedBox(height: 48),
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(labelText: 'Tên cửa hàng của bạn'),
                validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập tên cửa hàng' : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _storeCodeController,
                decoration: InputDecoration(
                  labelText: 'Mã cửa hàng (viết liền, không dấu)',
                  suffixIcon: _buildStatusIcon(),
                  errorText: _storeCodeStatus == StoreCodeStatus.unavailable ? _storeCodeError : null,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập mã cửa hàng';
                  if (v.length < 3) return 'Phải có ít nhất 3 ký tự';
                  if (_storeCodeStatus == StoreCodeStatus.unavailable) return _storeCodeError;
                  return null;
                },
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _storeCodeStatus == StoreCodeStatus.available ? _continue : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Tiếp tục', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_storeCodeStatus) {
      case StoreCodeStatus.checking:
        return const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
      case StoreCodeStatus.available:
        return const Icon(Icons.check_circle, color: Colors.green);
      case StoreCodeStatus.unavailable:
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const SizedBox.shrink();
    }
  }
}
