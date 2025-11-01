import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/employee_provider.dart';
import '../models/user_profile.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _selectedRole = UserRole.cashier;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Thêm nhân viên'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth =
              constraints.maxWidth > 600 ? 500.0 : constraints.maxWidth;

          return Center(
            child: Container(
              width: contentWidth,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 0 : 16,
                    vertical: isDesktop ? 24 : 16,
                  ),
                  children: [
                    if (isDesktop) ...[
                      const Text(
                        'Thêm nhân viên',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tạo tài khoản mới cho nhân viên trong cửa hàng',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Form fields section
                    _buildSectionHeader('THÔNG TIN CƠ BẢN'),
                    _buildGroupedInputs([
                      _buildTextInput(
                        controller: _emailController,
                        placeholder: 'Email',
                        icon: CupertinoIcons.envelope,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!value.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      _buildDivider(),
                      _buildTextInput(
                        controller: _fullNameController,
                        placeholder: 'Họ và tên',
                        icon: CupertinoIcons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập họ tên';
                          }
                          return null;
                        },
                      ),
                      _buildDivider(),
                      _buildTextInput(
                        controller: _phoneController,
                        placeholder: 'Số điện thoại (không bắt buộc)',
                        icon: CupertinoIcons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ]),

                    const SizedBox(height: 35),

                    // Security section
                    _buildSectionHeader('BẢO MẬT'),
                    _buildGroupedInputs([
                      _buildPasswordInput(
                        controller: _passwordController,
                        placeholder: 'Mật khẩu',
                        obscureText: _obscurePassword,
                        onToggleVisibility: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (value.length < 6) {
                            return 'Mật khẩu tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                    ]),

                    const SizedBox(height: 35),

                    // Role section
                    _buildSectionHeader('VAI TRÒ'),
                    _buildGroupedInputs([
                      _buildRolePicker(),
                    ]),

                    const SizedBox(height: 35),

                    // Info box
                    _buildInfoBox(),

                    const SizedBox(height: 24),

                    // Submit button
                    _buildSubmitButton(isDesktop),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Padding(
      padding: EdgeInsets.only(
        left: isDesktop ? 0 : 0,
        right: isDesktop ? 0 : 0,
        bottom: 8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  Widget _buildGroupedInputs(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 52),
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: placeholder,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: CupertinoColors.systemGrey,
                ),
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String placeholder,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(CupertinoIcons.lock_fill, color: Colors.green, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: placeholder,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: CupertinoColors.systemGrey,
                ),
              ),
              validator: validator,
            ),
          ),
          IconButton(
            icon: Icon(
              obscureText
                  ? CupertinoIcons.eye_slash_fill
                  : CupertinoIcons.eye_fill,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
            onPressed: onToggleVisibility,
          ),
        ],
      ),
    );
  }

  Widget _buildRolePicker() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRolePicker(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(CupertinoIcons.person_crop_circle_badge_plus,
                  color: Colors.green, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chức vụ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      _getRoleDisplayName(_selectedRole),
                      style: const TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.systemGrey3,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.info_circle_fill,
              color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sau khi tạo, hãy ghi lại email và mật khẩu để giao cho nhân viên',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Tạo tài khoản',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  void _showRolePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Hủy'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Chọn chức vụ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Xong'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedRole = [
                      UserRole.cashier,
                      UserRole.inventoryStaff,
                      UserRole.manager,
                    ][index];
                  });
                },
                children: [
                  Text(_getRoleDisplayName(UserRole.cashier)),
                  Text(_getRoleDisplayName(UserRole.inventoryStaff)),
                  Text(_getRoleDisplayName(UserRole.manager)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Chủ cửa hàng';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.cashier:
        return 'Thu ngân';
      case UserRole.inventoryStaff:
        return 'Nhân viên kho';
    }
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<EmployeeProvider>();

      // TODO: Uncomment khi đã implement RPC function
      // final newEmployee = await provider.createEmployee(
      //   email: _emailController.text.trim(),
      //   password: _passwordController.text,
      //   fullName: _fullNameController.text.trim(),
      //   role: _selectedRole,
      //   phone: _phoneController.text.trim().isNotEmpty
      //       ? _phoneController.text.trim()
      //       : null,
      // );

      // Temporary: Show unimplemented message
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Chức năng chưa sẵn sàng'),
            content: const Text(
              'Tính năng tạo tài khoản thủ công chưa được triển khai. '
              'Vui lòng sử dụng tính năng gửi lời mời thay thế.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Đóng'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        return;
      }

      // Success flow (uncomment khi ready)
      // if (mounted) {
      //   final password = _passwordController.text;
      //   final email = _emailController.text.trim();
      //
      //   showCupertinoDialog(
      //     context: context,
      //     barrierDismissible: false,
      //     builder: (ctx) => CupertinoAlertDialog(
      //       title: const Text('Tạo tài khoản thành công'),
      //       content: Column(
      //         mainAxisSize: MainAxisSize.min,
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         children: [
      //           const SizedBox(height: 12),
      //           Text('Email: $email',
      //               style: const TextStyle(fontWeight: FontWeight.w600)),
      //           const SizedBox(height: 4),
      //           Text('Mật khẩu: $password',
      //               style: const TextStyle(fontWeight: FontWeight.w600)),
      //           const SizedBox(height: 12),
      //           const Text(
      //             'Vui lòng ghi lại và đưa cho nhân viên',
      //             style: TextStyle(color: Colors.red, fontSize: 14),
      //           ),
      //         ],
      //       ),
      //       actions: [
      //         CupertinoDialogAction(
      //           child: const Text('Đóng'),
      //           onPressed: () {
      //             Navigator.pop(ctx);
      //             Navigator.pop(context, true); // Return to employee list
      //           },
      //         ),
      //       ],
      //     ),
      //   );
      // }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Lỗi'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('Đóng'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
