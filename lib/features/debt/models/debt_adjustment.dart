/// Debt adjustment model - represents manual adjustments to debt
class DebtAdjustment {
  final String id;
  final String storeId;
  final String debtId;
  final String customerId;

  final double adjustmentAmount;
  final String adjustmentType; // 'increase', 'decrease', 'write_off'
  final String reason;

  final double previousAmount;
  final double newAmount;

  final String? createdBy;
  final DateTime createdAt;

  DebtAdjustment({
    required this.id,
    required this.storeId,
    required this.debtId,
    required this.customerId,
    required this.adjustmentAmount,
    required this.adjustmentType,
    required this.reason,
    required this.previousAmount,
    required this.newAmount,
    this.createdBy,
    required this.createdAt,
  });

  factory DebtAdjustment.fromJson(Map<String, dynamic> json) {
    return DebtAdjustment(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      debtId: json['debt_id'] as String,
      customerId: json['customer_id'] as String,
      adjustmentAmount: (json['adjustment_amount'] as num).toDouble(),
      adjustmentType: json['adjustment_type'] as String,
      reason: json['reason'] as String,
      previousAmount: (json['previous_amount'] as num).toDouble(),
      newAmount: (json['new_amount'] as num).toDouble(),
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
      'adjustment_amount': adjustmentAmount,
      'adjustment_type': adjustmentType,
      'reason': reason,
      'previous_amount': previousAmount,
      'new_amount': newAmount,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get display name for adjustment type
  String get adjustmentTypeDisplayName {
    switch (adjustmentType) {
      case 'increase':
        return 'Tăng nợ';
      case 'decrease':
        return 'Giảm nợ';
      case 'write_off':
        return 'Xóa nợ';
      default:
        return adjustmentType;
    }
  }
}
