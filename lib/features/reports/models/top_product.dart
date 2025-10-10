
class TopProduct {
  final String productId;
  final String productName;
  final String unit;
  final double totalQuantity;
  final double totalRevenue;
  final int transactionCount;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.transactionCount,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      unit: json['unit'] as String? ?? '',
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}
