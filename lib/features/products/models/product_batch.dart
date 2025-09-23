class ProductBatch {
  final String id;
  final String productId;
  final String batchNumber;
  final int quantity;
  final double costPrice;
  final DateTime receivedDate;
  final DateTime? expiryDate;
  final String? supplierBatchId;
  final String? notes;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNumber,
    required this.quantity,
    required this.costPrice,
    required this.receivedDate,
    this.expiryDate,
    this.supplierBatchId,
    this.notes,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    return ProductBatch(
      id: json['id'],
      productId: json['product_id'],
      batchNumber: json['batch_number'],
      quantity: json['quantity'],
      costPrice: (json['cost_price']).toDouble(),
      receivedDate: DateTime.parse(json['received_date']),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      supplierBatchId: json['supplier_batch_id'],
      notes: json['notes'],
      isAvailable: json['is_available'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'cost_price': costPrice,
      'received_date': receivedDate.toIso8601String().split('T')[0],
      if (expiryDate != null)
        'expiry_date': expiryDate!.toIso8601String().split('T')[0],
      'supplier_batch_id': supplierBatchId,
      'notes': notes,
      'is_available': isAvailable,
    };
  }

  // Computed properties
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final thirtyDaysFromNow = DateTime.now().add(Duration(days: 30));
    return expiryDate!.isBefore(thirtyDaysFromNow) && !isExpired;
  }

  int get daysUntilExpiry {
    if (expiryDate == null) return -1;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  ProductBatch copyWith({
    String? batchNumber,
    int? quantity,
    double? costPrice,
    DateTime? receivedDate,
    DateTime? expiryDate,
    String? supplierBatchId,
    String? notes,
    bool? isAvailable,
  }) {
    return ProductBatch(
      id: id,
      productId: productId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      receivedDate: receivedDate ?? this.receivedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplierBatchId: supplierBatchId ?? this.supplierBatchId,
      notes: notes ?? this.notes,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}