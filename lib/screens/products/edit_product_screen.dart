// lib/screens/products/edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../widgets/loading_widget.dart';

class EditProductScreen extends StatefulWidget {
  const EditProductScreen({Key? key}) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isInitialized = false;

  // Controllers cho thông tin cơ bản
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State variables
  late ProductCategory _selectedCategory;
  String? _selectedCompanyId;
  late bool _isActive;
  late bool _isBanned;

  // Controllers cho attributes động
  // Fertilizer
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  final _weightController = TextEditingController();
  final _weightUnitController = TextEditingController();
  final _nitrogenController = TextEditingController();
  final _phosphorusController = TextEditingController();
  final _potassiumController = TextEditingController();

  // Pesticide
  final _activeIngredientController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _volumeController = TextEditingController();
  final _volumeUnitController = TextEditingController();
  final _targetPestsController = TextEditingController();

  // Seed
  final _strainController = TextEditingController();
  final _originController = TextEditingController();
  final _germinationRateController = TextEditingController();
  final _purityController = TextEditingController();
  final _growthPeriodController = TextEditingController();
  final _yieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // THÊM DÒNG NÀY VÀO
      context.read<ProductProvider>().loadCompanies();
      _loadProductData();
    });
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
    _nitrogenController.dispose();
    _phosphorusController.dispose();
    _potassiumController.dispose();
    _activeIngredientController.dispose();
    _concentrationController.dispose();
    _volumeController.dispose();
    _volumeUnitController.dispose();
    _targetPestsController.dispose();
    _strainController.dispose();
    _originController.dispose();
    _germinationRateController.dispose();
    _purityController.dispose();
    _growthPeriodController.dispose();
    _yieldController.dispose();
    super.dispose();
  }

  void _loadProductData() {
    final provider = context.read<ProductProvider>();
    final product = provider.selectedProduct;

    if (product == null) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isInitialized = true;

      // Load thông tin cơ bản
      _nameController.text = product.name;
      _skuController.text = product.sku;
      _descriptionController.text = product.description ?? '';
      _selectedCategory = product.category;
      _selectedCompanyId = product.companyId;
      _isActive = product.isActive;
      _isBanned = product.isBanned;

      // Load attributes theo category
      switch (product.category) {
        case ProductCategory.FERTILIZER:
          final attrs = product.fertilizerAttributes;
          if (attrs != null) {
            _npkRatioController.text = attrs.npkRatio;
            _fertilizerTypeController.text = attrs.type;
            _weightController.text = attrs.weight.toString();
            _weightUnitController.text = attrs.unit;
            _nitrogenController.text = attrs.nitrogen?.toString() ?? '';
            _phosphorusController.text = attrs.phosphorus?.toString() ?? '';
            _potassiumController.text = attrs.potassium?.toString() ?? '';
          }
          break;

        case ProductCategory.PESTICIDE:
          final attrs = product.pesticideAttributes;
          if (attrs != null) {
            _activeIngredientController.text = attrs.activeIngredient;
            _concentrationController.text = attrs.concentration;
            _volumeController.text = attrs.volume.toString();
            _volumeUnitController.text = attrs.unit;
            _targetPestsController.text = attrs.targetPests.join(', ');
          }
          break;

        case ProductCategory.SEED:
          final attrs = product.seedAttributes;
          if (attrs != null) {
            _strainController.text = attrs.strain;
            _originController.text = attrs.origin;
            _germinationRateController.text = attrs.germinationRate;
            _purityController.text = attrs.purity;
            _growthPeriodController.text = attrs.growthPeriod ?? '';
            _yieldController.text = attrs.yield ?? '';
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chỉnh Sửa Sản Phẩm'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: LoadingWidget()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chỉnh Sửa Sản Phẩm',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Nút Delete
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 24),
            onPressed: _isLoading ? null : _showDeleteConfirmation,
            tooltip: 'Xóa sản phẩm',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section: Thông tin cơ bản
              _buildSectionTitle('Thông Tin Cơ Bản'),
              const SizedBox(height: 16),
              _buildBasicInfoForm(),

              const SizedBox(height: 24),

              // Section: Thuộc tính đặc thù
              _buildSectionTitle('Thuộc Tính Sản Phẩm'),
              const SizedBox(height: 16),
              _buildCategoryInfo(),
              const SizedBox(height: 16),
              _buildDynamicAttributesForm(),

              const SizedBox(height: 24),

              // Section: Trạng thái
              _buildStatusSection(),

              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBasicInfoForm() {
    return Column(
      children: [
        // Tên sản phẩm
        TextFormField(
          controller: _nameController,
          decoration: _buildInputDecoration(
            label: 'Tên sản phẩm',
            hint: 'Ví dụ: Phân bón NPK 16-16-8',
            icon: Icons.inventory,
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
        ),

        const SizedBox(height: 16),

        // SKU/Barcode (không cho sửa)
        TextFormField(
          controller: _skuController,
          decoration: _buildInputDecoration(
            label: 'Mã SKU/Barcode',
            hint: 'Mã SKU không thể thay đổi',
            icon: Icons.qr_code,
          ),
          enabled: false, // Không cho phép sửa SKU
        ),

        const SizedBox(height: 16),

        // Nhà cung cấp
        Consumer<ProductProvider>(
          builder: (context, provider, child) {
            if (provider.companies.isEmpty) {
              // Hiển thị loading hoặc dropdown bị vô hiệu hóa
              return DropdownButtonFormField<String>(
                decoration: _buildInputDecoration(
                  label: 'Nhà cung cấp',
                  hint: 'Đang tải...',
                  icon: Icons.business,
                ),
                items: const [],
                onChanged: null,
              );
            }

            return DropdownButtonFormField<String>(
              value: _selectedCompanyId,
              decoration: _buildInputDecoration(
                label: 'Nhà cung cấp',
                hint: 'Chọn nhà cung cấp',
                icon: Icons.business,
              ),
              // Dùng danh sách thật từ provider
              items: provider.companies.map((company) {
                return DropdownMenuItem<String>(
                  value: company.id,
                  child: Text(company.name),
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

        const SizedBox(height: 16),

        // Mô tả (optional)
        TextFormField(
          controller: _descriptionController,
          decoration: _buildInputDecoration(
            label: 'Mô tả (tùy chọn)',
            hint: 'Mô tả chi tiết về sản phẩm',
            icon: Icons.description,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildCategoryInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCategoryColor(_selectedCategory).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getCategoryColor(_selectedCategory).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(_selectedCategory),
            color: _getCategoryColor(_selectedCategory),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Loại sản phẩm: ${_getCategoryDisplayName(_selectedCategory)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _getCategoryColor(_selectedCategory),
            ),
          ),
          const Spacer(),
          const Text(
            '(Không thể thay đổi)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAttributesForm() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER:
        return _buildFertilizerForm();
      case ProductCategory.PESTICIDE:
        return _buildPesticideForm();
      case ProductCategory.SEED:
        return _buildSeedForm();
    }
  }

  Widget _buildFertilizerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông số phân bón',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),

        // Tỷ lệ NPK
        TextFormField(
          controller: _npkRatioController,
          decoration: _buildInputDecoration(
            label: 'Tỷ lệ NPK',
            hint: 'Ví dụ: 16-16-8',
            icon: Icons.science,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập tỷ lệ NPK';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            // Loại phân bón
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _fertilizerTypeController.text.isEmpty
                    ? null
                    : _fertilizerTypeController.text,
                decoration: _buildInputDecoration(
                  label: 'Loại',
                  hint: 'Chọn loại',
                  icon: Icons.type_specimen,
                ),
                items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  _fertilizerTypeController.text = value ?? '';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng chọn loại';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Khối lượng
            Expanded(
              child: TextFormField(
                controller: _weightController,
                decoration: _buildInputDecoration(
                  label: 'Khối lượng',
                  hint: '50',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập khối lượng';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Khối lượng phải là số';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Đơn vị khối lượng
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _weightUnitController.text.isEmpty
                    ? null
                    : _weightUnitController.text,
                decoration: _buildInputDecoration(label: 'Đơn vị', hint: 'kg'),
                items: ['kg', 'tấn', 'bao'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  _weightUnitController.text = value ?? 'kg';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Chọn đơn vị';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // NPK Details (optional)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nitrogenController,
                decoration: _buildInputDecoration(
                  label: 'Nitơ (N) %',
                  hint: 'Tùy chọn',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _phosphorusController,
                decoration: _buildInputDecoration(
                  label: 'Lân (P) %',
                  hint: 'Tùy chọn',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _potassiumController,
                decoration: _buildInputDecoration(
                  label: 'Kali (K) %',
                  hint: 'Tùy chọn',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPesticideForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông số thuốc BVTV',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 12),

        // Hoạt chất chính
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(
            label: 'Hoạt chất chính',
            hint: 'Ví dụ: Imidacloprid',
            icon: Icons.biotech,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập hoạt chất chính';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            // Nồng độ
            Expanded(
              child: TextFormField(
                controller: _concentrationController,
                decoration: _buildInputDecoration(
                  label: 'Nồng độ',
                  hint: '4SC, 25EC',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập nồng độ';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Thể tích
            Expanded(
              child: TextFormField(
                controller: _volumeController,
                decoration: _buildInputDecoration(
                  label: 'Thể tích',
                  hint: '100',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập thể tích';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Thể tích phải là số';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Đơn vị thể tích
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _volumeUnitController.text.isEmpty
                    ? null
                    : _volumeUnitController.text,
                decoration: _buildInputDecoration(label: 'Đơn vị', hint: 'ml'),
                items: ['ml', 'lít', 'chai', 'lọ'].map((unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  _volumeUnitController.text = value ?? 'ml';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Chọn đơn vị';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Đối tượng sử dụng
        TextFormField(
          controller: _targetPestsController,
          decoration: _buildInputDecoration(
            label: 'Đối tượng sử dụng (tùy chọn)',
            hint: 'Ví dụ: sâu cuốn lá, rầy nâu',
            icon: Icons.bug_report,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSeedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông số lúa giống',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.brown,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Tên giống
            Expanded(
              child: TextFormField(
                controller: _strainController,
                decoration: _buildInputDecoration(
                  label: 'Tên giống',
                  hint: 'OM18, ST24',
                  icon: Icons.grass,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên giống';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Nguồn gốc
            Expanded(
              child: TextFormField(
                controller: _originController,
                decoration: _buildInputDecoration(
                  label: 'Nguồn gốc',
                  hint: 'Việt Nam, Nhật Bản',
                  icon: Icons.place,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập nguồn gốc';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            // Tỷ lệ nảy mầm
            Expanded(
              child: TextFormField(
                controller: _germinationRateController,
                decoration: _buildInputDecoration(
                  label: 'Tỷ lệ nảy mầm',
                  hint: '95%',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tỷ lệ nảy mầm';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 12),

            // Độ thuần chủng
            Expanded(
              child: TextFormField(
                controller: _purityController,
                decoration: _buildInputDecoration(
                  label: 'Độ thuần chủng',
                  hint: '99%',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập độ thuần chủng';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            // Thời gian sinh trưởng (optional)
            Expanded(
              child: TextFormField(
                controller: _growthPeriodController,
                decoration: _buildInputDecoration(
                  label: 'Thời gian sinh trưởng',
                  hint: '110 ngày (tùy chọn)',
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Năng suất (optional)
            Expanded(
              child: TextFormField(
                controller: _yieldController,
                decoration: _buildInputDecoration(
                  label: 'Năng suất dự kiến',
                  hint: '6-7 tấn/ha (tùy chọn)',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trạng thái sản phẩm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Đang kinh doanh'),
              subtitle: const Text('Bật để cho phép bán sản phẩm này'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              activeColor: Colors.green,
            ),

            if (_selectedCategory == ProductCategory.PESTICIDE)
              SwitchListTile(
                title: const Text('Sản phẩm bị cấm'),
                subtitle: const Text('Đánh dấu nếu chứa hoạt chất bị cấm'),
                value: _isBanned,
                onChanged: (value) {
                  setState(() {
                    _isBanned = value;
                  });
                },
                activeColor: Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Nút Hủy
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(context);
                  },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey[400]!),
            ),
            child: const Text('Hủy', style: TextStyle(fontSize: 16)),
          ),
        ),

        const SizedBox(width: 16),

        // Nút Lưu
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Cập Nhật',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String _getCategoryDisplayName(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
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
          nitrogen: int.tryParse(_nitrogenController.text.trim()),
          phosphorus: int.tryParse(_phosphorusController.text.trim()),
          potassium: int.tryParse(_potassiumController.text.trim()),
        ).toJson();

      case ProductCategory.PESTICIDE:
        final targetPests = _targetPestsController.text.trim().isEmpty
            ? <String>[]
            : _targetPestsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

        return PesticideAttributes(
          activeIngredient: _activeIngredientController.text.trim(),
          concentration: _concentrationController.text.trim(),
          volume: double.tryParse(_volumeController.text.trim()) ?? 0.0,
          unit: _volumeUnitController.text.trim(),
          targetPests: targetPests,
        ).toJson();

      case ProductCategory.SEED:
        return SeedAttributes(
          strain: _strainController.text.trim(),
          origin: _originController.text.trim(),
          germinationRate: _germinationRateController.text.trim(),
          purity: _purityController.text.trim(),
          growthPeriod: _growthPeriodController.text.trim().isEmpty
              ? null
              : _growthPeriodController.text.trim(),
          yield: _yieldController.text.trim().isEmpty
              ? null
              : _yieldController.text.trim(),
        ).toJson();
    }
  }

  Future<void> _updateProduct() async {
    // Kiểm tra validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hiển thị loading
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ProductProvider>();
      final currentProduct = provider.selectedProduct;

      if (currentProduct == null) {
        throw Exception('Không tìm thấy sản phẩm');
      }

      // Tạo object Product đã cập nhật
      final updatedProduct = currentProduct.copyWith(
        name: _nameController.text.trim(),
        // SKU không cho sửa
        companyId: _selectedCompanyId,
        attributes: _buildAttributes(),
        isActive: _isActive,
        isBanned: _isBanned,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      );

      // Gọi ProductProvider để update
      final success = await provider.updateProduct(updatedProduct);

      if (success) {
        // Thành công
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật sản phẩm thành công!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Thất bại
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi cập nhật sản phẩm',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Xử lý exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Ẩn loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc muốn xóa sản phẩm này?'),
            const SizedBox(height: 8),
            Text(
              _nameController.text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lưu ý: Hành động này không thể hoàn tác.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ProductProvider>();
      final product = provider.selectedProduct;

      if (product == null) {
        throw Exception('Không tìm thấy sản phẩm');
      }

      final success = await provider.deleteProduct(product.id);

      if (success) {
        if (mounted) {
          // Pop cả 2 màn hình (Edit và Detail)
          Navigator.of(context)
            ..pop() // Pop Edit Screen
            ..pop(); // Pop Detail Screen

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa sản phẩm thành công'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi xóa sản phẩm',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
