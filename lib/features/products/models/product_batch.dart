class ProductBatch {
  final String id;
  final String productId;
  final String? purchaseOrderId; // Link to PO
  final String? supplierId;      // Link to Supplier
  final String batchNumber;
  final int quantity;
  final double costPrice;
  final double? sellingPrice;
  final DateTime receivedDate;
  final DateTime? expiryDate;
  final String? supplierBatchId;
  final String? notes;
  final bool isAvailable;
  final String storeId; // Add storeId
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? productName; // Optional: enriched via join products(name)
  final String? supplierName; // Optional: enriched via join companies(name)

  ProductBatch({
    required this.id,
    required this.productId,
    this.purchaseOrderId,
    this.supplierId,
    required this.batchNumber,
    required this.quantity,
    required this.costPrice,
    this.sellingPrice,
    required this.receivedDate,
    this.expiryDate,
    this.supplierBatchId,
    this.notes,
    this.isAvailable = true,
    required this.storeId, // Add storeId
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.supplierName,
  });

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    String? resolvedProductName;
    if (json.containsKey('product_name')) {
      resolvedProductName = json['product_name'] as String?;
    } else if (json.containsKey('products') && json['products'] is Map) {
      final prod = json['products'] as Map;
      final nameVal = prod['name'];
      if (nameVal is String) resolvedProductName = nameVal;
    }
    String? resolvedSupplierName;
    if (json.containsKey('supplier_name')) {
      resolvedSupplierName = json['supplier_name'] as String?;
    } else if (json.containsKey('companies') && json['companies'] is Map) {
      final comp = json['companies'] as Map;
      final nameVal = comp['name'];
      if (nameVal is String) resolvedSupplierName = nameVal;
    }
    return ProductBatch(
      id: json['id'],
      productId: json['product_id'],
      purchaseOrderId: json['purchase_order_id'],
      supplierId: json['supplier_id'],
      batchNumber: json['batch_number'],
      quantity: json['quantity'],
      costPrice: (json['cost_price']).toDouble(),
      sellingPrice: (json['selling_price'] as num?)?.toDouble(),
      receivedDate: DateTime.parse(json['received_date']),
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'])
          : null,
      supplierBatchId: json['supplier_batch_id'],
      notes: json['notes'],
      isAvailable: json['is_available'] ?? true,
      storeId: json['store_id'], // Add storeId
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      productName: resolvedProductName,
      supplierName: resolvedSupplierName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'purchase_order_id': purchaseOrderId,
      'supplier_id': supplierId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'cost_price': costPrice,
      // Note: selling_price is not stored in product_batches table
      // It should be stored in seasonal_prices table instead
      'received_date': receivedDate.toIso8601String().split('T')[0],
      if (expiryDate != null)
        'expiry_date': expiryDate!.toIso8601String().split('T')[0],
      'supplier_batch_id': supplierBatchId,
      'notes': notes,
      'is_available': isAvailable,
      'store_id': storeId, // Add storeId
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
    double? sellingPrice,
    DateTime? receivedDate,
    DateTime? expiryDate,
    String? supplierBatchId,
    String? notes,
    bool? isAvailable,
    String? purchaseOrderId,
    String? supplierId,
    String? productName,
    String? supplierName,
    String? storeId, // Add storeId
  }) {
    return ProductBatch(
      id: id,
      productId: productId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      supplierId: supplierId ?? this.supplierId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      receivedDate: receivedDate ?? this.receivedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplierBatchId: supplierBatchId ?? this.supplierBatchId,
      notes: notes ?? this.notes,
      isAvailable: isAvailable ?? this.isAvailable,
      storeId: storeId ?? this.storeId, // Add storeId
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      productName: productName ?? this.productName,
      supplierName: supplierName ?? this.supplierName,
    );
  }
}