import 'payment_method.dart';

class Transaction {
  final String id;
  final String? customerId;
  final double totalAmount;
  final DateTime transactionDate;
  final bool isDebt;
  final PaymentMethod paymentMethod;
  final String? notes;
  final String? invoiceNumber;
  final String? createdBy;
  final String storeId; // Add storeId
  final DateTime createdAt;

  Transaction({
    required this.id,
    this.customerId,
    required this.totalAmount,
    required this.transactionDate,
    this.isDebt = false,
    this.paymentMethod = PaymentMethod.cash,
    this.notes,
    this.invoiceNumber,
    this.createdBy,
    required this.storeId, // Add storeId
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      customerId: json['customer_id'],
      totalAmount: (json['total_amount']).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date']),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] ?? 'CASH'),
      notes: json['notes'],
      invoiceNumber: json['invoice_number'],
      createdBy: json['created_by'],
      storeId: json['store_id'], // Add storeId
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'total_amount': totalAmount,
      'transaction_date': transactionDate.toIso8601String(),
      'is_debt': isDebt,
      'payment_method': paymentMethod.value,
      'notes': notes,
      'invoice_number': invoiceNumber,
      'created_by': createdBy,
      'store_id': storeId, // Add storeId
    };
  }

  Transaction copyWith({
    String? customerId,
    double? totalAmount,
    DateTime? transactionDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
    String? notes,
    String? invoiceNumber,
    String? createdBy,
    String? storeId, // Add storeId
  }) {
    return Transaction(
      id: id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      transactionDate: transactionDate ?? this.transactionDate,
      isDebt: isDebt ?? this.isDebt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdBy: createdBy ?? this.createdBy,
      storeId: storeId ?? this.storeId, // Add storeId
      createdAt: createdAt,
    );
  }
}