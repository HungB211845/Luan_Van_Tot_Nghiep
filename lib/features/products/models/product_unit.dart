// lib/features/products/models/product_unit.dart

class ProductUnit {
  final String id;
  final String productId;
  final String unitName;
  final double conversionFactor;
  final double unitPrice;
  final bool isDefaultSellingUnit;
  final bool isActive;
  final String storeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.conversionFactor,
    required this.unitPrice,
    this.isDefaultSellingUnit = false,
    this.isActive = true,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      unitName: json['unit_name'] as String,
      conversionFactor: (json['conversion_factor'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      isDefaultSellingUnit: json['is_default_selling_unit'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      storeId: json['store_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'unit_name': unitName,
      'conversion_factor': conversionFactor,
      'unit_price': unitPrice,
      'is_default_selling_unit': isDefaultSellingUnit,
      'is_active': isActive,
      'store_id': storeId,
      // Note: id, created_at, updated_at are handled by database
    };
  }

  ProductUnit copyWith({
    String? id,
    String? productId,
    String? unitName,
    double? conversionFactor,
    double? unitPrice,
    bool? isDefaultSellingUnit,
    bool? isActive,
    String? storeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductUnit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      unitPrice: unitPrice ?? this.unitPrice,
      isDefaultSellingUnit: isDefaultSellingUnit ?? this.isDefaultSellingUnit,
      isActive: isActive ?? this.isActive,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ProductUnit(id: $id, unitName: $unitName, conversionFactor: $conversionFactor, unitPrice: $unitPrice, isDefault: $isDefaultSellingUnit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductUnit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
