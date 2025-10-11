import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../providers/company_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/services/base_service.dart';
import '../../../../shared/services/image_service.dart';
import '../../widgets/product_image_widget.dart';
import 'add_product_step2_screen.dart';
import '../company/company_picker_screen.dart';

class AddProductStep1Screen extends StatefulWidget {
  const AddProductStep1Screen({super.key});

  @override
  State<AddProductStep1Screen> createState() => _AddProductStep1ScreenState();
}

class _AddProductStep1ScreenState extends State<AddProductStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ImageService _imageService = ImageService();
  String? _selectedCompanyId;
  String? _selectedCompanyName;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;

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
          'Thông tin cơ bản',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
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
              // Product name
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
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),

              // Image upload section
              InkWell(
                onTap: _isUploadingImage ? null : _showImagePickerSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                        // Show uploaded image
                        ProductImageWidget(
                          imageUrl: _imageUrl,
                          size: ProductImageSize.list,
                        ),
                        const SizedBox(width: 16),
                      ] else ...[
                        // Show upload icon
                        Icon(
                          Icons.add_photo_alternate,
                          size: 24,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hình ảnh sản phẩm',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isUploadingImage
                                  ? 'Đang tải lên...'
                                  : (_imageUrl != null && _imageUrl!.isNotEmpty
                                      ? 'Đã tải lên'
                                      : 'Chọn ảnh từ camera hoặc thư viện'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _imageUrl != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _isUploadingImage
                                    ? Colors.orange
                                    : (_imageUrl != null
                                        ? Colors.black87
                                        : Colors.grey[500]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isUploadingImage)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Company selector - Navigation row (Apple style)
              InkWell(
                onTap: () async {
                  final selectedId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (context) => CompanyPickerScreen(
                        selectedCompanyId: _selectedCompanyId,
                      ),
                    ),
                  );

                  if (selectedId != null && mounted) {
                    final provider = context.read<CompanyProvider>();
                    final company = provider.companies.firstWhere(
                      (c) => c.id == selectedId,
                      orElse: () => throw Exception('Company not found'),
                    );

                    setState(() {
                      _selectedCompanyId = selectedId;
                      _selectedCompanyName = company.name;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedCompanyId == null
                          ? Colors.grey[300]!
                          : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 24,
                        color: _selectedCompanyId != null
                            ? Colors.green
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nhà cung cấp',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedCompanyName ?? 'Chọn nhà cung cấp',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedCompanyId != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _selectedCompanyId != null
                                    ? Colors.black87
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Continue button
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
            ],
          ),
        ),
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
    if (_formKey.currentState!.validate() && _selectedCompanyId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddProductStep2Screen(
            productName: _nameController.text.trim(),
            companyId: _selectedCompanyId!,
            imageUrl: _imageUrl,
          ),
        ),
      );
    }
  }

  Future<void> _saveMinimal() async {
    if (!(_formKey.currentState!.validate() && _selectedCompanyId != null)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final newProduct = Product(
        id: '',
        name: _nameController.text.trim(),
        category: ProductCategory.FERTILIZER,
        companyId: _selectedCompanyId!,
        imageUrl: _imageUrl,
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
        await _showSuccessDialog('Đã lưu sản phẩm với thông tin cơ bản!');
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
                  color: Colors.green.withValues(alpha: 0.1),
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
                  color: Colors.green.withValues(alpha: 0.1),
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
