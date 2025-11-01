import 'package:flutter/foundation.dart';
import '../../products/models/product.dart';
import '../../products/models/product_unit.dart';
import '../../products/services/product_service.dart';
import '../../products/services/product_unit_service.dart';
import '../../products/utils/unit_display_formatter.dart';
import '../models/notification_message.dart';
import '../models/notification_preferences.dart';
import '../utils/inventory_threshold_helper.dart';

/// Central place to build notifications (inventory alerts for now).
class NotificationService {
  final ProductService _productService = ProductService();
  final ProductUnitService _unitService = ProductUnitService();

  /// Fetch notifications by combining multiple data sources.
  Future<List<NotificationMessage>> fetchInventoryNotifications({
    required NotificationPreferences preferences,
    required Map<String, double> thresholds,
  }) async {
    final notifications = <NotificationMessage>[];

    try {
      final expiring = await _productService.getExpiringBatches();
      final now = DateTime.now();
      for (final batch in expiring) {
        final expiryRaw = batch['expiry_date'] ?? batch['expiryDate'];
        if (expiryRaw == null) continue;

        final expiryDate = DateTime.tryParse(expiryRaw.toString());
        if (expiryDate == null) continue;

        final days = expiryDate.difference(now).inDays;
        NotificationSeverity? severity;
        int? expiryDays;
        if (days < 0) {
          severity = NotificationSeverity.danger;
          expiryDays = days;
        } else if (days <= 30) {
          severity = NotificationSeverity.warning;
          expiryDays = days;
        } else if (days <= 60) {
          severity = NotificationSeverity.info;
          expiryDays = days;
        } else if (days <= 90) {
          severity = NotificationSeverity.info;
          expiryDays = days;
        } else {
          severity = null;
        }

        if (severity == null) continue;
        final productId = batch['product_id']?.toString() ??
            batch['productId']?.toString() ??
            '';
        final productName =
            batch['product_name'] ?? batch['productName'] ?? '';
        final batchNumber =
            batch['batch_number'] ?? batch['batchNumber'] ?? '';

        notifications.add(
          NotificationMessage(
            id: 'expiry-$batchNumber-${expiryDate.toIso8601String()}',
            title: days < 0
                ? 'Lô đã hết hạn'
                : 'Lô sắp hết hạn ($days ngày)',
            body:
                '$productName • Mã lô $batchNumber • Hết hạn ${_formatDate(expiryDate)}',
            createdAt: now,
            severity: severity,
            topic: NotificationTopic.batchExpiry,
            expiryDays: expiryDays,
            productId: productId.isEmpty ? null : productId,
            batchId: batch['id']?.toString(),
            batchNumber: batchNumber.isEmpty ? null : batchNumber,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService.fetchInventoryNotifications expiring error: $e');
    }

    try {
      notifications.addAll(
        await _buildLowStockNotifications(
          thresholds: thresholds,
        ),
      );
    } catch (e) {
      debugPrint(
        'NotificationService.fetchInventoryNotifications low stock error: $e',
      );
    }

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatQuantity(
    double baseQuantity, {
    required List<ProductUnit> units,
    required String baseUnitName,
  }) {
    if (units.isEmpty) {
      if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
        return _formatNumber(baseQuantity);
      }
      return '${_formatNumber(baseQuantity)} ${baseUnitName.toLowerCase()}';
    }

    final preferred = UnitDisplayFormatter.preferredQuantity(
      baseQuantity: baseQuantity,
      units: units,
      baseUnitName: baseUnitName,
    );

    if (preferred == null) {
      if (baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị') {
        return _formatNumber(baseQuantity);
      }
      return '${_formatNumber(baseQuantity)} ${baseUnitName.toLowerCase()}';
    }

    final value =
        UnitDisplayFormatter.formatQuantityValue(preferred.primaryQuantity);
    final unitLabel = UnitDisplayFormatter.simpleUnitName(preferred.unit);
    return '$value $unitLabel';
  }

  ProductCategory? _parseCategory(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return ProductCategory.values
          .firstWhere((element) => element.name == raw);
    } catch (_) {
      final upper = raw.toUpperCase();
      try {
        return ProductCategory.values
            .firstWhere((element) => element.name.toUpperCase() == upper);
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<NotificationMessage>> _buildLowStockNotifications({
    required Map<String, double> thresholds,
  }) async {
    final results = <NotificationMessage>[];
    final unitCache = <String, List<ProductUnit>>{};

    final response = await _fetchBatchesWithProduct();
    final now = DateTime.now();

    for (final row in response) {
      final productId = row['product_id']?.toString();
      final batchId = row['id']?.toString();
      if (productId == null || productId.isEmpty || batchId == null) {
        continue;
      }

      final batchNumber = (row['batch_number'] ?? '').toString();
      final quantity = (row['quantity'] as num?)?.toDouble() ?? 0;
      final productJson = row['products'] as Map<String, dynamic>?;
      final productName = productJson?['name']?.toString() ?? 'Sản phẩm';
      final minStock =
          (productJson?['min_stock_level'] as num?)?.toDouble() ?? 0;
      final category = _parseCategory(productJson?['category']?.toString());
      final baseUnitFallback =
          (productJson?['base_unit'] ?? '').toString();

      List<ProductUnit> units = unitCache[productId] ?? const [];
      if (units.isEmpty) {
        try {
          units = await _unitService.getProductUnits(productId);
        } catch (e) {
          debugPrint(
            'NotificationService: failed to load units for $productId: $e',
          );
          units = const [];
        }
        unitCache[productId] = units;
      }

      final thresholdBase = InventoryThresholdHelper.resolveLowStockThreshold(
        minStockLevel: minStock,
        units: units,
        thresholds: thresholds,
        category: category,
      );

      final severity = quantity <= 0
          ? NotificationSeverity.danger
          : (quantity <= thresholdBase ? NotificationSeverity.warning : null);

      if (severity == null) {
        continue;
      }

      final resolvedBaseUnit = UnitDisplayFormatter.resolveBaseUnitName(
        units: units,
        fallback: baseUnitFallback,
      );

      final quantityLabel = _formatQuantity(
        quantity,
        units: units,
        baseUnitName: resolvedBaseUnit,
      );
      final thresholdLabel = _formatQuantity(
        thresholdBase,
        units: units,
        baseUnitName: resolvedBaseUnit,
      );

      String body;
      if (severity == NotificationSeverity.danger) {
        body = '$productName • Mã lô $batchNumber • Đã hết hàng';
      } else {
        body = '$productName • Mã lô $batchNumber • Còn $quantityLabel '
            '(ngưỡng $thresholdLabel)';
      }

      results.add(
        NotificationMessage(
          id: 'lowstock-batch-$batchId',
          title: severity == NotificationSeverity.danger
              ? 'Lô đã hết hàng'
              : 'Lô sắp hết hàng',
          body: body,
          createdAt: now,
          severity: severity,
          topic: NotificationTopic.batchLowStock,
          productId: productId,
          batchId: batchId,
          batchNumber: batchNumber.isEmpty ? null : batchNumber,
        ),
      );
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> _fetchBatchesWithProduct() async {
    final response = await _productService
        .addStoreFilter(
          _productService.supabase.from('product_batches').select('''
              id,
              product_id,
              batch_number,
              quantity,
              cost_price,
              expiry_date,
              received_date,
              products:products!inner(
                id,
                name,
                category,
                min_stock_level,
                base_unit
              )
            '''),
        )
        .eq('is_available', true)
        .order('quantity', ascending: true);

    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

}
