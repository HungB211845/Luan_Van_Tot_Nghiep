// lib/features/products/models/purchase_order_status.dart

enum PurchaseOrderStatus {
  draft('DRAFT'),
  sent('SENT'),
  confirmed('CONFIRMED'),
  delivered('DELIVERED'),
  cancelled('CANCELLED');

  const PurchaseOrderStatus(this.value);
  final String value;

  factory PurchaseOrderStatus.fromString(String value) {
    return PurchaseOrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }

  String get displayName {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return 'Nháp';
      case PurchaseOrderStatus.sent:
        return 'Đã gửi';
      case PurchaseOrderStatus.confirmed:
        return 'Đã xác nhận';
      case PurchaseOrderStatus.delivered:
        return 'Đã giao hàng';
      case PurchaseOrderStatus.cancelled:
        return 'Đã hủy';
    }
  }

  // For database enum compatibility
  String get name => value;
}