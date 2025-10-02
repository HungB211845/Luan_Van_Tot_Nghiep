import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_revenue.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  /// Get revenue data for 7 days starting from [startDate]
  /// Aggregates transaction totals by day
  Future<List<DailyRevenue>> getRevenueForWeek(DateTime startDate) async {
    try {
      final endDate = startDate.add(const Duration(days: 6));

      // Format dates for SQL query (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      // Query to aggregate revenue by day
      final response = await _supabase
          .from('transactions')
          .select('created_at, total_amount')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59')
          .order('created_at');

      final transactions = response as List;

      // Group by date and calculate daily totals
      final Map<String, Map<String, dynamic>> dailyMap = {};

      for (var txn in transactions) {
        final createdAt = DateTime.parse(txn['created_at'] as String);
        final dateKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

        if (!dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey] = {
            'date': dateKey,
            'revenue': 0.0,
            'transaction_count': 0,
          };
        }

        dailyMap[dateKey]!['revenue'] =
            (dailyMap[dateKey]!['revenue'] as double) + ((txn['total_amount'] as num?)?.toDouble() ?? 0.0);
        dailyMap[dateKey]!['transaction_count'] =
            (dailyMap[dateKey]!['transaction_count'] as int) + 1;
      }

      // Create list for all 7 days (fill missing days with 0)
      final List<DailyRevenue> result = [];
      for (int i = 0; i < 7; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

        if (dailyMap.containsKey(dateKey)) {
          result.add(DailyRevenue.fromJson(dailyMap[dateKey]!));
        } else {
          result.add(DailyRevenue(
            date: currentDate,
            revenue: 0.0,
            transactionCount: 0,
          ));
        }
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }
}
