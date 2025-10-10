class RevenueTrendPoint {
  final DateTime reportDate;
  final double currentPeriodRevenue;
  final double previousPeriodRevenue;

  RevenueTrendPoint({
    required this.reportDate,
    required this.currentPeriodRevenue,
    required this.previousPeriodRevenue,
  });

  factory RevenueTrendPoint.fromJson(Map<String, dynamic> json) {
    return RevenueTrendPoint(
      reportDate: DateTime.parse(json['report_date'] as String),
      currentPeriodRevenue: (json['current_period_revenue'] as num?)?.toDouble() ?? 0.0,
      previousPeriodRevenue: (json['previous_period_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
