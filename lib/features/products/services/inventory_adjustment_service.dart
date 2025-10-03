import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';

enum AdjustmentType {
  manual,
  voidBatch,
  stockCorrection,
  damage,
  theft,
}

extension AdjustmentTypeExtension on AdjustmentType {
  String get value {
    switch (this) {
      case AdjustmentType.manual:
        return 'manual';
      case AdjustmentType.voidBatch:
        return 'void_batch';
      case AdjustmentType.stockCorrection:
        return 'stock_correction';
      case AdjustmentType.damage:
        return 'damage';
      case AdjustmentType.theft:
        return 'theft';
    }
  }
}

class InventoryAdjustment {
  final String id;
  final String batchId;
  final double quantityChange;
  final String reason;
  final AdjustmentType adjustmentType;
  final DateTime createdAt;
  final String? userIdWhoAdjusted;
  final String storeId;
  final String? notes;

  InventoryAdjustment({
    required this.id,
    required this.batchId,
    required this.quantityChange,
    required this.reason,
    required this.adjustmentType,
    required this.createdAt,
    this.userIdWhoAdjusted,
    required this.storeId,
    this.notes,
  });

  factory InventoryAdjustment.fromJson(Map<String, dynamic> json) {
    return InventoryAdjustment(
      id: json['id'],
      batchId: json['batch_id'],
      quantityChange: (json['quantity_change'] as num).toDouble(),
      reason: json['reason'],
      adjustmentType: _parseAdjustmentType(json['adjustment_type']),
      createdAt: DateTime.parse(json['created_at']),
      userIdWhoAdjusted: json['user_id_who_adjusted'],
      storeId: json['store_id'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'quantity_change': quantityChange,
      'reason': reason,
      'adjustment_type': adjustmentType.value,
      'created_at': createdAt.toIso8601String(),
      'user_id_who_adjusted': userIdWhoAdjusted,
      'store_id': storeId,
      'notes': notes,
    };
  }

  static AdjustmentType _parseAdjustmentType(String? value) {
    switch (value) {
      case 'manual':
        return AdjustmentType.manual;
      case 'void_batch':
        return AdjustmentType.voidBatch;
      case 'stock_correction':
        return AdjustmentType.stockCorrection;
      case 'damage':
        return AdjustmentType.damage;
      case 'theft':
        return AdjustmentType.theft;
      default:
        return AdjustmentType.manual;
    }
  }
}

class InventoryAdjustmentService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create an inventory adjustment record
  Future<InventoryAdjustment> createAdjustment({
    required String batchId,
    required double quantityChange,
    required String reason,
    AdjustmentType adjustmentType = AdjustmentType.manual,
    String? notes,
  }) async {
    try {
      ensureAuthenticated();

      final adjustmentData = addStoreId({
        'batch_id': batchId,
        'quantity_change': quantityChange,
        'reason': reason,
        'adjustment_type': adjustmentType.value,
        'user_id_who_adjusted': _supabase.auth.currentUser?.id,
        'notes': notes,
      });

      final response = await _supabase
          .from('inventory_adjustments')
          .insert(adjustmentData)
          .select()
          .single();

      return InventoryAdjustment.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi tạo điều chỉnh tồn kho: $e');
    }
  }

  /// Void a batch (soft delete with inventory adjustment)
  /// This is used when a batch needs to be "deleted" but has sales history
  Future<bool> voidBatch(String batchId, String reason) async {
    try {
      ensureAuthenticated();

      // First, get the current quantity of the batch
      final batchResponse = await _supabase
          .from('product_batches')
          .select('quantity, sales_count, product_id')
          .eq('id', batchId)
          .single();

      final currentQuantity = (batchResponse['quantity'] as num).toDouble();
      final salesCount = (batchResponse['sales_count'] as num? ?? 0).toInt();
      final productId = batchResponse['product_id'];

      if (currentQuantity <= 0) {
        throw Exception('Lô hàng đã hết, không thể hủy');
      }

      // Calculate remaining quantity (what hasn't been sold)
      // Note: This assumes quantity in batch table is remaining quantity, not original
      final remainingQuantity = currentQuantity;

      // Create negative adjustment to "remove" the remaining stock
      await createAdjustment(
        batchId: batchId,
        quantityChange: -remainingQuantity,
        reason: reason,
        adjustmentType: AdjustmentType.voidBatch,
        notes: salesCount > 0
          ? 'Hủy lô hàng đã có $salesCount giao dịch bán'
          : 'Hủy lô hàng chưa có giao dịch',
      );

      // Mark batch as deleted (soft delete)
      await _supabase
          .from('product_batches')
          .update({
            'is_deleted': true,
            'quantity': 0, // Zero out the quantity
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', batchId);

      return true;
    } catch (e) {
      throw Exception('Lỗi hủy lô hàng: $e');
    }
  }

  /// Check if a batch can be edited (no sales transactions)
  Future<bool> canEditBatch(String batchId) async {
    try {
      ensureAuthenticated();

      final response = await _supabase
          .from('product_batches')
          .select('sales_count')
          .eq('id', batchId)
          .single();

      final salesCount = (response['sales_count'] as num? ?? 0).toInt();
      return salesCount == 0;
    } catch (e) {
      throw Exception('Lỗi kiểm tra quyền chỉnh sửa: $e');
    }
  }

  /// Check if a batch can be deleted (no sales transactions)
  Future<bool> canDeleteBatch(String batchId) async {
    return await canEditBatch(batchId);
  }

  /// Get adjustment history for a batch
  Future<List<InventoryAdjustment>> getBatchAdjustmentHistory(String batchId) async {
    try {
      ensureAuthenticated();

      final response = await _supabase
          .from('inventory_adjustments')
          .select()
          .eq('batch_id', batchId)
          .order('created_at', ascending: false);

      return response.map<InventoryAdjustment>((json) => InventoryAdjustment.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi tải lịch sử điều chỉnh: $e');
    }
  }

  /// Get all adjustments for a product
  Future<List<InventoryAdjustment>> getProductAdjustmentHistory(String productId) async {
    try {
      ensureAuthenticated();

      final response = await _supabase
          .from('inventory_adjustments')
          .select('''
            *,
            product_batches!inner(product_id)
          ''')
          .eq('product_batches.product_id', productId)
          .order('created_at', ascending: false);

      return response.map<InventoryAdjustment>((json) => InventoryAdjustment.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi tải lịch sử điều chỉnh sản phẩm: $e');
    }
  }

  /// Update sales count for a batch (called when items are sold from this batch)
  Future<void> incrementBatchSalesCount(String batchId, {int increment = 1}) async {
    try {
      ensureAuthenticated();

      await _supabase.rpc('increment_batch_sales_count', params: {
        'batch_id': batchId,
        'increment_by': increment,
      });
    } catch (e) {
      // If RPC doesn't exist, fall back to manual update
      try {
        final currentResponse = await _supabase
            .from('product_batches')
            .select('sales_count')
            .eq('id', batchId)
            .single();

        final currentCount = (currentResponse['sales_count'] as num? ?? 0).toInt();

        await _supabase
            .from('product_batches')
            .update({'sales_count': currentCount + increment})
            .eq('id', batchId);
      } catch (fallbackError) {
        throw Exception('Lỗi cập nhật số lần bán: $fallbackError');
      }
    }
  }
}