
class MonthlyReport {
  final int month;
  final int year;
  final double totalRevenue;
  final double cashRevenue;
  final double debtRevenue;
  final int totalTransactions;
  final double taxAmount;
  final double netRevenue;

  MonthlyReport({
    required this.month,
    required this.year,
    required this.totalRevenue,
    required this.cashRevenue,
    required this.debtRevenue,
    required this.totalTransactions,
    required this.taxAmount,
    required this.netRevenue,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      month: json['month'] as int,
      year: json['year'] as int,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      cashRevenue: (json['cash_revenue'] as num?)?.toDouble() ?? 0.0,
      debtRevenue: (json['debt_revenue'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      netRevenue: (json['net_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
