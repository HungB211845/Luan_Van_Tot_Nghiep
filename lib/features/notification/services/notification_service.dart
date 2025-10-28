import 'package:flutter/foundation.dart';
import '../../products/services/product_service.dart';
import '../models/notification_message.dart';

/// Central place to build notifications (inventory alerts for now).
class NotificationService {
  final ProductService _productService = ProductService();

  /// Fetch notifications by combining multiple data sources.
  Future<List<NotificationMessage>> fetchInventoryNotifications() async {
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
        final productName = batch['product_name'] ?? batch['productName'] ?? '';
        final batchNumber = batch['batch_number'] ?? batch['batchNumber'] ?? '';

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
            expiryDays: expiryDays,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService.fetchInventoryNotifications expiring error: $e');
    }

    try {
      final lowStock =
          await _productService.getLowStockProducts(forceFallback: true);
      for (final product in lowStock) {
        final productId = product['id']?.toString() ?? '';
        final name = product['name']?.toString() ?? 'Sản phẩm';
        final currentStock =
            (product['current_stock'] as num?)?.toDouble() ?? 0;
        final minStock =
            (product['min_stock_level'] as num?)?.toDouble() ?? 0;

        notifications.add(
          NotificationMessage(
            id: 'lowstock-$productId',
            title: 'Sắp hết hàng',
            body:
                '$name còn ${_formatNumber(currentStock)} (mức tối thiểu $minStock)',
            createdAt: DateTime.now(),
            severity: NotificationSeverity.warning,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService.fetchInventoryNotifications low stock error: $e');
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
}
