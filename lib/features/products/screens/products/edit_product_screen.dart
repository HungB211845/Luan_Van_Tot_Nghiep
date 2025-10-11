import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/services/base_service.dart';
import '../../../../shared/services/image_service.dart';
import '../../widgets/product_image_widget.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;

  // Image upload
  final ImageService _imageService = ImageService();
  String? _imageUrl;
  bool _isUploadingImage = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _descriptionController;

  // Dropdown selections
  late ProductCategory _selectedCategory;
  String? _selectedCompanyId;

  // Attribute Controllers
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  final _weightController = TextEditingController();
  final _weightUnitController = TextEditingController();
  final _activeIngredientController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _volumeController = TextEditingController();
  final _volumeUnitController = TextEditingController();
  final _strainController = TextEditingController();
  final _originController = TextEditingController();
  final _germinationRateController = TextEditingController();
  final _purityController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product.name);
    _skuController = TextEditingController(text: widget.product.sku);
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
    _selectedCategory = widget.product.category;
    _selectedCompanyId = widget.product.companyId;
    _imageUrl = widget.product.imageUrl;

    _populateAttributeControllers();

    // Track changes
    _nameController.addListener(() => setState(() => _hasChanges = true));
    _skuController.addListener(() => setState(() => _hasChanges = true));
    _descriptionController.addListener(() => setState(() => _hasChanges = true));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  void _populateAttributeControllers() {
    final attrs = widget.product.attributes;
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        final fertilizerAttrs = FertilizerAttributes.fromJson(attrs);
        _npkRatioController.text = fertilizerAttrs.npkRatio;
        _fertilizerTypeController.text = fertilizerAttrs.type;
        _weightController.text = fertilizerAttrs.weight.toString();
        _weightUnitController.text = fertilizerAttrs.unit;
        break;
      case ProductCategory.PESTICIDE:
        final pesticideAttrs = PesticideAttributes.fromJson(attrs);
        _activeIngredientController.text = pesticideAttrs.activeIngredient;
        _concentrationController.text = pesticideAttrs.concentration;
        _volumeController.text = pesticideAttrs.volume.toString();
        _volumeUnitController.text = pesticideAttrs.unit;
        break;
      case ProductCategory.SEED:
        final seedAttrs = SeedAttributes.fromJson(attrs);
        _strainController.text = seedAttrs.strain;
        _originController.text = seedAttrs.origin;
        _germinationRateController.text = seedAttrs.germinationRate;
        _purityController.text = seedAttrs.purity;
        break;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _npkRatioController.dispose();
    _fertilizerTypeController.dispose();
    _weightController.dispose();
    _weightUnitController.dispose();
    _activeIngredientController.dispose();
    _concentrationController.dispose();
    _volumeController.dispose();
    _volumeUnitController.dispose();
    _strainController.dispose();
    _originController.dispose();
    _germinationRateController.dispose();
    _purityController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hủy thay đổi?'),
        content: const Text('Bạn có thay đổi chưa được lưu. Bạn có muốn hủy các thay đổi không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hủy thay đổi'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _selectedCategory,
        companyId: _selectedCompanyId,
        imageUrl: _imageUrl,
        attributes: _buildAttributes(),
        updatedAt: DateTime.now(),
      );

      final provider = context.read<ProductProvider>();
      final success = await provider.updateProduct(updatedProduct);

      if (success && mounted) {
        setState(() => _hasChanges = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật sản phẩm thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage.isEmpty ? 'Có lỗi xảy ra' : provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa sản phẩm',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${widget.product.name}" không?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        final provider = context.read<ProductProvider>();
        final success = await provider.deleteProduct(widget.product.id);

        if (success && mounted) {
          Navigator.pop(context); // Close EditProductScreen
          Navigator.pop(context); // Close ProductDetailScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa sản phẩm thành công'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage.isEmpty ? 'Có lỗi xảy ra' : provider.errorMessage),
              backgroundColor: Colors.red,
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

  Map<String, dynamic> _buildAttributes() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER:
        return FertilizerAttributes(
          npkRatio: _npkRatioController.text.trim(),
          type: _fertilizerTypeController.text.trim(),
          weight: int.tryParse(_weightController.text.trim()) ?? 0,
          unit: _weightUnitController.text.trim(),
        ).toJson();
      case ProductCategory.PESTICIDE:
        return PesticideAttributes(
          activeIngredient: _activeIngredientController.text.trim(),
          concentration: _concentrationController.text.trim(),
          volume: double.tryParse(_volumeController.text.trim()) ?? 0.0,
          unit: _volumeUnitController.text.trim(),
          targetPests: [],
        ).toJson();
      case ProductCategory.SEED:
        return SeedAttributes(
          strain: _strainController.text.trim(),
          origin: _originController.text.trim(),
          germinationRate: _germinationRateController.text.trim(),
          purity: _purityController.text.trim(),
        ).toJson();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            'Chỉnh Sửa Sản Phẩm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
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
                    'Lưu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Basic Info Group
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Thông Tin Cơ Bản',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      _buildBasicInfoFields(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Product Attributes Group
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Thuộc Tính Sản Phẩm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      _buildCategoryRow(),
                      _buildDynamicAttributesForm(),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Delete Button - Separated at bottom
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteProduct,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa Sản Phẩm Này'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _buildInputDecoration(
              label: 'Tên sản phẩm *',
              icon: Icons.inventory,
            ),
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Nhập tên sản phẩm' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _skuController,
            decoration: _buildInputDecoration(
              label: 'Mã SKU/Barcode',
              icon: Icons.qr_code,
            ),
          ),
          const SizedBox(height: 16),
          Consumer<CompanyProvider>(
            builder: (context, provider, _) {
              return DropdownButtonFormField<String>(
                value: _selectedCompanyId,
                decoration: _buildInputDecoration(
                  label: 'Nhà cung cấp *',
                  icon: Icons.business,
                ),
                items: provider.companies.map((c) {
                  return DropdownMenuItem(value: c.id, child: Text(c.name));
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedCompanyId = v;
                  _hasChanges = true;
                }),
                validator: (v) => (v?.isEmpty ?? true) ? 'Chọn nhà cung cấp' : null,
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: _buildInputDecoration(
              label: 'Mô tả',
              icon: Icons.description,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // Image upload section
          InkWell(
            onTap: _isUploadingImage ? null : _showImagePickerSheet,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  if (_imageUrl != null && _imageUrl!.isNotEmpty) ...[
                    // Show uploaded image
                    ProductImageWidget(
                      imageUrl: _imageUrl,
                      size: ProductImageSize.list,
                    ),
                    const SizedBox(width: 12),
                  ] else ...[
                    // Show upload icon
                    Icon(
                      Icons.add_photo_alternate,
                      size: 20,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
                        Text(
                          _isUploadingImage
                              ? 'Đang tải lên...'
                              : (_imageUrl != null && _imageUrl!.isNotEmpty
                                  ? 'Đã tải lên'
                                  : 'Chọn ảnh từ camera hoặc thư viện'),
                          style: TextStyle(
                            fontSize: 14,
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
        ],
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DropdownButtonFormField<ProductCategory>(
        value: _selectedCategory,
        decoration: _buildInputDecoration(
          label: 'Loại sản phẩm *',
          icon: Icons.category,
        ),
        items: ProductCategory.values.map((cat) {
          return DropdownMenuItem(
            value: cat,
            child: Text(_getCategoryName(cat)),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _selectedCategory = v;
              _hasChanges = true;
            });
          }
        },
      ),
    );
  }

  Widget _buildDynamicAttributesForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _selectedCategory == ProductCategory.FERTILIZER
        ? _buildFertilizerForm()
        : _selectedCategory == ProductCategory.PESTICIDE
          ? _buildPesticideForm()
          : _buildSeedForm(),
    );
  }

  Widget _buildFertilizerForm() {
    return Column(
      children: [
        TextFormField(
          controller: _npkRatioController,
          decoration: _buildInputDecoration(label: 'Tỷ lệ NPK *', icon: Icons.science),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập NPK' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _fertilizerTypeController.text.isEmpty ? null : _fertilizerTypeController.text,
          decoration: _buildInputDecoration(label: 'Loại *'),
          items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() {
            _fertilizerTypeController.text = v ?? '';
            _hasChanges = true;
          }),
          validator: (v) => (v?.isEmpty ?? true) ? 'Chọn loại' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                decoration: _buildInputDecoration(label: 'Khối lượng *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Nhập khối lượng' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _weightUnitController.text.isEmpty ? null : _weightUnitController.text,
                decoration: _buildInputDecoration(label: 'Đơn vị *'),
                items: ['kg', 'tấn', 'bao'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() {
                  _weightUnitController.text = v ?? '';
                  _hasChanges = true;
                }),
                validator: (v) => (v?.isEmpty ?? true) ? 'Chọn đơn vị' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPesticideForm() {
    return Column(
      children: [
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(label: 'Hoạt chất chính *', icon: Icons.biotech),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập hoạt chất' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _concentrationController,
          decoration: _buildInputDecoration(label: 'Nồng độ *'),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập nồng độ' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _volumeController,
                decoration: _buildInputDecoration(label: 'Thể tích *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Nhập thể tích' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _volumeUnitController.text.isEmpty ? null : _volumeUnitController.text,
                decoration: _buildInputDecoration(label: 'Đơn vị *'),
                items: ['ml', 'lít', 'chai', 'lọ'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() {
                  _volumeUnitController.text = v ?? '';
                  _hasChanges = true;
                }),
                validator: (v) => (v?.isEmpty ?? true) ? 'Chọn đơn vị' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeedForm() {
    return Column(
      children: [
        TextFormField(
          controller: _strainController,
          decoration: _buildInputDecoration(label: 'Tên giống *', icon: Icons.grass),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập tên giống' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _originController,
          decoration: _buildInputDecoration(label: 'Nguồn gốc *'),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập nguồn gốc' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _germinationRateController,
                decoration: _buildInputDecoration(label: 'Tỷ lệ nảy mầm (%) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Nhập tỷ lệ' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _purityController,
                decoration: _buildInputDecoration(label: 'Độ thuần chủng (%) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v?.isEmpty ?? true) ? 'Nhập độ thuần' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.green) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  String _getCategoryName(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
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
        _hasChanges = true;
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
          _hasChanges = true;
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