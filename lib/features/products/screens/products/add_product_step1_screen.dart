import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/services/base_service.dart';
import 'add_product_step2_screen.dart';

class AddProductStep1Screen extends StatefulWidget {
  const AddProductStep1Screen({super.key});

  @override
  State<AddProductStep1Screen> createState() => _AddProductStep1ScreenState();
}

class _AddProductStep1ScreenState extends State<AddProductStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCompanyId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thêm Sản Phẩm Mới',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // "Lưu" button - Always present escape hatch
          TextButton(
            onPressed: (_canSaveMinimal() && !_isLoading) ? _saveMinimal : null,
            child: Text(
              'Lưu',
              style: TextStyle(
                color: _canSaveMinimal() ? Colors.white : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step indicator
              Row(
                children: [
                  _buildStepIndicator(1, true),
                  _buildStepLine(false),
                  _buildStepIndicator(2, false),
                  _buildStepLine(false),
                  _buildStepIndicator(3, false),
                ],
              ),

              const SizedBox(height: 32),

              // Welcome message
              const Text(
                'Bắt đầu với thông tin cơ bản',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Chỉ cần hai thông tin này để bắt đầu',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 40),

              // Product name - Large, prominent
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Tên sản phẩm',
                  hintText: 'Ví dụ: Phân bón NPK 16-16-8',
                  prefixIcon: const Icon(Icons.inventory, size: 24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên sản phẩm';
                  }
                  if (value.trim().length < 2) {
                    return 'Tên sản phẩm phải có ít nhất 2 ký tự';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // Refresh save button state
              ),

              const SizedBox(height: 24),

              // Company selector - Clean dropdown
              Consumer<CompanyProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.companies.isEmpty) {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Nhà cung cấp',
                        hintText: 'Đang tải...',
                        prefixIcon: const Icon(Icons.business, size: 24),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                      items: const [],
                      onChanged: null,
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCompanyId,
                    decoration: InputDecoration(
                      labelText: 'Nhà cung cấp',
                      hintText: 'Chọn nhà cung cấp',
                      prefixIcon: const Icon(Icons.business, size: 24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                    ),
                    items: provider.companies.map((company) {
                      return DropdownMenuItem<String>(
                        value: company.id,
                        child: Text(
                          company.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCompanyId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng chọn nhà cung cấp';
                      }
                      return null;
                    },
                  );
                },
              ),

              const Spacer(),

              // Continue button - Primary action
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canContinue() ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canContinue()
                        ? Colors.green
                        : Colors.grey[300],
                    foregroundColor: _canContinue()
                        ? Colors.white
                        : Colors.grey[500],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _canContinue() ? 2 : 0,
                  ),
                  child: const Text(
                    'Tiếp tục',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Help text
              Text(
                'Bạn có thể bấm "Lưu" ở góc trên để lưu sản phẩm với thông tin tối thiểu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? Colors.green : Colors.grey[300],
      ),
    );
  }

  bool _canContinue() {
    return _nameController.text.trim().isNotEmpty && _selectedCompanyId != null;
  }

  bool _canSaveMinimal() {
    return _nameController.text.trim().length >= 2 &&
        _selectedCompanyId != null;
  }

  void _continue() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductStep2Screen(
            productName: _nameController.text.trim(),
            companyId: _selectedCompanyId!,
          ),
        ),
      );
    }
  }

  Future<void> _saveMinimal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create minimal product with just name and company
        final newProduct = Product(
          id: '',
          name: _nameController.text.trim(),
          category: ProductCategory.FERTILIZER, // Default category
          companyId: _selectedCompanyId!,
          attributes: {},
          isActive: true,
          isBanned: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          storeId: BaseService.getDefaultStoreId(),
        );

        final provider = context.read<ProductProvider>();
        final success = await provider.addProduct(newProduct);

        if (success && mounted) {
          // Show success dialog
          await _showSuccessDialog('Đã lưu sản phẩm với thông tin cơ bản!');

          // Return to product list
          Navigator.popUntil(
            context,
            (route) => route.settings.name != '/add-product-step1',
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi lưu sản phẩm',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi không mong muốn: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Thành công!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn có thể bổ sung thông tin chi tiết sau.',
                        style: TextStyle(fontSize: 14, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Quay về danh sách',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
