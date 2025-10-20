import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/bulk_product_entry.dart'; // For PesticidePackagingType
import '../services/product_unit_service.dart';
import '../utils/unit_display_formatter.dart';
import '../../../shared/services/base_service.dart';

/// Determines how price display should be resolved.
/// [defaultUnit] forces the default selling unit (used for PO detail, etc.).
/// [selectedUnit] respects the unit the user picked in the UI when available.
///
/// Keeping this enum here avoids scattering conversion rules in multiple files.
enum PriceDisplayMode { defaultUnit, selectedUnit }

/// Lightweight descriptor for presenting prices in the UI without leaking
/// formatting decisions outside of this provider.
class PriceDisplayInfo {
  final double basePrice;
  final double displayPrice;
  final ProductUnit displayUnit;
  final ProductUnit baseUnit;
  final ProductUnit? selectedUnit;
  final PriceDisplayMode mode;
  final String unitLabel;
  final String? hint;

  PriceDisplayInfo({
    required this.basePrice,
    required this.displayPrice,
    required this.displayUnit,
    required this.baseUnit,
    required this.selectedUnit,
    required this.mode,
    this.hint,
  }) : unitLabel = UnitDisplayFormatter.simpleUnitName(displayUnit);
}

/// ProductUnitProvider - Single Source of Truth for Product Unit Management
///
/// This provider centralizes all product unit business logic including:
/// - Fetching units with caching
/// - Replacing units atomically (prevents zombie units)
/// - Formatting stock display
/// - Managing unit configuration for different product categories
///
/// Usage:
/// ```dart
/// final provider = context.read<ProductUnitProvider>();
/// await provider.replaceUnitsForProduct(productId, category, config);
/// ```
class ProductUnitProvider extends ChangeNotifier {
  final _unitService = ProductUnitService();
  final Map<String, List<ProductUnit>> _unitCache = {};

  bool _isLoading = false;
  String _errorMessage = '';

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;


  /// Get units for product with caching
  /// Automatically refreshes cache if not present
  Future<List<ProductUnit>> getUnitsForProduct(
    String productId, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _unitCache.remove(productId);
    }

    if (_unitCache.containsKey(productId)) {
      return List<ProductUnit>.from(_unitCache[productId]!);
    }

    try {
      final units = await _unitService.getProductUnits(productId);
      _unitCache[productId] = units;
      return List<ProductUnit>.from(units);
    } catch (e) {
      _setError('Lỗi tải đơn vị sản phẩm: $e');
      return [];
    }
  }

  /// Replace units for product based on category configuration
  ///
  /// This is the main business logic method that handles unit replacement
  /// for all product categories. It prevents zombie units by using atomic
  /// database transaction.
  ///
  /// Config map keys:
  /// - For Fertilizer/Seed: 'bagWeight' (int), 'productPrice' (double)
  /// - For Pesticide: 'packagingType' (PesticidePackagingType), 'packageVolume' (int),
  ///   'packageQty' (int), 'baseUnit' (String), 'productPrice' (double)
  Future<void> replaceUnitsForProduct(
    String productId,
    ProductCategory category,
    Map<String, dynamic> config,
  ) async {
    _setLoading(true);

    try {
      final storeId = BaseService.getDefaultStoreId();
      final now = DateTime.now();
      List<ProductUnit> newUnits = [];

      if (category == ProductCategory.FERTILIZER || category == ProductCategory.SEED) {
        // Fertilizer/Seed: Create 2 units (kg + Bao)
        final bagWeight = config['bagWeight'] as int;
        final productPrice = config['productPrice'] as double;

        newUnits = [
          // Base unit: kg
          ProductUnit(
            id: '',
            productId: productId,
            unitName: 'kg',
            conversionFactor: 1.0,
            unitPrice: productPrice / bagWeight, // Giá/kg = Giá bao ÷ trọng lượng
            isDefaultSellingUnit: false,
            isActive: true,
            storeId: storeId,
            createdAt: now,
            updatedAt: now,
          ),
          // Default selling unit: Bao
          ProductUnit(
            id: '',
            productId: productId,
            unitName: 'Bao',
            conversionFactor: bagWeight.toDouble(),
            unitPrice: productPrice, // Giá đầy đủ cho Bao
            isDefaultSellingUnit: true,
            isActive: true,
            storeId: storeId,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      } else if (category == ProductCategory.PESTICIDE) {
        // Pesticide: Create 3 units (base + package + box)
        final packagingType = config['packagingType'] as PesticidePackagingType;
        final packageVolume = config['packageVolume'] as int;
        final packageQty = config['packageQty'] as int;
        final baseUnit = config['baseUnit'] as String;
        final productPrice = config['productPrice'] as double;

        final packageConfig = packagingDefaults[packagingType]!;
        final packageUnitName = '${packageConfig.displayName} ${packageVolume.toString()}$baseUnit';
        final boxConversionFactor = packageVolume * packageQty;

        newUnits = [
          // Base unit (ml/lít/g/kg)
          ProductUnit(
            id: '',
            productId: productId,
            unitName: baseUnit,
            conversionFactor: 1.0,
            unitPrice: productPrice / packageVolume, // Giá/đơn vị cơ sở
            isDefaultSellingUnit: false,
            isActive: true,
            storeId: storeId,
            createdAt: now,
            updatedAt: now,
          ),
          // Retail unit (Chai 500ml, Gói 50g, etc.)
          ProductUnit(
            id: '',
            productId: productId,
            unitName: packageUnitName,
            conversionFactor: packageVolume.toDouble(),
            unitPrice: productPrice, // Giá đầy đủ cho đơn vị bán lẻ
            isDefaultSellingUnit: true,
            isActive: true,
            storeId: storeId,
            createdAt: now,
            updatedAt: now,
          ),
          // Wholesale unit (Thùng)
          ProductUnit(
            id: '',
            productId: productId,
            unitName: 'Thùng',
            conversionFactor: boxConversionFactor.toDouble(),
            unitPrice: productPrice * packageQty, // Giá thùng = giá package × số lượng
            isDefaultSellingUnit: false,
            isActive: true,
            storeId: storeId,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      }

      // Call service to replace units atomically in database
      await _unitService.replaceUnits(productId, newUnits);

      // Clear cache for this product to force refresh
      _unitCache.remove(productId);

      _setLoading(false);
      _clearError();
      notifyListeners();

      debugPrint('✅ ProductUnitProvider: Replaced units for product $productId');
    } catch (e) {
      _setError('Lỗi thay thế đơn vị sản phẩm: $e');
      debugPrint('❌ ProductUnitProvider error: $e');
      rethrow;
    }
  }

  /// Format stock display using units
  ///
  /// Converts base stock quantity to display format using the most appropriate unit
  /// Example: 110000 ml → "110 Lít" or "2.2 Thùng"
  Future<String> getFormattedStock(String productId, double baseStock) async {
    try {
      final units = await getUnitsForProduct(productId);
      if (units.isEmpty) return baseStock.toStringAsFixed(1);

      // Use UnitDisplayFormatter for consistent formatting
      final defaultUnit = units.firstWhere(
        (u) => u.isDefaultSellingUnit,
        orElse: () => units.first,
      );

      final quantity = baseStock / defaultUnit.conversionFactor;
      return '${quantity.toStringAsFixed(1)} ${defaultUnit.unitName}';
    } catch (e) {
      return baseStock.toStringAsFixed(1);
    }
  }

  /// Get default selling unit for a product
  Future<ProductUnit?> getDefaultUnit(String productId) async {
    try {
      final units = await getUnitsForProduct(productId);
      return units.firstWhere(
        (u) => u.isDefaultSellingUnit,
        orElse: () => units.isNotEmpty ? units.first : throw Exception('No units found'),
      );
    } catch (e) {
      debugPrint('Error getting default unit: $e');
      return null;
    }
  }

  /// Clear unit cache for a specific product or all products
  void clearCache({String? productId}) {
    if (productId != null) {
      _unitCache.remove(productId);
    } else {
      _unitCache.clear();
    }
    notifyListeners();
  }

  PriceDisplayInfo? buildPriceDisplayFromUnits({
    required List<ProductUnit> units,
    required double basePrice,
    String? targetUnitId,
    PriceDisplayMode mode = PriceDisplayMode.defaultUnit,
  }) {
    if (units.isEmpty) return null;

    final baseUnit = _resolveBaseUnit(units);
    if (baseUnit == null) return null;

    final defaultUnit = UnitDisplayFormatter.defaultUnit(units) ?? baseUnit;
    final selectedUnit = _findUnitByIdOrName(units, targetUnitId);
    final displayUnit = _selectDisplayUnit(
      baseUnit: baseUnit,
      defaultUnit: defaultUnit,
      selectedUnit: selectedUnit,
      mode: mode,
    );

    final conversion = displayUnit.conversionFactor > 0
        ? displayUnit.conversionFactor
        : 1.0;
    final displayPrice = basePrice * conversion;

    String? hint;
    if (mode == PriceDisplayMode.selectedUnit &&
        defaultUnit.id != displayUnit.id) {
      final ratio =
          displayUnit.conversionFactor / defaultUnit.conversionFactor;
      if (ratio > 0) {
        hint =
            '1 ${displayUnit.unitName} = ${_formatRatio(ratio)} ${defaultUnit.unitName}';
      }
    }

    return PriceDisplayInfo(
      basePrice: basePrice,
      displayPrice: displayPrice,
      displayUnit: displayUnit,
      baseUnit: baseUnit,
      selectedUnit: selectedUnit,
      mode: mode,
      hint: hint,
    );
  }

  Future<PriceDisplayInfo?> getPriceDisplay({
    required String productId,
    required double basePrice,
    String? targetUnitId,
    PriceDisplayMode mode = PriceDisplayMode.defaultUnit,
    List<ProductUnit>? units,
  }) async {
    units ??= await getUnitsForProduct(productId);
    return buildPriceDisplayFromUnits(
      units: units,
      basePrice: basePrice,
      targetUnitId: targetUnitId,
      mode: mode,
    );
  }

  Future<ProductUnit?> resolveUnitForDisplay({
    required String productId,
    String? selectedUnitId,
    PriceDisplayMode mode = PriceDisplayMode.defaultUnit,
    List<ProductUnit>? units,
  }) async {
    units ??= await getUnitsForProduct(productId);
    if (units.isEmpty) return null;

    final baseUnit = _resolveBaseUnit(units);
    if (baseUnit == null) return null;

    final defaultUnit = UnitDisplayFormatter.defaultUnit(units) ?? baseUnit;
    final selectedUnit = _findUnitByIdOrName(units, selectedUnitId);
    return _selectDisplayUnit(
      baseUnit: baseUnit,
      defaultUnit: defaultUnit,
      selectedUnit: selectedUnit,
      mode: mode,
    );
  }

  double? convertPriceToBaseFromUnits({
    required List<ProductUnit> units,
    required double displayPrice,
    String? fromUnitId,
  }) {
    if (units.isEmpty) return displayPrice;

    final baseUnit =
        UnitDisplayFormatter.baseUnit(units) ?? _resolveBaseUnit(units);
    if (baseUnit == null) return displayPrice;

    final unit = _findUnitByIdOrName(units, fromUnitId) ?? baseUnit;
    final factor = unit.conversionFactor > 0 ? unit.conversionFactor : 1.0;
    if (factor == 0) return displayPrice;
    return displayPrice / factor;
  }

  Future<double?> convertPriceToBase({
    required String productId,
    required double displayPrice,
    String? fromUnitId,
    List<ProductUnit>? units,
  }) async {
    units ??= await getUnitsForProduct(productId);
    return convertPriceToBaseFromUnits(
      units: units,
      displayPrice: displayPrice,
      fromUnitId: fromUnitId,
    );
  }

  double? convertQuantityToBaseFromUnits({
    required List<ProductUnit> units,
    required double quantity,
    String? fromUnitId,
  }) {
    if (units.isEmpty) return quantity;

    final baseUnit =
        UnitDisplayFormatter.baseUnit(units) ?? _resolveBaseUnit(units);
    if (baseUnit == null || baseUnit.conversionFactor <= 0) {
      return quantity;
    }

    final unit = _findUnitByIdOrName(units, fromUnitId) ?? baseUnit;
    if (unit.conversionFactor <= 0) return quantity;

    return quantity * unit.conversionFactor;
  }

  Future<double?> convertQuantityToBase({
    required String productId,
    required double quantity,
    String? fromUnitId,
    List<ProductUnit>? units,
  }) async {
    units ??= await getUnitsForProduct(productId);
    return convertQuantityToBaseFromUnits(
      units: units,
      quantity: quantity,
      fromUnitId: fromUnitId,
    );
  }

  // Private helper methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
  }

  ProductUnit? _resolveBaseUnit(List<ProductUnit> units) {
    if (units.isEmpty) return null;
    final positives = units
        .where((unit) => unit.conversionFactor > 0)
        .toList()
      ..sort((a, b) => a.conversionFactor.compareTo(b.conversionFactor));
    return positives.isNotEmpty ? positives.first : units.first;
  }

  ProductUnit? _findUnitByIdOrName(List<ProductUnit> units, String? idOrName) {
    if (idOrName == null || idOrName.isEmpty) return null;
    try {
      return units.firstWhere((unit) => unit.id == idOrName);
    } catch (_) {
      try {
        return units.firstWhere(
          (unit) => unit.unitName.toLowerCase() == idOrName.toLowerCase(),
        );
      } catch (_) {
        return null;
      }
    }
  }

  ProductUnit _selectDisplayUnit({
    required ProductUnit baseUnit,
    required ProductUnit defaultUnit,
    required ProductUnit? selectedUnit,
    required PriceDisplayMode mode,
  }) {
    switch (mode) {
      case PriceDisplayMode.selectedUnit:
        return selectedUnit ?? defaultUnit;
      case PriceDisplayMode.defaultUnit:
        return defaultUnit;
    }
  }

  String _formatRatio(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
          RegExp(r'\.$'),
          '',
        );
  }
}
