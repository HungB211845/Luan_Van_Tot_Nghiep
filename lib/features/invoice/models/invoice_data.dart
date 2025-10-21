import '../../auth/models/store_business_info.dart';
import '../../pos/models/transaction.dart';
import '../../customers/models/customer.dart';
import '../../products/models/purchase_order.dart';
import '../../products/models/company.dart';

/// Combined data model for invoice generation
/// Chứa tất cả thông tin cần thiết để generate hóa đơn (PDF/Excel)
class InvoiceData {
  final StoreBusinessInfo? storeInfo;
  final Transaction? transaction;
  final PurchaseOrder? purchaseOrder;
  final Customer? customer;
  final Company? supplier;
  final List<InvoiceItemData> items;
  final Map<String, dynamic>? additionalData;

  const InvoiceData({
    this.storeInfo,
    this.transaction,
    this.purchaseOrder,
    this.customer,
    this.supplier,
    required this.items,
    this.additionalData,
  });

  /// Factory constructor for Transaction Invoice (from RPC get_invoice_data)
  factory InvoiceData.fromTransactionRpc(Map<String, dynamic> json) {
    // Parse store info
    final storeInfoJson = json['store_info'] as Map<String, dynamic>?;
    final storeInfo = storeInfoJson != null
        ? StoreBusinessInfo.fromJson(storeInfoJson)
        : null;

    // Parse transaction
    final transactionJson = json['transaction'] as Map<String, dynamic>?;
    final transaction = transactionJson != null
        ? Transaction.fromJson(transactionJson)
        : null;

    // Parse customer
    final customerJson = json['customer'] as Map<String, dynamic>?;
    final customer = customerJson != null
        ? Customer.fromJson(customerJson)
        : null;

    // Parse items
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((item) {
      return InvoiceItemData.fromTransactionItem(item as Map<String, dynamic>);
    }).toList();

    return InvoiceData(
      storeInfo: storeInfo,
      transaction: transaction,
      customer: customer,
      items: items,
    );
  }

  /// Factory constructor for Purchase Order Invoice (from RPC get_po_invoice_data)
  factory InvoiceData.fromPurchaseOrderRpc(Map<String, dynamic> json) {
    // Parse store info
    final storeInfoJson = json['store_info'] as Map<String, dynamic>?;
    final storeInfo = storeInfoJson != null
        ? StoreBusinessInfo.fromJson(storeInfoJson)
        : null;

    // Parse purchase order
    final poJson = json['purchase_order'] as Map<String, dynamic>?;
    final purchaseOrder = poJson != null
        ? PurchaseOrder.fromMap(poJson)
        : null;

    // Parse supplier
    final supplierJson = json['supplier'] as Map<String, dynamic>?;
    final supplier = supplierJson != null
        ? Company.fromJson(supplierJson)
        : null;

    // Parse items
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((item) {
      return InvoiceItemData.fromPurchaseOrderItem(item as Map<String, dynamic>);
    }).toList();

    return InvoiceData(
      storeInfo: storeInfo,
      purchaseOrder: purchaseOrder,
      supplier: supplier,
      items: items,
    );
  }

  /// Check if this is a transaction invoice
  bool get isTransactionInvoice => transaction != null;

  /// Check if this is a purchase order invoice
  bool get isPurchaseOrderInvoice => purchaseOrder != null;

  /// Get total amount
  double get totalAmount {
    if (transaction != null) {
      return transaction!.totalAmount;
    }
    if (purchaseOrder != null) {
      return purchaseOrder!.totalAmount;
    }
    return items.fold(0.0, (sum, item) => sum + item.subTotal);
  }

  /// Get invoice number
  String? get invoiceNumber {
    if (transaction != null) {
      return transaction!.invoiceNumber;
    }
    if (purchaseOrder != null) {
      return purchaseOrder!.poNumber;
    }
    return null;
  }

  /// Get invoice date
  DateTime get invoiceDate {
    if (transaction != null) {
      return transaction!.transactionDate;
    }
    if (purchaseOrder != null) {
      return purchaseOrder!.orderDate;
    }
    return DateTime.now();
  }
}

/// Unified item data for invoice (works for both Transaction and PO)
class InvoiceItemData {
  final String id;
  final String productId;
  final String productName;
  final String? productSku;
  final int quantity;
  final String? unitName;
  final double? unitConversionFactor;
  final double? baseUnitQuantity;
  final double pricePerUnit;
  final double subTotal;
  final double discountAmount;

  const InvoiceItemData({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    this.unitName,
    this.unitConversionFactor,
    this.baseUnitQuantity,
    required this.pricePerUnit,
    required this.subTotal,
    this.discountAmount = 0.0,
  });

  /// From TransactionItem (RPC get_invoice_data)
  factory InvoiceItemData.fromTransactionItem(Map<String, dynamic> json) {
    return InvoiceItemData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      productSku: json['product_sku']?.toString(),
      quantity: json['quantity'] as int? ?? 0,
      unitName: json['unit_name']?.toString(),
      unitConversionFactor: (json['unit_conversion_factor'] as num?)?.toDouble(),
      baseUnitQuantity: (json['base_unit_quantity'] as num?)?.toDouble(),
      pricePerUnit: (json['price_at_sale'] as num?)?.toDouble() ?? 0.0,
      subTotal: (json['sub_total'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// From PurchaseOrderItem (RPC get_po_invoice_data)
  factory InvoiceItemData.fromPurchaseOrderItem(Map<String, dynamic> json) {
    return InvoiceItemData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      productSku: null, // PO items don't have SKU in the RPC
      quantity: json['quantity'] as int? ?? 0,
      unitName: json['unit']?.toString(),
      unitConversionFactor: null, // PO uses different unit structure
      baseUnitQuantity: null,
      pricePerUnit: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      subTotal: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      discountAmount: 0.0, // PO items don't have discount
    );
  }

  /// Display quantity with unit
  String get quantityDisplay {
    if (unitName != null && unitName!.isNotEmpty) {
      return '$quantity $unitName';
    }
    return quantity.toString();
  }

  /// Net amount after discount
  double get netAmount => subTotal - discountAmount;
}
