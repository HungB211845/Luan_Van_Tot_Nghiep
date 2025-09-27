class TransactionItem {
  final String id;
  final String transactionId;
  final String productId;
  final String? batchId;
  final int quantity;
  final double priceAtSale;
  final double subTotal;
  final double discountAmount;
  final String storeId; // Add storeId
  final DateTime createdAt;

  TransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    this.batchId,
    required this.quantity,
    required this.priceAtSale,
    required this.subTotal,
    this.discountAmount = 0,
    required this.storeId, // Add storeId
    required this.createdAt,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'],
      transactionId: json['transaction_id'],
      productId: json['product_id'],
      batchId: json['batch_id'],
      quantity: json['quantity'],
      priceAtSale: (json['price_at_sale']).toDouble(),
      subTotal: (json['sub_total']).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      storeId: json['store_id'], // Add storeId
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'product_id': productId,
      'batch_id': batchId,
      'quantity': quantity,
      'price_at_sale': priceAtSale,
      'sub_total': subTotal,
      'discount_amount': discountAmount,
      'store_id': storeId, // Add storeId
    };
  }

  // Computed properties
  double get discountPercentage {
    if (subTotal == 0) return 0;
    return (discountAmount / subTotal) * 100;
  }

  double get finalPrice {
    return subTotal - discountAmount;
  }

  TransactionItem copyWith({
    String? transactionId,
    String? productId,
    String? batchId,
    int? quantity,
    double? priceAtSale,
    double? subTotal,
    double? discountAmount,
    String? storeId, // Add storeId
  }) {
    return TransactionItem(
      id: id,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      batchId: batchId ?? this.batchId,
      quantity: quantity ?? this.quantity,
      priceAtSale: priceAtSale ?? this.priceAtSale,
      subTotal: subTotal ?? this.subTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      storeId: storeId ?? this.storeId, // Add storeId
      createdAt: createdAt,
    );
  }
}