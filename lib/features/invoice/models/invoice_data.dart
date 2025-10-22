import '../../auth/models/store_business_info.dart';
import '../../pos/models/transaction.dart';
import '../../customers/models/customer.dart';
import '../../products/models/purchase_order.dart';
import '../../products/models/company.dart';

/// Combined data model for invoice generation
/// Chứa tất cả thông tin cần thiết để generate hóa đơn (PDF/Excel)
/// Updated: 2025-10-22 - Added VAT fields per NĐ 123/2020, TT 32/2025
class InvoiceData {
  final StoreBusinessInfo? storeInfo;
  final Transaction? transaction;
  final PurchaseOrder? purchaseOrder;
  final Customer? customer;
  final Company? supplier;
  final List<InvoiceItemData> items;
  final double? vatTotal;  // Total VAT amount from RPC
  final Map<String, dynamic>? additionalData;

  const InvoiceData({
    this.storeInfo,
    this.transaction,
    this.purchaseOrder,
    this.customer,
    this.supplier,
    required this.items,
    this.vatTotal,
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

    // Parse items with VAT fields
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((item) {
      return InvoiceItemData.fromTransactionItem(item as Map<String, dynamic>);
    }).toList();

    // Get VAT total from RPC (fallback to calculated if not present)
    final vatTotal = (json['vat_total'] as num?)?.toDouble() ??
        items.fold<double>(0.0, (sum, item) => sum + (item.taxAmount ?? 0.0));

    return InvoiceData(
      storeInfo: storeInfo,
      transaction: transaction,
      customer: customer,
      items: items,
      vatTotal: vatTotal,
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

    // Parse items with VAT fields
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((item) {
      return InvoiceItemData.fromPurchaseOrderItem(item as Map<String, dynamic>);
    }).toList();

    // Get VAT total from RPC (fallback to calculated if not present)
    final vatTotal = (json['vat_total'] as num?)?.toDouble() ??
        items.fold<double>(0.0, (sum, item) => sum + (item.taxAmount ?? 0.0));

    return InvoiceData(
      storeInfo: storeInfo,
      purchaseOrder: purchaseOrder,
      supplier: supplier,
      items: items,
      vatTotal: vatTotal,
    );
  }

  /// Check if this is a transaction invoice
  bool get isTransactionInvoice => transaction != null;

  /// Check if this is a purchase order invoice
  bool get isPurchaseOrderInvoice => purchaseOrder != null;

  /// Get total amount (before VAT)
  double get totalAmount {
    if (transaction != null) {
      return transaction!.totalAmount;
    }
    if (purchaseOrder != null) {
      return purchaseOrder!.totalAmount;
    }
    return items.fold(0.0, (sum, item) => sum + item.subTotal);
  }

  /// Get total amount including VAT
  double get totalWithVat {
    return totalAmount + (vatTotal ?? 0.0);
  }

  /// Get invoice symbol from store info
  String? get invoiceSymbol => storeInfo?.invoiceSymbol;

  /// Get invoice template code from store info
  String? get invoiceTemplateCode => storeInfo?.invoiceTemplateCode;

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
/// Updated: 2025-10-22 - Added VAT fields
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

  // VAT fields (per NĐ 123/2020, TT 32/2025)
  final double taxRate;       // % VAT (0, 5, 8, 10, etc.)
  final double taxAmount;     // Tiền thuế = subTotal * (taxRate / 100)
  final double grossAmount;   // Tổng cộng = subTotal + taxAmount

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
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    this.grossAmount = 0.0,
  });

  /// From TransactionItem (RPC get_invoice_data - with VAT)
  factory InvoiceItemData.fromTransactionItem(Map<String, dynamic> json) {
    final subTotal = (json['sub_total'] as num?)?.toDouble() ?? 0.0;
    final taxRate = (json['tax_rate'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (json['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final grossAmount = (json['gross_amount'] as num?)?.toDouble() ?? subTotal;

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
      subTotal: subTotal,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      taxRate: taxRate,
      taxAmount: taxAmount,
      grossAmount: grossAmount,
    );
  }

  /// From PurchaseOrderItem (RPC get_po_invoice_data - with VAT)
  factory InvoiceItemData.fromPurchaseOrderItem(Map<String, dynamic> json) {
    final subTotal = (json['total_cost'] as num?)?.toDouble() ?? 0.0;
    final taxRate = (json['tax_rate'] as num?)?.toDouble() ?? 0.0;
    final taxAmount = (json['tax_amount'] as num?)?.toDouble() ?? 0.0;
    final grossAmount = (json['gross_amount'] as num?)?.toDouble() ?? subTotal;

    return InvoiceItemData(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      productSku: json['product_sku']?.toString(),
      quantity: json['quantity'] as int? ?? 0,
      unitName: json['unit']?.toString(),
      unitConversionFactor: null, // PO uses different unit structure
      baseUnitQuantity: null,
      pricePerUnit: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      subTotal: subTotal,
      discountAmount: 0.0, // PO items don't have discount
      taxRate: taxRate,
      taxAmount: taxAmount,
      grossAmount: grossAmount,
    );
  }

  /// Display quantity with unit
  String get quantityDisplay {
    if (unitName != null && unitName!.isNotEmpty) {
      return '$quantity $unitName';
    }
    return quantity.toString();
  }

  /// Net amount after discount (before VAT)
  double get netAmount => subTotal - discountAmount;

  /// Check if this item has VAT
  bool get hasTax => taxRate > 0;
}
