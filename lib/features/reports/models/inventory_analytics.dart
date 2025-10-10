
class InventoryAnalytics {
  final double totalInventoryValue;
  final double totalSellingValue;
  final double potentialProfit;
  final double profitMargin;
  final int lowStockItems;
  final int expiringSoonItems;
  final int slowMovingItems; // Products with no sales in 90 days
  final int totalBatches;

  InventoryAnalytics({
    required this.totalInventoryValue,
    required this.totalSellingValue,
    required this.potentialProfit,
    required this.profitMargin,
    required this.lowStockItems,
    required this.expiringSoonItems,
    required this.slowMovingItems,
    required this.totalBatches,
  });

  factory InventoryAnalytics.fromJson(Map<String, dynamic> json) {
    return InventoryAnalytics(
      totalInventoryValue: (json['total_inventory_value'] as num?)?.toDouble() ?? 0.0,
      totalSellingValue: (json['total_selling_value'] as num?)?.toDouble() ?? 0.0,
      potentialProfit: (json['potential_profit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profit_margin'] as num?)?.toDouble() ?? 0.0,
      lowStockItems: json['low_stock_items'] as int? ?? 0,
      expiringSoonItems: json['expiring_soon_items'] as int? ?? 0,
      slowMovingItems: json['slow_moving_items'] as int? ?? 0,
      totalBatches: json['total_batches'] as int? ?? 0,
    );
  }
}
