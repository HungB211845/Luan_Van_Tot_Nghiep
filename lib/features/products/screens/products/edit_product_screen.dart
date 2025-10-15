import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 🔥 NEW: For CupertinoSlidingSegmentedControl
import 'package:flutter/services.dart'; // 🔥 NEW: For FilteringTextInputFormatter
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../models/product_unit.dart';
import '../../models/fertilizer_attributes.dart';
import '../../models/pesticide_attributes.dart';
import '../../models/seed_attributes.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../services/product_unit_service.dart';
import '../../../../shared/services/base_service.dart';
import '../../../../shared/services/image_service.dart';
import '../../widgets/product_image_widget.dart';
import '../../models/bulk_product_entry.dart'; // 🔥 NEW: For Pesticide UOM config

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

  // Product Unit Service
  final ProductUnitService _unitService = ProductUnitService();
  List<ProductUnit> _productUnits = [];
  bool _isLoadingUnits = true;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _descriptionController;

  // Unit Config Controllers
  final _bagWeightController = TextEditingController(text: '50'); // Default 50kg per bag
  final _packageQtyController = TextEditingController(text: '20'); // Default 20 units per package
  final _packageVolumeController = TextEditingController(text: '500'); // Default 500ml per unit
  late PesticidePackagingType _selectedPesticidePackagingType; // 🔥 NEW
  late String _pesticideBaseUnit; // 🔥 NEW

  // Dropdown selections
  late ProductCategory _selectedCategory;
  String? _selectedCompanyId;

  // Attribute Controllers
  final _npkRatioController = TextEditingController();
  final _fertilizerTypeController = TextEditingController();
  // 🔥 REMOVED: _weightController and _weightUnitController - now configured in "Đơn Vị Bán Hàng" section
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
    _loadExistingUnits();

    // Track changes
    _nameController.addListener(() => setState(() => _hasChanges = true));
    _skuController.addListener(() => setState(() => _hasChanges = true));
    _descriptionController.addListener(() => setState(() => _hasChanges = true));
    _bagWeightController.addListener(() => setState(() => _hasChanges = true));
    _packageQtyController.addListener(() => setState(() => _hasChanges = true));
    _packageVolumeController.addListener(() => setState(() => _hasChanges = true));

    // Initialize new pesticide unit config state with defaults
    _selectedPesticidePackagingType = PesticidePackagingType.bottle;
    _pesticideBaseUnit = 'ml';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  Future<void> _loadExistingUnits() async {
    try {
      final units = await _unitService.getProductUnits(widget.product.id);
      if (mounted) {
        setState(() {
          _productUnits = units;
          _isLoadingUnits = false;
        });

        if (units.isEmpty) {
          return;
        }

        // Populate controllers from existing units
        if (_selectedCategory == ProductCategory.FERTILIZER || _selectedCategory == ProductCategory.SEED) {
          // Find "Bao" unit
          final bagUnit = units.firstWhere(
            (u) => u.unitName.toLowerCase() == 'bao',
            orElse: () => units.first,
          );
          _bagWeightController.text = bagUnit.conversionFactor.toInt().toString();
        } else if (_selectedCategory == ProductCategory.PESTICIDE) {
          // Find main selling unit (default unit)
          final mainUnit = units.firstWhere(
            (u) => u.isDefaultSellingUnit,
            orElse: () => units.isNotEmpty ? units.first : ProductUnit(
              id: '', productId: widget.product.id, unitName: 'Chai 500ml', conversionFactor: 500, unitPrice: 0, storeId: '', createdAt: DateTime.now(), updatedAt: DateTime.now()
            ), // Fallback to a default unit
          );

          // Find the "Thùng" (box) unit to get package quantity
          final boxUnit = units.firstWhere(
            (u) => u.unitName.toLowerCase() == 'thùng',
            orElse: () => mainUnit, // Fallback to mainUnit if no box unit
          );

          // Parse unit name like "Chai 500ml" → extract volume and type
          final unitName = mainUnit.unitName;
          PesticidePackagingType? detectedPackageType;
          String? detectedBaseUnit;
          double? detectedVolume;

          // Try to match unitName with packagingDefaults
          for (var entry in packagingDefaults.entries) {
            final type = entry.key;
            final config = entry.value;
            // Check if unitName contains the display name (e.g., "Chai")
            if (unitName.contains(config.displayName)) {
              detectedPackageType = type;
              // Extract volume and base unit from unitName (e.g., "Chai 500ml")
              final volumeMatch = RegExp(r'(\d+)([a-zA-Z]+)').firstMatch(unitName);
              if (volumeMatch != null) {
                detectedVolume = double.tryParse(volumeMatch.group(1)!);
                detectedBaseUnit = volumeMatch.group(2)!;
              }
              break;
            }
          }

          // Fallback if parsing from unitName fails
          _selectedPesticidePackagingType = detectedPackageType ?? PesticidePackagingType.bottle;
          _pesticideBaseUnit = detectedBaseUnit ?? packagingDefaults[_selectedPesticidePackagingType]!.defaultBaseUnit;
          _packageVolumeController.text = detectedVolume?.toStringAsFixed(0) ?? '500'; // Default to 500 if not found

          // Calculate package quantity (qty per box)
          // boxUnit.conversionFactor = packageQty * mainUnit.conversionFactor
          // packageQty = boxUnit.conversionFactor / mainUnit.conversionFactor
          if (mainUnit.conversionFactor > 0) {
            final calculatedQty = boxUnit.conversionFactor / mainUnit.conversionFactor;
            _packageQtyController.text = calculatedQty.toInt().toString();
          } else {
            _packageQtyController.text = '20'; // Default
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
      }
      debugPrint('Error loading product units: $e');
    }
  }

  void _populateAttributeControllers() {
    final attrs = widget.product.attributes;
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        final fertilizerAttrs = FertilizerAttributes.fromJson(attrs);
        _npkRatioController.text = fertilizerAttrs.npkRatio;
        _fertilizerTypeController.text = fertilizerAttrs.type;
        // 🔥 REMOVED: Weight/unit no longer populated from attributes
        // These are now configured in "Đơn Vị Bán Hàng" section
        break;
      case ProductCategory.PESTICIDE:
        final pesticideAttrs = PesticideAttributes.fromJson(attrs);
        _activeIngredientController.text = pesticideAttrs.activeIngredient ?? '';
        _concentrationController.text = pesticideAttrs.concentration ?? '';
        _volumeController.text = pesticideAttrs.volume != null ? pesticideAttrs.volume!.toString() : '';
        _volumeUnitController.text = pesticideAttrs.unit ?? '';
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
    _bagWeightController.dispose();
    _packageQtyController.dispose();
    _packageVolumeController.dispose();
    _npkRatioController.dispose();
    _fertilizerTypeController.dispose();
    // 🔥 REMOVED: _weightController and _weightUnitController disposal
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
      // Determine base unit based on category
      String? baseUnit;
      if (_selectedCategory == ProductCategory.FERTILIZER || _selectedCategory == ProductCategory.SEED) {
        baseUnit = 'kg'; // Fertilizer & Seed use kg as base unit
      } else if (_selectedCategory == ProductCategory.PESTICIDE) {
        baseUnit = _pesticideBaseUnit; // Pesticide uses ml or lít
      }

      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        category: _selectedCategory,
        companyId: _selectedCompanyId,
        imageUrl: _imageUrl,
        attributes: _buildAttributes(),
        baseUnit: baseUnit, // Set base unit
        updatedAt: DateTime.now(),
      );

      final provider = context.read<ProductProvider>();
      final success = await provider.updateProduct(updatedProduct);

      if (success && mounted) {
        // Save product units after product saved successfully
        try {
          await _saveProductUnits(widget.product.id);
          // 🔥 CRITICAL: Reload units cache after successful save
          await _loadExistingUnits();
        } catch (e) {
          debugPrint('Warning: Product saved but units failed: $e');
          // Continue anyway - product is saved, units can be fixed later
        }

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

  /// Save product units based on category-specific config
  Future<void> _saveProductUnits(String productId) async {
    try {
      // 🔥 STEP 1: Get product's current selling price for unit price calculation
      final productPrice = widget.product.currentSellingPrice; // 🔥 FIXED: Use currentSellingPrice (not currentPrice)
      debugPrint('🔥 DEBUG: Product ${widget.product.name} currentSellingPrice = $productPrice');
      
      if (_selectedCategory == ProductCategory.FERTILIZER || _selectedCategory == ProductCategory.SEED) {
        // Fertilizer/Seed: Create "Bao" and "kg" units
        final bagWeight = int.tryParse(_bagWeightController.text.trim()) ?? 50;

        // 🔥 STEP 2: Calculate unit prices based on conversion factors
        final bagPrice = productPrice; // 1 Bao = full product price (660K)
        final kgPrice = productPrice / bagWeight; // 1 kg = product price ÷ bag weight (660K ÷ 50 = 13.2K)
        debugPrint('🔥 DEBUG: bagWeight=$bagWeight, bagPrice=$bagPrice, kgPrice=$kgPrice');

        // 🔥 CRITICAL: Handle existing inconsistent data
        // First, ensure only one default unit exists by updating existing units
        
        // Find existing units
        ProductUnit? existingBagUnit;
        ProductUnit? existingKgUnit;
        ProductUnit? existingDefaultUnit;
        
        for (final unit in _productUnits) {
          if (unit.unitName.toLowerCase() == 'bao') {
            existingBagUnit = unit;
          } else if (unit.unitName.toLowerCase() == 'kg') {
            existingKgUnit = unit;
          }
          if (unit.isDefaultSellingUnit) {
            existingDefaultUnit = unit;
          }
        }

        // 🔥 STRATEGY: Update existing units to match desired structure
        
        // Step 1: Update existing kg unit to be base unit (factor=1, not default)
        if (existingKgUnit != null) {
          await _unitService.updateProductUnit(
            existingKgUnit.copyWith(
              conversionFactor: 1.0, // Ensure kg is base unit
              isDefaultSellingUnit: false, // kg should not be default
              unitPrice: kgPrice, // 🔥 FIXED: Set calculated kg price
            ),
          );
        } else {
          // Create new kg base unit
          await _unitService.createProductUnit(
            ProductUnit(
              id: '',
              productId: productId,
              unitName: 'kg',
              conversionFactor: 1.0,
              unitPrice: kgPrice, // 🔥 FIXED: Set calculated kg price
              isDefaultSellingUnit: false,
              isActive: true,
              storeId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Step 2: Handle Bao unit (should be default)
        if (existingBagUnit != null) {
          await _unitService.updateProductUnit(
            existingBagUnit.copyWith(
              conversionFactor: bagWeight.toDouble(),
              isDefaultSellingUnit: true, // Bao should be default
              unitPrice: bagPrice, // 🔥 FIXED: Set full product price for Bao
            ),
          );
        } else {
          // If no existing Bao unit, but there's another default unit, 
          // we need to remove its default status first
          if (existingDefaultUnit != null && existingDefaultUnit.unitName.toLowerCase() != 'bao') {
            await _unitService.updateProductUnit(
              existingDefaultUnit.copyWith(isDefaultSellingUnit: false),
            );
          }
          
          // Create new Bao default unit
          await _unitService.createProductUnit(
            ProductUnit(
              id: '',
              productId: productId,
              unitName: 'Bao',
              conversionFactor: bagWeight.toDouble(),
              unitPrice: bagPrice, // 🔥 FIXED: Set full product price for Bao
              isDefaultSellingUnit: true,
              isActive: true,
              storeId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

      } else if (_selectedCategory == ProductCategory.PESTICIDE) {
        // Pesticide: Create "Chai 500ml", "Thùng", and "ml" units
        final packageQty = int.tryParse(_packageQtyController.text.trim()) ?? 20;
        final volume = int.tryParse(_packageVolumeController.text.trim()) ?? 500;
        
        // Determine the correct base unit and its conversion factor
        // Example: if _pesticideBaseUnit is 'lít', and volume is 0.5, conversionFactor is 0.5
        // if _pesticideBaseUnit is 'ml', and volume is 500, conversionFactor is 500
        // if _pesticideBaseUnit is 'kg', and volume is 50, conversionFactor is 50
        double baseUnitConversionFactor = volume.toDouble();
        // No need for if/else if, as volume is already in the correct base unit
        // The conversion factor for the package unit is simply its volume/weight value
        
        final packageUnitName = '${packagingDefaults[_selectedPesticidePackagingType]!.displayName} ${volume.toStringAsFixed(0)}$_pesticideBaseUnit';

        final boxConversionFactor = packageQty * baseUnitConversionFactor;

        // Calculate pesticide unit prices
        final packagePrice = productPrice; // Package unit = full product price
        final baseUnitPrice = productPrice / baseUnitConversionFactor; // Base unit = price ÷ conversion factor
        final boxPrice = productPrice * packageQty; // Box price = package price × quantity per box

        // Handle existing units properly to avoid default conflicts
        ProductUnit? existingMainUnit;
        ProductUnit? existingBaseUnit;
        ProductUnit? existingBoxUnit;
        ProductUnit? existingDefaultUnit;
        
        for (final unit in _productUnits) {
          if (unit.unitName.toLowerCase() == packageUnitName.toLowerCase()) {
            existingMainUnit = unit;
          }
          if (unit.unitName.toLowerCase() == _pesticideBaseUnit.toLowerCase()) {
            existingBaseUnit = unit;
          }
          if (unit.unitName.toLowerCase() == 'thùng') {
            existingBoxUnit = unit;
          }
          if (unit.isDefaultSellingUnit) {
            existingDefaultUnit = unit;
          }
        }

        // Step 1: Update base unit (ml/lít/g/kg) - should not be default
        if (existingBaseUnit != null) {
          await _unitService.updateProductUnit(
            existingBaseUnit.copyWith(
              unitName: _pesticideBaseUnit,
              conversionFactor: 1.0, // Base unit always has conversion factor 1
              isDefaultSellingUnit: false,
              unitPrice: baseUnitPrice,
            ),
          );
        } else {
          await _unitService.createProductUnit(
            ProductUnit(
              id: '',
              productId: productId,
              unitName: _pesticideBaseUnit,
              conversionFactor: 1.0,
              unitPrice: baseUnitPrice,
              isDefaultSellingUnit: false,
              isActive: true,
              storeId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Step 2: Update main selling unit (Chai 500ml, Gói 50g, etc.) - should be default
        if (existingMainUnit != null) {
          await _unitService.updateProductUnit(
            existingMainUnit.copyWith(
              unitName: packageUnitName,
              conversionFactor: baseUnitConversionFactor,
              isDefaultSellingUnit: true,
              unitPrice: packagePrice,
            ),
          );
        } else {
          // Clear any existing default before creating new one
          if (existingDefaultUnit != null && existingDefaultUnit.unitName.toLowerCase() != packageUnitName.toLowerCase()) {
            await _unitService.updateProductUnit(
              existingDefaultUnit.copyWith(isDefaultSellingUnit: false),
            );
          }
          
          await _unitService.createProductUnit(
            ProductUnit(
              id: '',
              productId: productId,
              unitName: packageUnitName,
              conversionFactor: baseUnitConversionFactor,
              unitPrice: packagePrice,
              isDefaultSellingUnit: true,
              isActive: true,
              storeId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }

        // Step 3: Create/update "Thùng" unit for wholesale purchase
        if (existingBoxUnit != null) {
          await _unitService.updateProductUnit(
            existingBoxUnit.copyWith(
              unitName: 'Thùng',
              conversionFactor: boxConversionFactor,
              isDefaultSellingUnit: false,
              unitPrice: boxPrice,
            ),
          );
        } else {
          await _unitService.createProductUnit(
            ProductUnit(
              id: '',
              productId: productId,
              unitName: 'Thùng',
              conversionFactor: boxConversionFactor,
              unitPrice: boxPrice,
              isDefaultSellingUnit: false,
              isActive: true,
              storeId: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving product units: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _buildAttributes() {
    switch (_selectedCategory) {
      case ProductCategory.FERTILIZER:
        return FertilizerAttributes(
          npkRatio: _npkRatioController.text.trim(),
          type: _fertilizerTypeController.text.trim(),
          weight: 1, // 🔥 FIXED: Default value (not displayed to user)
          unit: 'bao', // 🔥 FIXED: Default unit (actual unit comes from ProductUnit table)
        ).toJson();
      case ProductCategory.PESTICIDE:
        final activeIngredient = _activeIngredientController.text.trim();
        final concentration = _concentrationController.text.trim();
        final volumeText = _volumeController.text.trim();
        final unitText = _volumeUnitController.text.trim();
        return PesticideAttributes(
          activeIngredient: activeIngredient.isEmpty ? null : activeIngredient,
          concentration: concentration.isEmpty ? null : concentration,
          volume: volumeText.isEmpty ? null : double.tryParse(volumeText),
          unit: unitText.isEmpty ? null : unitText,
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

                const SizedBox(height: 20),

                // Unit Config Section
                if (!_isLoadingUnits)
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
                            'Đơn Vị Bán Hàng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        _buildUnitConfigForm(),
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
          decoration: _buildInputDecoration(label: 'Tỷ lệ NPK', icon: Icons.science),
          // Allow empty - NPK ratio is optional
          validator: null,
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
        // 🔥 REMOVED: Weight/Unit fields - now configured in "Đơn Vị Bán Hàng" section
        // This eliminates confusion between attribute metadata and actual selling units
      ],
    );
  }

  Widget _buildPesticideForm() {
    final volumeUnitOptions = ['ml', 'lít', 'chai', 'gói', 'lọ'];
    String? selectedVolumeUnit;
    final rawVolumeUnit = _volumeUnitController.text.trim();
    if (rawVolumeUnit.isNotEmpty) {
      try {
        selectedVolumeUnit = volumeUnitOptions.firstWhere(
          (unit) => unit.toLowerCase() == rawVolumeUnit.toLowerCase(),
        );
      } catch (_) {
        selectedVolumeUnit = null;
      }
    }

    return Column(
      children: [
        TextFormField(
          controller: _activeIngredientController,
          decoration: _buildInputDecoration(label: 'Hoạt chất chính (Tùy chọn)', icon: Icons.biotech),
          validator: (_) => null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _concentrationController,
          decoration: _buildInputDecoration(label: 'Nồng độ (Tùy chọn)'),
          validator: (_) => null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _volumeController,
                decoration: _buildInputDecoration(label: 'Thể tích (Tùy chọn)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return double.tryParse(value.trim()) == null ? 'Nhập số hợp lệ' : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedVolumeUnit,
                decoration: _buildInputDecoration(label: 'Đơn vị (Tùy chọn)'),
                items: volumeUnitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() {
                  _volumeUnitController.text = v?.trim() ?? '';
                  _hasChanges = true;
                }),
                validator: (value) {
                  final volumeText = _volumeController.text.trim();
                  if (volumeText.isEmpty) {
                    return null;
                  }
                  if ((value ?? '').isEmpty) {
                    return 'Chọn đơn vị';
                  }
                  return null;
                },
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

  /// Unit Config Form - Different UI based on category
  Widget _buildUnitConfigForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: _selectedCategory == ProductCategory.FERTILIZER || _selectedCategory == ProductCategory.SEED
          ? _buildFertilizerSeedUnitConfig()
          : _buildPesticideUnitConfig(),
    );
  }

  /// Fertilizer & Seed: Simple bag weight input
  Widget _buildFertilizerSeedUnitConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trọng lượng mỗi bao (kg)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bagWeightController,
          decoration: _buildInputDecoration(
            label: 'VD: 50',
            icon: Icons.scale,
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v?.trim().isEmpty ?? true) return 'Nhập trọng lượng';
            final num = int.tryParse(v!.trim());
            if (num == null || num <= 0) return 'Nhập số hợp lệ';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Hệ thống sẽ tự tạo 2 đơn vị: "Bao" (${_bagWeightController.text}kg) và "kg" (1kg)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildPesticideUnitConfig() {
    final currentPackageConfig = packagingDefaults[_selectedPesticidePackagingType]!;
    final currentBaseUnitOptions = currentPackageConfig.baseUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quy cách đóng gói',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),

        // CupertinoSlidingSegmentedControl for Package Type
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<PesticidePackagingType>(
            groupValue: _selectedPesticidePackagingType,
            backgroundColor: Colors.grey.shade200,
            thumbColor: Colors.green, // Match app theme
            onValueChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPesticidePackagingType = value;
                  _pesticideBaseUnit = packagingDefaults[value]!.defaultBaseUnit; // Update base unit based on new package type
                  _hasChanges = true;
                });
              }
            },
            children: {
              for (var type in PesticidePackagingType.values)
                type: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    packagingDefaults[type]!.displayName,
                    style: TextStyle(
                      color: _selectedPesticidePackagingType == type
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
            },
          ),
        ),

        const SizedBox(height: 16),

        // First row: Quantity + Volume
        Row(
          children: [
            // Quantity input
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mỗi thùng chứa',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _packageQtyController,
                    decoration: _buildInputDecoration(label: 'Số lượng'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Nhập số lượng';
                      final num = int.tryParse(v!.trim());
                      if (num == null || num <= 0) return 'Số hợp lệ';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Volume input
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dung tích/Khối lượng',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _packageVolumeController,
                    decoration: _buildInputDecoration(label: 'VD: 500'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Nhập giá trị';
                      final num = int.tryParse(v!.trim());
                      if (num == null || num <= 0) return 'Số hợp lệ';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Base unit dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đơn vị cơ sở',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(value: _pesticideBaseUnit,
              decoration: _buildInputDecoration(label: 'Đơn vị'),
              items: currentBaseUnitOptions.map((unit) {
                return DropdownMenuItem(value: unit, child: Text(unit));
              }).toList(),
              onChanged: (v) => setState(() {
                _pesticideBaseUnit = v ?? currentBaseUnitOptions.first;
                _hasChanges = true;
              }),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Helper text
        Text(
          'Hệ thống sẽ tự tạo 3 đơn vị:\n'
          '• "${currentPackageConfig.displayName} ${_packageVolumeController.text}$_pesticideBaseUnit" (bán lẻ)\n'
          '• "Thùng" (${_packageQtyController.text} ${currentPackageConfig.displayName}, nhập hàng)\n'
          '• "$_pesticideBaseUnit" (đơn vị cơ sở)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
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
