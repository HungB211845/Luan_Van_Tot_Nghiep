enum PaymentMethod { CASH, BANK_TRANSFER, DEBT }

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.CASH:
        return 'Tiền Mặt';
      case PaymentMethod.BANK_TRANSFER:
        return 'Chuyển Khoản';
      case PaymentMethod.DEBT:
        return 'Ghi Nợ';
    }
  }
}

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
  final DateTime createdAt;

  Transaction({
    required this.id,
    this.customerId,
    required this.totalAmount,
    required this.transactionDate,
    this.isDebt = false,
    this.paymentMethod = PaymentMethod.CASH,
    this.notes,
    this.invoiceNumber,
    this.createdBy,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      customerId: json['customer_id'],
      totalAmount: (json['total_amount']).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date']),
      isDebt: json['is_debt'] ?? false,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString().split('.').last == json['payment_method'],
        orElse: () => PaymentMethod.CASH,
      ),
      notes: json['notes'],
      invoiceNumber: json['invoice_number'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'total_amount': totalAmount,
      'transaction_date': transactionDate.toIso8601String(),
      'is_debt': isDebt,
      'payment_method': paymentMethod.toString().split('.').last,
      'notes': notes,
      'invoice_number': invoiceNumber,
      'created_by': createdBy,
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
      createdAt: createdAt,
    );
  }
}