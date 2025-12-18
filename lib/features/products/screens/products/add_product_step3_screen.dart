import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../models/product_unit.dart';
import '../../services/product_unit_service.dart';
import '../../../../shared/services/base_service.dart';
import '../../../../shared/utils/responsive.dart';

enum PesticidePackagingType { bottle, pack, jar }

class DefaultPackagingConfig {
  final String displayName;
  final double defaultVolume;
  final List<String> baseUnits;
  final String defaultBaseUnit;
  final int defaultQuantity;

  const DefaultPackagingConfig({
    required this.displayName,
    required this.defaultVolume,
    required this.baseUnits,
    required this.defaultBaseUnit,
    required this.defaultQuantity,
  });
}

const Map<PesticidePackagingType, DefaultPackagingConfig> _packagingDefaults = {
  PesticidePackagingType.bottle: DefaultPackagingConfig(
    displayName: 'Chai',
    defaultVolume: 500,
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
    defaultQuantity: 20,
  ),
  PesticidePackagingType.pack: DefaultPackagingConfig(
    displayName: 'Gói',
    defaultVolume: 50,
    baseUnits: ['g', 'kg'],
    defaultBaseUnit: 'g',
    defaultQuantity: 20,
  ),
  PesticidePackagingType.jar: DefaultPackagingConfig(
    displayName: 'Lọ',
    defaultVolume: 100,
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
    defaultQuantity: 20,
  ),
};

class AddProductStep3Screen extends StatefulWidget {
  final String productName;
  final String companyId;
  final String? imageUrl;
  final ProductCategory category;
  final String baseUnit;

  const AddProductStep3Screen({
    super.key,
    required this.productName,
    required this.companyId,
    this.imageUrl,
    required this.category,
    required this.baseUnit,
  });

  @override
  State<AddProductStep3Screen> createState() => _AddProductStep3ScreenState();
}

class _AddProductStep3ScreenState extends State<AddProductStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _productCreated = false; // Track if product has been created

  final ProductUnitService _unitService = ProductUnitService();

  // Optional fields
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Category-specific controllers
  // Fertilizer
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  // 🔥 REMOVED: _weightController and _weightUnit - now configured in Multi-UoM system

  // Pesticide
  final _activeIngredientController = TextEditingController();
  final _concentrationController = TextEditingController();
  final _packageVolumeController = TextEditingController();
  final _packageQtyController = TextEditingController();
  PesticidePackagingType _selectedPackagingType = PesticidePackagingType.bottle;
  String? _selectedBaseUnit;

  // Seed
  final _strainController = TextEditingController();
  final _originController = TextEditingController();
  final _germinationRateController = TextEditingController();
  final _purityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBaseUnit = _packagingDefaults[_selectedPackagingType]!.defaultBaseUnit;
    _packageVolumeController.addListener(_onPackagingFieldChanged);
    _packageQtyController.addListener(_onPackagingFieldChanged);
  }

  @override
  void dispose() {
    _packageVolumeController.removeListener(_onPackagingFieldChanged);
    _packageQtyController.removeListener(_onPackagingFieldChanged);
    _skuController.dispose();
    _descriptionController.dispose();
    _npkRatioController.dispose();
    _fertilizerTypeController.dispose();
    // 🔥 REMOVED: _weightController disposal
    _activeIngredientController.dispose();
    _concentrationController.dispose();
    _packageVolumeController.dispose();
    _packageQtyController.dispose();
    _strainController.dispose();
    _originController.dispose();
    _germinationRateController.dispose();
    _purityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Thêm Sản Phẩm Mới',
      appBarColor: Colors.green,
      appBarForegroundColor: Colors.white,
      actions: [
        // "Lưu" button - Always present escape hatch
        TextButton(
          onPressed: _saveWithCurrentInfo,
          child: const Text(
            'Lưu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      body: Form(
        key: _formKey,
        child: Container(
          width: context.contentWidth,
          padding: EdgeInsets.all(context.sectionPadding),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: context.formAlignment,
            children: [
              // Step indicator
              Container(
                constraints: BoxConstraints(maxWidth: context.maxFormWidth),
                child: Row(
                children: [
                  _buildStepIndicator(1, true),
                  _buildStepLine(true),
                  _buildStepIndicator(2, true),
                  _buildStepLine(true),
                  _buildStepIndicator(3, true),
                ],
                ),
              ),

              const SizedBox(height: 32),

              // Product context
              Container(
                constraints: BoxConstraints(maxWidth: context.maxFormWidth),
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getCategoryColor().withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(),
                      color: _getCategoryColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.productName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _getCategoryColor(),
                            ),
                          ),
                          Text(
                            _getCategoryName(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Chi tiết bổ sung',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Thông tin này có thể để trống và bổ sung sau',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 32),

              // Optional fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SKU
                      TextFormField(
                        controller: _skuController,
                        decoration: _buildInputDecoration(
                          label: 'Mã SKU/Barcode',
                          hint: 'Có thể để trống',
                          icon: Icons.qr_code,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Category-specific attributes
                      _buildCategorySpecificForm(),

                      const SizedBox(height: 20),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: _buildInputDecoration(
                          label: 'Mô tả',
                          hint: 'Mô tả chi tiết sản phẩm',
                          icon: Icons.description,
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Finish button
              Container(
                constraints: BoxConstraints(maxWidth: context.maxFormWidth),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || _productCreated) ? null : _saveComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Hoàn tất',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                ),
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

  Widget _buildCategorySpecificForm() {
    switch (widget.category) {
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
        Text(
          'Thông số phân bón',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _npkRatioController,
          decoration: _buildInputDecoration(
            label: 'Tỷ lệ NPK',
            hint: 'Ví dụ: 16-16-8',
            icon: Icons.science,
          ),
        ),

        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: _fertilizerTypeController.text.isEmpty
              ? null
              : _fertilizerTypeController.text,
          decoration: _buildInputDecoration(
            label: 'Loại phân bón',
            hint: 'Chọn loại',
            icon: Icons.category,
          ),
          items: ['vô cơ', 'hữu cơ', 'hỗn hợp'].map((type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            _fertilizerTypeController.text = value ?? '';
          },
        ),

        // 🔥 REMOVED: Weight/Unit fields - will be configured in Multi-UoM system later
        // This eliminates confusion between attribute metadata and actual selling units
      ],
    );
  }

  Widget _buildPesticideForm() {
    final defaults = _currentPackagingDefaults;
    final unitLabel = defaults.displayName;
    final baseUnitOptions = defaults.baseUnits;
    final previewText = _buildPackagingPreviewText();
    final baseUnitValue = _selectedBaseUnit ?? defaults.defaultBaseUnit;
    final volumeHint =
        '${_formatNumber(_defaultVolumeForBaseUnit(baseUnitValue))} $baseUnitValue (mặc định)';
    final quantityHint = '${defaults.defaultQuantity} (mặc định)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quy cách đóng gói',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: PesticidePackagingType.values.map((type) {
            final config = _packagingDefaults[type]!;
            return ChoiceChip(
              label: Text(config.displayName),
              selected: _selectedPackagingType == type,
              onSelected: (selected) {
                if (selected) {
                  _onPackagingTypeChanged(type);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _packageVolumeController,
          decoration: _buildInputDecoration(
            label: 'Dung tích/Khối lượng mỗi ${unitLabel.toLowerCase()}',
            hint: volumeHint,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            return double.tryParse(value.trim()) == null ? 'Nhập số hợp lệ' : null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: baseUnitValue,
          decoration: _buildInputDecoration(
            label: 'Đơn vị cơ sở',
            hint: 'Chọn đơn vị',
          ),
          items: baseUnitOptions
              .map(
                (unit) => DropdownMenuItem<String>(
                  value: unit,
                  child: Text(unit),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedBaseUnit = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _packageQtyController,
          decoration: _buildInputDecoration(
            label: 'Số lượng ${unitLabel.toLowerCase()} trong thùng',
            hint: quantityHint,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return 'Nhập số nguyên dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildPackagingPreview(previewText),
        const SizedBox(height: 8),
        Text(
          'Các đơn vị này sẽ dùng cho Nhập Lô Nhanh và Đơn nhập hàng.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Thông số thuốc BVTV (tùy chọn)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(
            label: 'Hoạt chất chính (tùy chọn)',
            hint: 'Ví dụ: Imidacloprid',
            icon: Icons.biotech,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _concentrationController,
          decoration: _buildInputDecoration(
            label: 'Nồng độ (tùy chọn)',
            hint: 'Ví dụ: 4SC, 25EC',
          ),
        ),
      ],
    );
  }

  Widget _buildSeedForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông số lúa giống',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(),
          ),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _strainController,
          decoration: _buildInputDecoration(
            label: 'Tên giống',
            hint: 'Ví dụ: OM18, ST24',
            icon: Icons.grass,
          ),
        ),

        const SizedBox(height: 16),

        TextFormField(
          controller: _originController,
          decoration: _buildInputDecoration(
            label: 'Nguồn gốc',
            hint: 'Ví dụ: Việt Nam, Nhật Bản',
            icon: Icons.place,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _germinationRateController,
                decoration: _buildInputDecoration(
                  label: 'Tỷ lệ nảy mầm (%)',
                  hint: '0-100',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _purityController,
                decoration: _buildInputDecoration(
                  label: 'Độ thuần chủng (%)',
                  hint: '0-100',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onPackagingTypeChanged(PesticidePackagingType type) {
    if (_selectedPackagingType == type) return;
    setState(() {
      _selectedPackagingType = type;
      final defaults = _packagingDefaults[type]!;
      _selectedBaseUnit = defaults.defaultBaseUnit;
      _packageVolumeController.clear();
      _packageQtyController.clear();
    });
  }

  void _onPackagingFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  DefaultPackagingConfig get _currentPackagingDefaults =>
      _packagingDefaults[_selectedPackagingType]!;

  double _defaultVolumeForBaseUnit(String baseUnit) {
    final defaults = _currentPackagingDefaults;
    return _convertValue(
      defaults.defaultVolume,
      defaults.defaultBaseUnit,
      baseUnit,
    );
  }

  double _effectivePackageVolume() {
    final baseUnit = _effectiveBaseUnit();
    final raw = _packageVolumeController.text.trim();
    if (raw.isEmpty) return _defaultVolumeForBaseUnit(baseUnit);
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      return _defaultVolumeForBaseUnit(baseUnit);
    }
    return parsed;
  }

  int _effectivePackageQuantity() {
    final raw = _packageQtyController.text.trim();
    if (raw.isEmpty) return _currentPackagingDefaults.defaultQuantity;
    final parsed = int.tryParse(raw);
    return (parsed == null || parsed <= 0)
        ? _currentPackagingDefaults.defaultQuantity
        : parsed;
  }

  String _effectiveBaseUnit() {
    final base = _selectedBaseUnit ?? _currentPackagingDefaults.defaultBaseUnit;
    if (_currentPackagingDefaults.baseUnits.contains(base)) {
      return base;
    }
    return _currentPackagingDefaults.defaultBaseUnit;
  }

  String _buildPackagingPreviewText() {
    final unitLabel = _currentPackagingDefaults.displayName;
    final volume = _formatNumber(_effectivePackageVolume());
    final baseUnit = _effectiveBaseUnit();
    final quantity = _effectivePackageQuantity();
    return '• "$unitLabel $volume$baseUnit" (bán lẻ)\n'
        '• "Thùng" (×$quantity $unitLabel)\n'
        '• "$baseUnit" (đơn vị cơ sở)';
  }

  Widget _buildPackagingPreview(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hệ thống sẽ tạo:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _convertValue(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    if (fromUnit == 'ml' && toUnit == 'lít') return value / 1000;
    if (fromUnit == 'lít' && toUnit == 'ml') return value * 1000;
    if (fromUnit == 'g' && toUnit == 'kg') return value / 1000;
    if (fromUnit == 'kg' && toUnit == 'g') return value * 1000;
    return value;
  }

  Future<void> _createDefaultPesticideUnits(String productId) async {
    final unitLabel = _currentPackagingDefaults.displayName;
    final baseUnit = _effectiveBaseUnit();
    final volumeValue = _effectivePackageVolume();
    final quantityPerBox = _effectivePackageQuantity();
    final retailUnitName = '$unitLabel ${_formatNumber(volumeValue)}$baseUnit';
    final conversionFactor = volumeValue;
    final boxConversionFactor = quantityPerBox * conversionFactor;
    final now = DateTime.now();

    await _unitService.createProductUnit(
      ProductUnit(
        id: '',
        productId: productId,
        unitName: baseUnit,
        conversionFactor: 1.0,
        unitPrice: 0,
        isDefaultSellingUnit: false,
        isActive: true,
        storeId: '',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _unitService.createProductUnit(
      ProductUnit(
        id: '',
        productId: productId,
        unitName: retailUnitName,
        conversionFactor: conversionFactor,
        unitPrice: 0,
        isDefaultSellingUnit: true,
        isActive: true,
        storeId: '',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _unitService.createProductUnit(
      ProductUnit(
        id: '',
        productId: productId,
        unitName: 'Thùng',
        conversionFactor: boxConversionFactor,
        unitPrice: 0,
        isDefaultSellingUnit: false,
        isActive: true,
        storeId: '',
        createdAt: now,
        updatedAt: now,
      ),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _getCategoryColor(), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  String _getCategoryName() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }

  Map<String, dynamic> _buildAttributes() {
    switch (widget.category) {
      case ProductCategory.FERTILIZER:
        return FertilizerAttributes(
          npkRatio: _npkRatioController.text.trim(),
          type: _fertilizerTypeController.text.trim(),
          weight: 1, // 🔥 FIXED: Default value (not displayed to user)
          unit: 'bao', // 🔥 FIXED: Default unit (actual unit comes from ProductUnit table)
        ).toJson();

      case ProductCategory.PESTICIDE:
        return PesticideAttributes(
          activeIngredient: _activeIngredientController.text.trim().isEmpty
              ? null
              : _activeIngredientController.text.trim(),
          concentration: _concentrationController.text.trim().isEmpty
              ? null
              : _concentrationController.text.trim(),
          targetPests: const [],
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

  Future<void> _saveProduct({bool isComplete = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final baseUnit = widget.category == ProductCategory.PESTICIDE
          ? _effectiveBaseUnit()
          : widget.baseUnit;

      final newProduct = Product(
        id: '',
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        name: widget.productName,
        category: widget.category,
        companyId: widget.companyId,
        imageUrl: widget.imageUrl,
        attributes: _buildAttributes(),
        isActive: true,
        isBanned: false,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
        baseUnit: baseUnit,
      );

      final provider = context.read<ProductProvider>();
      final createdProduct = await provider.addProduct(newProduct);

      if (createdProduct != null) {
        String? unitSetupError;
        if (widget.category == ProductCategory.PESTICIDE) {
          try {
            await _createDefaultPesticideUnits(createdProduct.id);
            await provider.refreshProductUnitsCache(createdProduct.id);
          } catch (e) {
            debugPrint('Failed to create default units for pesticide: $e');
            unitSetupError = e.toString();
          }
        }

        if (mounted) {
          setState(() {
            _productCreated = true; // Mark as created to prevent duplicate
          });

          final message = isComplete
              ? 'Đã tạo sản phẩm với đầy đủ thông tin!'
              : 'Đã tạo sản phẩm thành công!';

          if (unitSetupError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã tạo sản phẩm, vui lòng kiểm tra lại đơn vị bán hàng trong màn hình chỉnh sửa.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }

          // Show success dialog
          await _showSuccessDialog(message);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi tạo sản phẩm',
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

  void _saveWithCurrentInfo() {
    if (_productCreated) return; // Prevent duplicate creation
    _saveProduct(isComplete: false);
  }

  void _saveComplete() {
    if (_productCreated) return; // Prevent duplicate creation
    _saveProduct(isComplete: true);
  }

  Future<void> _showSuccessDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
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
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sản phẩm đã được thêm vào danh sách và sẵn sàng sử dụng.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog

                  // Pop all 3 wizard screens to return to product list
                  Navigator.of(context).pop(); // Pop step 3
                  Navigator.of(context).pop(); // Pop step 2
                  Navigator.of(context).pop(); // Pop step 1
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
