// lib/models/transaction_item_details.dart

// Model này dùng để gộp thông tin từ TransactionItem và Product lại làm một
// chỉ để phục vụ cho việc hiển thị trên giao diện.
class TransactionItemDetails {
  final String productId;
  final String productName;
  final String? productSku;
  final int quantity;
  final double priceAtSale;
  final double subTotal;
  final String? unitId;
  final String? unitName;
  final double? unitConversionFactor;
  final double? baseUnitQuantity;
  final String unitLabel;
  final double pricePerDisplayUnit;
  final String priceUnitName;

  TransactionItemDetails({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    required this.priceAtSale,
    required this.subTotal,
    this.unitId,
    this.unitName,
    this.unitConversionFactor,
    this.baseUnitQuantity,
    required this.unitLabel,
    required this.pricePerDisplayUnit,
    required this.priceUnitName,
  });
}
