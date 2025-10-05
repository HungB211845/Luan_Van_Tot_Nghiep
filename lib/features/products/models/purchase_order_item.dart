import 'dart:convert';

class PurchaseOrderItem {
  final String id;
  final String purchaseOrderId;
  final String productId;
  final int quantity;
  final double unitCost;
  final double? sellingPrice; // ADDED
  final String? unit; // Thêm trường unit
  final double totalCost;
  final int receivedQuantity;
  final String? notes;
  final String storeId; // Add storeId
  final DateTime createdAt;
  final String? productName; // Optional: enriched from join with products

  PurchaseOrderItem({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    this.sellingPrice, // ADDED
    this.unit,
    required this.totalCost,
    this.receivedQuantity = 0,
    this.notes,
    required this.storeId, // Add storeId
    required this.createdAt,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_order_id': purchaseOrderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'selling_price': sellingPrice, // ADDED
      'unit': unit, // Thêm vào map
      'received_quantity': receivedQuantity,
      'notes': notes,
      'store_id': storeId, // Add storeId
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    // Support both flattened 'product_name' and nested 'products': { name: ... }
    String? resolvedProductName;
    if (map.containsKey('product_name')) {
      resolvedProductName = map['product_name'] as String?;
    } else if (map.containsKey('products') && map['products'] is Map) {
      final prod = map['products'] as Map;
      final nameVal = prod['name'];
      if (nameVal is String) resolvedProductName = nameVal;
    }
    return PurchaseOrderItem(
      id: map['id'] ?? '',
      purchaseOrderId: map['purchase_order_id'] ?? '',
      productId: map['product_id'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble(), // ADDED
      unit: map['unit'], // Thêm từ map
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      receivedQuantity: map['received_quantity']?.toInt() ?? 0,
      notes: map['notes'],
      storeId: map['store_id'] ?? '', // Add storeId
      createdAt: DateTime.parse(map['created_at']),
      productName: resolvedProductName,
    );
  }

  String toJson() => json.encode(toMap());

  factory PurchaseOrderItem.fromJson(String source) =>
      PurchaseOrderItem.fromMap(json.decode(source));
}
