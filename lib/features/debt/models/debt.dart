import 'debt_status.dart';

/// Debt model - represents a customer debt record
class Debt {
  final String id;
  final String storeId;
  final String customerId;
  final String? transactionId;

  final double originalAmount;
  final double paidAmount;
  final double remainingAmount;

  final DebtStatus status;
  final DateTime? dueDate;
  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  Debt({
    required this.id,
    required this.storeId,
    required this.customerId,
    this.transactionId,
    required this.originalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.dueDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      customerId: json['customer_id'] as String,
      transactionId: json['transaction_id'] as String?,
      originalAmount: (json['original_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      status: DebtStatus.fromString(json['status'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'customer_id': customerId,
      'transaction_id': transactionId,
      'original_amount': originalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'status': status.value,
      'due_date': dueDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Check if debt is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == DebtStatus.paid || status == DebtStatus.cancelled) {
      return false;
    }
    // Overdue if due date is before today (not including today)
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dueDate!.isBefore(today) && remainingAmount > 0;
  }

  /// Check if debt is due soon (within 7 days) and not already overdue
  bool get isDueSoon {
    if (dueDate == null || isOverdue) return false;
    if (status == DebtStatus.paid || status == DebtStatus.cancelled) {
      return false;
    }
    final sevenDaysFromNow = DateTime.now().add(const Duration(days: 7));
    return dueDate!.isBefore(sevenDaysFromNow) && remainingAmount > 0;
  }

  /// Calculate payment progress percentage
  double get paymentProgress {
    if (originalAmount == 0) return 0;
    return (paidAmount / originalAmount) * 100;
  }

  Debt copyWith({
    String? id,
    String? storeId,
    String? customerId,
    String? transactionId,
    double? originalAmount,
    double? paidAmount,
    double? remainingAmount,
    DebtStatus? status,
    DateTime? dueDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      customerId: customerId ?? this.customerId,
      transactionId: transactionId ?? this.transactionId,
      originalAmount: originalAmount ?? this.originalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
