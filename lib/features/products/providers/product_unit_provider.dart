import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/bulk_product_entry.dart'; // For PesticidePackagingType
import '../services/product_unit_service.dart';
import '../utils/unit_display_formatter.dart';
import '../../../shared/services/base_service.dart';

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
}
