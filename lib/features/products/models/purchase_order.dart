import 'dart:convert';

enum PurchaseOrderStatus {
  DRAFT,
  SENT,
  CONFIRMED,
  DELIVERED,
  CANCELLED,
}

class PurchaseOrder {
  final String id;
  final String supplierId;
  final String? supplierName; // Thêm trường này từ view
  final String? poNumber;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final DateTime? deliveryDate;
  final PurchaseOrderStatus status;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final double discountAmount;
  final String? paymentTerms;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    this.supplierName,
    this.poNumber,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.deliveryDate,
    this.status = PurchaseOrderStatus.DRAFT,
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.discountAmount = 0.0,
    this.paymentTerms,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] ?? '',
      supplierId: map['supplier_id'] ?? '',
      supplierName: map['supplier_name'], // Đọc từ map
      poNumber: map['po_number'],
      orderDate: DateTime.parse(map['order_date']),
      expectedDeliveryDate: map['expected_delivery_date'] != null
          ? DateTime.parse(map['expected_delivery_date'])
          : null,
      deliveryDate: map['delivery_date'] != null
          ? DateTime.parse(map['delivery_date'])
          : null,
      status: PurchaseOrderStatus.values
          .firstWhere((e) => e.name == map['status'], orElse: () => PurchaseOrderStatus.DRAFT),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      paymentTerms: map['payment_terms'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'po_number': poNumber,
      'order_date': orderDate.toIso8601String(),
      'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'status': status.name,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'payment_terms': paymentTerms,
      'notes': notes,
      'created_by': createdBy,
    };
  }
}
