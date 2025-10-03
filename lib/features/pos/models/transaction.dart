import 'payment_method.dart';

class Transaction {
  final String id;
  final String storeId;
  final String? customerId;
  final double totalAmount;
  final double surchargeAmount; // Phụ phí được thêm vào giao dịch
  final DateTime transactionDate;
  final bool isDebt;
  final PaymentMethod paymentMethod;
  final String? notes;
  final String? invoiceNumber;
  final String? createdBy;
  final DateTime createdAt;

  // Enriched data, not part of the 'transactions' table schema
  final String? customerName;

  Transaction({
    required this.id,
    required this.storeId,
    this.customerId,
    required this.totalAmount,
    this.surchargeAmount = 0.0, // Default to 0 if not specified
    required this.transactionDate,
    this.isDebt = false,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
    this.invoiceNumber,
    this.createdBy,
    required this.createdAt,
    this.customerName, // Enriched data
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final customerData = json['customers'];
    return Transaction(
      id: json['id'],
      storeId: json['store_id'],
      customerId: json['customer_id'],
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      surchargeAmount: (json['surcharge_amount'] as num? ?? 0).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date']),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] ?? 'CASH'),
      notes: json['notes'],
      invoiceNumber: json['invoice_number'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      // Handle nested customer data if available
      customerName: customerData is Map ? customerData['name'] : null,
    );
  }
  
  /// Factory constructor for data coming from the 'search_transactions' RPC
  factory Transaction.fromRpcJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      storeId: json['store_id'], // Fixed: use correct field name from RPC output
      customerId: json['customer_id'],
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      surchargeAmount: (json['surcharge_amount'] as num? ?? 0).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date']),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] ?? 'CASH'),
      notes: json['notes'],
      invoiceNumber: json['invoice_number'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      // Enriched fields from the RPC
      customerName: json['customer_name'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'customer_id': customerId,
      'total_amount': totalAmount,
      'surcharge_amount': surchargeAmount,
      'transaction_date': transactionDate.toIso8601String(),
      'is_debt': isDebt,
      'payment_method': paymentMethod.value,
      'notes': notes,
      'invoice_number': invoiceNumber,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? storeId,
    String? customerId,
    double? totalAmount,
    double? surchargeAmount,
    DateTime? transactionDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
    String? notes,
    String? invoiceNumber,
    String? createdBy,
    DateTime? createdAt,
    String? customerName,
  }) {
    return Transaction(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      surchargeAmount: surchargeAmount ?? this.surchargeAmount,
      transactionDate: transactionDate ?? this.transactionDate,
      isDebt: isDebt ?? this.isDebt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
    );
  }
}