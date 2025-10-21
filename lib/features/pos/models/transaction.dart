import '../../../shared/services/base_service.dart';
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
      id: _parseString(json['id']) ?? '',
      storeId: _parseString(json['store_id']) ?? BaseService.getDefaultStoreId(),
      customerId: _parseString(json['customer_id']),
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      surchargeAmount: (json['surcharge_amount'] as num? ?? 0).toDouble(),
      transactionDate: _parseDateTime(json['transaction_date']) ??
          _parseDateTime(json['created_at']) ??
          DateTime.now(),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] ?? 'CASH'),
      notes: _parseString(json['notes']),
      invoiceNumber: _parseString(json['invoice_number']),
      createdBy: _parseString(json['created_by']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      // Handle nested customer data if available
      customerName:
          customerData is Map ? _parseString(customerData['name']) : null,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }
  
  /// Factory constructor for data coming from the 'search_transactions' RPC
  factory Transaction.fromRpcJson(Map<String, dynamic> json) {
    return Transaction(
      id: _parseString(json['id']) ?? '',
      storeId: _parseString(json['store_id']) ?? BaseService.getDefaultStoreId(),
      customerId: _parseString(json['customer_id']),
      totalAmount: (json['total_amount'] as num? ?? 0).toDouble(),
      surchargeAmount: (json['surcharge_amount'] as num? ?? 0).toDouble(),
      transactionDate: _parseDateTime(json['transaction_date']) ??
          _parseDateTime(json['created_at']) ??
          DateTime.now(),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.fromString(json['payment_method'] ?? 'CASH'),
      notes: _parseString(json['notes']),
      invoiceNumber: _parseString(json['invoice_number']),
      createdBy: _parseString(json['created_by']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      // Enriched fields from the RPC
      customerName: _parseString(json['customer_name']),
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
