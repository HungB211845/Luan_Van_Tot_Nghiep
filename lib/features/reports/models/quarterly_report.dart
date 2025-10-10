
class QuarterlyReport {
  final int quarter;
  final int year;
  final double totalRevenue;
  final double cashRevenue;
  final double debtRevenue;
  final int totalTransactions;
  final double taxAmount;
  final double netRevenue;

  QuarterlyReport({
    required this.quarter,
    required this.year,
    required this.totalRevenue,
    required this.cashRevenue,
    required this.debtRevenue,
    required this.totalTransactions,
    required this.taxAmount,
    required this.netRevenue,
  });

  factory QuarterlyReport.fromJson(Map<String, dynamic> json) {
    return QuarterlyReport(
      quarter: json['quarter'] as int,
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
