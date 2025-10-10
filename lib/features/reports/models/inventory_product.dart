/// Model for inventory analytics product data
/// Used in top/bottom product rankings by value or turnover
class InventoryProduct {
  final String productId;
  final String productName;
  final String sku;
  final double metricValue; // Can be inventory_value or turnover_ratio
  final int? currentStock; // Optional, may not always be present
  final double? totalSold; // Optional, for turnover calculations

  InventoryProduct({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.metricValue,
    this.currentStock,
    this.totalSold,
  });

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    return InventoryProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      sku: json['sku'] as String? ?? '',
      metricValue: (json['inventory_value'] ?? json['turnover_ratio'] as num?)?.toDouble() ?? 0.0,
      currentStock: json['current_stock'] as int? ?? json['avg_stock']?.toInt(),
      totalSold: (json['total_sold'] as num?)?.toDouble(),
    );
  }
}
