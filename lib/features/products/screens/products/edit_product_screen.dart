import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart'; // Thêm import

class EditProductScreen extends StatefulWidget {
  final Product product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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

    // Khởi tạo controllers với dữ liệu từ product có sẵn
    _nameController = TextEditingController(text: widget.product.name);
    _skuController = TextEditingController(text: widget.product.sku);
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
    _selectedCategory = widget.product.category;
    _selectedCompanyId = widget.product.companyId;

    // Điền dữ liệu cho các thuộc tính đặc thù
    _populateAttributeControllers();

    // Tải danh sách công ty từ CompanyProvider
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
    // Dispose tất cả controllers
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh Sửa Sản Phẩm'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Thông Tin Cơ Bản'),
              const SizedBox(height: 16),
              _buildBasicInfoForm(),
              const SizedBox(height: 24),
              _buildSectionTitle('Thuộc Tính Sản Phẩm'),
              const SizedBox(height: 16),
              _buildCategorySelector(),
              const SizedBox(height: 16),
              _buildDynamicAttributesForm(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Các hàm build UI được copy và điều chỉnh từ AddProductScreen)

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildBasicInfoForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: _buildInputDecoration(label: 'Tên sản phẩm', icon: Icons.inventory),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _skuController,
          readOnly: true, // KHÔNG CHO SỬA SKU
          decoration: _buildInputDecoration(label: 'Mã SKU/Barcode', icon: Icons.qr_code).copyWith(
            fillColor: Colors.grey[200],
          ),
        ),
        const SizedBox(height: 16),
        Consumer<CompanyProvider>(
          builder: (context, provider, child) {
            return DropdownButtonFormField<String>(
              value: _selectedCompanyId,
              decoration: _buildInputDecoration(label: 'Nhà cung cấp', icon: Icons.business),
              items: provider.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (value) => setState(() => _selectedCompanyId = value),
              validator: (value) => (value == null) ? 'Vui lòng chọn nhà cung cấp' : null,
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: _buildInputDecoration(label: 'Mô tả', icon: Icons.description),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return DropdownButtonFormField<ProductCategory>(
      value: _selectedCategory,
      decoration: _buildInputDecoration(label: 'Loại sản phẩm', icon: Icons.category),
      items: ProductCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(_getCategoryDisplayName(c)))).toList(),
      onChanged: null, // KHÔNG CHO SỬA LOẠI SẢN PHẨM
    );
  }

  Widget _buildDynamicAttributesForm() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER: return _buildFertilizerForm();
      case ProductCategory.PESTICIDE: return _buildPesticideForm();
      case ProductCategory.SEED: return _buildSeedForm();
    }
  }

  Widget _buildFertilizerForm() {
    return Column(children: [
      TextFormField(
        controller: _npkRatioController,
        decoration: _buildInputDecoration(label: 'Tỷ lệ NPK', icon: Icons.science),
        validator: (v) => (v?.isEmpty ?? true) ? 'Nhập NPK' : null,
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _fertilizerTypeController.text,
          decoration: _buildInputDecoration(label: 'Loại'),
          items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => _fertilizerTypeController.text = v ?? '',
          validator: (v) => (v?.isEmpty ?? true) ? 'Chọn loại' : null,
        )),
        const SizedBox(width: 12),
        Expanded(child: TextFormField(
          controller: _weightController,
          decoration: _buildInputDecoration(label: 'Khối lượng'),
          keyboardType: TextInputType.number,
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập khối lượng' : null,
        )),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(
          value: _weightUnitController.text,
          decoration: _buildInputDecoration(label: 'Đơn vị'),
          items: ['kg', 'tấn', 'bao'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (v) => _weightUnitController.text = v ?? '',
          validator: (v) => (v?.isEmpty ?? true) ? 'Chọn đơn vị' : null,
        )),
      ]),
    ]);
  }

  Widget _buildPesticideForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(label: 'Hoạt chất chính', icon: Icons.biotech),
          validator: (v) => (v?.isEmpty ?? true) ? 'Nhập hoạt chất' : null,
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _concentrationController,
            decoration: _buildInputDecoration(label: 'Nồng độ'),
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập nồng độ' : null,
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _volumeController,
            decoration: _buildInputDecoration(label: 'Thể tích'),
            keyboardType: TextInputType.number,
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập thể tích' : null,
          )),
          const SizedBox(width: 12),
          Expanded(child: DropdownButtonFormField<String>(
            value: _volumeUnitController.text,
            decoration: _buildInputDecoration(label: 'Đơn vị'),
            items: ['ml', 'lít', 'chai', 'lọ'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
            onChanged: (v) => _volumeUnitController.text = v ?? '',
            validator: (v) => (v?.isEmpty ?? true) ? 'Chọn đơn vị' : null,
          )),
        ]),
      ],
    );
  }

  Widget _buildSeedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: TextFormField(
            controller: _strainController,
            decoration: _buildInputDecoration(label: 'Tên giống', icon: Icons.grass),
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập tên giống' : null,
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _originController,
            decoration: _buildInputDecoration(label: 'Nguồn gốc', icon: Icons.place),
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập nguồn gốc' : null,
          )),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextFormField(
            controller: _germinationRateController,
            decoration: _buildInputDecoration(label: 'Tỷ lệ nảy mầm (%)'),
            keyboardType: TextInputType.number,
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập tỷ lệ' : null,
          )),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(
            controller: _purityController,
            decoration: _buildInputDecoration(label: 'Độ thuần chủng (%)'),
            keyboardType: TextInputType.number,
            validator: (v) => (v?.isEmpty ?? true) ? 'Nhập độ thuần' : null,
          )),
        ]),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(child: OutlinedButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Hủy'))),
      const SizedBox(width: 16),
      Expanded(child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProduct,
        child: _isLoading ? const CircularProgressIndicator() : const Text('Lưu Thay Đổi'),
      )),
    ]);
  }

  InputDecoration _buildInputDecoration({required String label, String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label, hintText: hint, prefixIcon: icon != null ? Icon(icon) : null, border: const OutlineInputBorder(),
    );
  }

  String _getCategoryDisplayName(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER: return 'Phân Bón';
      case ProductCategory.PESTICIDE: return 'Thuốc BVTV';
      case ProductCategory.SEED: return 'Lúa Giống';
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
      // ... các case khác tương tự
      default:
        return {};
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        companyId: _selectedCompanyId,
        description: _descriptionController.text.trim(),
        attributes: _buildAttributes(),
      );

      final provider = context.read<ProductProvider>();
      final success = await provider.updateProduct(updatedProduct);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}