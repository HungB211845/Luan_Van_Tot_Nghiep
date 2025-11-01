class TaxSummary {
  final double totalRevenue;
  final double estimatedTax;
  final double totalExpenses;
  final int totalTransactions;
  final double taxRate;

  TaxSummary({
    required this.totalRevenue,
    required this.estimatedTax,
    required this.totalExpenses,
    required this.totalTransactions,
    this.taxRate = 1.5,
  });

  factory TaxSummary.fromJson(Map<String, dynamic> json) {
    return TaxSummary(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      estimatedTax: (json['estimated_tax'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 1.5,
    );
  }

  /// Tính lợi nhuận thực (doanh thu - chi phí - thuế)
  double get netProfit => totalRevenue - totalExpenses - estimatedTax;

  /// Tính biên lợi nhuận (%)
  double get profitMargin {
    if (totalRevenue == 0) return 0.0;
    return (netProfit / totalRevenue) * 100;
  }
}
