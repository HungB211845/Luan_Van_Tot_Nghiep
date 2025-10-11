import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/services/base_service.dart';
import '../../../../shared/services/image_service.dart';
import '../../widgets/product_image_widget.dart';

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Image upload
  final ImageService _imageService = ImageService();
  String? _imageUrl;
  bool _isUploadingImage = false;

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
      imageUrl: _imageUrl,
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

                // Image upload section
                InkWell(
                  onTap: _isUploadingImage ? null : _showImagePickerSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                          ProductImageWidget(
                            imageUrl: _imageUrl,
                            size: ProductImageSize.list,
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          const Icon(
                            Icons.add_photo_alternate,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            _isUploadingImage
                                ? 'Đang tải lên...'
                                : (_imageUrl != null && _imageUrl!.isNotEmpty
                                    ? 'Đã tải lên'
                                    : 'Hình ảnh sản phẩm (tùy chọn)'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _imageUrl != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _isUploadingImage
                                  ? Colors.orange
                                  : (_imageUrl != null
                                      ? Colors.black87
                                      : Colors.grey[600]),
                            ),
                          ),
                        ),
                        if (_isUploadingImage)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                      ],
                    ),
                  ),
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

  /// Show ActionSheet for selecting image upload method
  Future<void> _showImagePickerSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chọn nguồn hình ảnh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.green),
                title: const Text('Nhập URL'),
                onTap: () => Navigator.pop(context, 'url'),
              ),
              if (_imageUrl != null && _imageUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Xóa ảnh'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    if (result == 'delete') {
      setState(() {
        _imageUrl = null;
      });
      return;
    }

    if (result == 'url') {
      await _showUrlInputDialog();
      return;
    }

    // Handle camera or gallery
    final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    await _uploadImage(source: source);
  }

  /// Show dialog for entering image URL
  Future<void> _showUrlInputDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Nhập URL hình ảnh'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'https://example.com/image.jpg',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Tải lên'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _uploadImage(imageUrl: result);
    }
  }

  /// Upload image and update state
  Future<void> _uploadImage({ImageSource? source, String? imageUrl}) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final uploadedUrl = await _imageService.uploadProductImage(
        source: source,
        imageUrl: imageUrl,
      );

      if (uploadedUrl != null && mounted) {
        setState(() {
          _imageUrl = uploadedUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải ảnh lên thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải ảnh lên. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }
}
