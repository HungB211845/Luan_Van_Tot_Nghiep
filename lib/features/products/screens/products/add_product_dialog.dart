import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/services/base_service.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for all fields from all steps
  final _nameController = TextEditingController();
  String? _selectedCompanyId;
  ProductCategory _selectedCategory = ProductCategory.FERTILIZER; // Default
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _npkRatioController = TextEditingController();
  // ... other controllers for pesticide, seed etc.

  @override
  void initState() {
    super.initState();
    // Load companies for the dropdown
    context.read<CompanyProvider>().loadCompanies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _npkRatioController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // Build attributes based on selected category
    Map<String, dynamic> attributes = {};
    if (_selectedCategory == ProductCategory.FERTILIZER) {
      attributes = {'npk_ratio': _npkRatioController.text};
    }
    // TODO: Add logic for other categories

    final newProduct = Product(
      id: '',
      name: _nameController.text.trim(),
      companyId: _selectedCompanyId!,
      category: _selectedCategory,
      sku: _skuController.text.trim(),
      description: _descriptionController.text.trim(),
      attributes: attributes,
      storeId: BaseService.getDefaultStoreId(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await context.read<ProductProvider>().addProduct(newProduct);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true); // Pop with success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<ProductProvider>().errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm Sản Phẩm Mới'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6, // 60% of screen width
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Không được để trống' : null,
                ),
                const SizedBox(height: 16),
                Consumer<CompanyProvider>(
                  builder: (context, provider, child) {
                    return DropdownButtonFormField<String>(
                      value: _selectedCompanyId,
                      decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
                      items: provider.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (value) => setState(() => _selectedCompanyId = value),
                      validator: (v) => (v == null) ? 'Vui lòng chọn' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: 'Mã SKU/Barcode'),
                ),
                const SizedBox(height: 16),

                // Category and Attributes
                DropdownButtonFormField<ProductCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Danh mục sản phẩm'),
                  items: ProductCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.displayName))).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedCategory = value);
                  },
                ),
                const SizedBox(height: 16),
                _buildCategorySpecificForm(),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu Sản Phẩm'),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificForm() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER:
        return TextFormField(
          controller: _npkRatioController,
          decoration: const InputDecoration(labelText: 'Tỷ lệ NPK', hintText: 'Ví dụ: 16-16-8'),
        );
      // TODO: Add cases for PESTICIDE and SEED
      default:
        return const SizedBox.shrink();
    }
  }
}
