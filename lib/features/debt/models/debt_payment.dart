/// Debt payment model - represents a payment towards a debt
class DebtPayment {
  final String id;
  final String storeId;
  final String debtId;
  final String customerId;

  final double amount;
  final String paymentMethod;
  final String? notes;

  final DateTime paymentDate;
  final String? createdBy;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.storeId,
    required this.debtId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    required this.paymentDate,
    this.createdBy,
    required this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      debtId: json['debt_id'] as String,
      customerId: json['customer_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      notes: json['notes'] as String?,
      paymentDate: DateTime.parse(json['payment_date'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'debt_id': debtId,
      'customer_id': customerId,
      'amount': amount,
      'payment_method': paymentMethod,
      'notes': notes,
      'payment_date': paymentDate.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
