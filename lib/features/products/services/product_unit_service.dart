import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/product_unit.dart';

/// Service for managing product units (Multi-UoM system)
/// Handles CRUD operations for product_units table
class ProductUnitService extends BaseService {
  /// Get all active units for a product using RPC function
  /// Returns list ordered by: default unit first, then alphabetically
  Future<List<ProductUnit>> getProductUnits(String productId) async {
    ensureAuthenticated();

    try {
      final response = await supabase.rpc(
        'get_product_units',
        params: {'p_product_id': productId},
      ) as List<dynamic>;

      return response
          .map((json) => ProductUnit.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load product units: $e');
    }
  }

  /// Get default selling unit for a product
  /// Returns null if no default unit is set
  Future<ProductUnit?> getDefaultUnit(String productId) async {
    final units = await getProductUnits(productId);
    try {
      return units.firstWhere((unit) => unit.isDefaultSellingUnit);
    } catch (e) {
      return null; // No default unit found
    }
  }

  /// Create new product unit
  /// Note: Cannot have duplicate unit_name for same product in same store
  Future<ProductUnit> createProductUnit(ProductUnit unit) async {
    ensureAuthenticated();

    try {
      final data = addStoreId(unit.toJson());

      final response = await supabase
          .from('product_units')
          .insert(data)
          .select()
          .single();

      return ProductUnit.fromJson(response);
    } catch (e) {
      if (e.toString().contains('product_units_unique_name_per_product')) {
        throw Exception('Đơn vị "${unit.unitName}" đã tồn tại cho sản phẩm này');
      }
      throw Exception('Failed to create product unit: $e');
    }
  }

  /// Update existing product unit
  /// Cannot change product_id or store_id
  Future<ProductUnit> updateProductUnit(ProductUnit unit) async {
    ensureAuthenticated();

    try {
      final data = unit.toJson();
      // Remove fields that shouldn't be updated
      data.remove('product_id');
      data.remove('store_id');

      final response = await supabase
          .from('product_units')
          .update(data)
          .eq('id', unit.id)
          .eq('store_id', getValidStoreId()) // Ensure store isolation
          .select()
          .single();

      return ProductUnit.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update product unit: $e');
    }
  }

  /// Soft delete product unit (set is_active = false)
  /// Cannot delete if it's the only active unit for the product
  Future<void> deleteProductUnit(String unitId) async {
    ensureAuthenticated();

    try {
      // Check if this is the last active unit
      final unit = await supabase
          .from('product_units')
          .select('product_id')
          .eq('id', unitId)
          .eq('store_id', getValidStoreId())
          .single();

      final productId = unit['product_id'] as String;
      final activeUnits = await getProductUnits(productId);

      if (activeUnits.length <= 1) {
        throw Exception('Không thể xóa đơn vị cuối cùng của sản phẩm');
      }

      // Soft delete
      await supabase
          .from('product_units')
          .update({'is_active': false})
          .eq('id', unitId)
          .eq('store_id', getValidStoreId());
    } catch (e) {
      throw Exception('Failed to delete product unit: $e');
    }
  }

  /// Set a unit as the default selling unit for a product
  /// Automatically unsets previous default unit
  /// Uses database UNIQUE partial index to enforce one default per product
  Future<void> setDefaultUnit(String productId, String unitId) async {
    ensureAuthenticated();

    try {
      // Step 1: Unset all defaults for this product
      await supabase
          .from('product_units')
          .update({'is_default_selling_unit': false})
          .eq('product_id', productId)
          .eq('store_id', getValidStoreId());

      // Step 2: Set new default
      // Database unique index ensures only one default per product
      await supabase
          .from('product_units')
          .update({'is_default_selling_unit': true})
          .eq('id', unitId)
          .eq('store_id', getValidStoreId());
    } catch (e) {
      throw Exception('Failed to set default unit: $e');
    }
  }

  /// Check if enough stock is available for given quantity and unit
  /// Uses RPC function that handles unit conversion and base unit calculation
  Future<bool> checkStockAvailability({
    required String productId,
    required double quantity,
    required String unitId,
  }) async {
    ensureAuthenticated();

    try {
      final result = await supabase.rpc(
        'check_stock_availability',
        params: {
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_unit_id': unitId,
        },
      ) as bool;

      return result;
    } catch (e) {
      throw Exception('Failed to check stock availability: $e');
    }
  }

  /// Get available stock in base unit for a product
  /// Uses RPC function to sum all available batches
  Future<double> getAvailableStockBaseUnit(String productId) async {
    ensureAuthenticated();

    try {
      final result = await supabase.rpc(
        'get_available_stock_base_unit',
        params: {'p_product_id': productId},
      ) as num;

      return result.toDouble();
    } catch (e) {
      throw Exception('Failed to get available stock: $e');
    }
  }

  /// Convert quantity from one unit to base unit
  /// Helper method for client-side calculations
  double convertToBaseUnit({
    required double quantity,
    required double conversionFactor,
  }) {
    return quantity * conversionFactor;
  }

  /// Convert quantity from base unit to specific unit
  /// Helper method for client-side calculations
  double convertFromBaseUnit({
    required double baseQuantity,
    required double conversionFactor,
  }) {
    if (conversionFactor == 0) return 0;
    return baseQuantity / conversionFactor;
  }
}
