import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';
import '../models/inventory_product.dart';
import '../models/daily_revenue.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  /// Fetches a summary of revenue for a given date range AND the preceding period.
  Future<Map<String, dynamic>> getRevenueSummaryWithComparison(DateTime startDate, DateTime endDate) async {
    try {
      final response = await _supabase.rpc('get_revenue_summary_with_comparison', params: {
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      });
      return (response as List).first as Map<String, dynamic>;
    } catch (e) {
      print('Error in getRevenueSummaryWithComparison: $e');
      rethrow;
    }
  }

  /// Fetches time-series data for revenue charts using an RPC.
  Future<List<RevenueTrendPoint>> getRevenueTrend(DateTime startDate, DateTime endDate, {String interval = 'day'}) async {
    try {
      final response = await _supabase.rpc('get_revenue_trend', params: {
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
        'p_interval': interval,
      });
      final data = response as List;
      return data.map((item) => RevenueTrendPoint.fromJson(item)).toList();
    } catch (e) {
      print('Error in getRevenueTrend: $e');
      rethrow;
    }
  }

  /// Fetches revenue data for a week (7 days) starting from given date
  Future<List<DailyRevenue>> getRevenueForWeek(DateTime startDate) async {
    try {
      final endDate = startDate.add(const Duration(days: 6));

      final trendData = await getRevenueTrend(
        startDate,
        endDate,
        interval: 'day'
      );

      // Convert RevenueTrendPoint to DailyRevenue
      // Note: transaction_count is not available, so we set it to 0
      return trendData.map((point) => DailyRevenue(
        date: point.reportDate,
        revenue: point.currentPeriodRevenue,
        transactionCount: 0, // Not available from revenue_trend RPC
      )).toList();
    } catch (e) {
      print('Error in getRevenueForWeek: $e');
      rethrow;
    }
  }

  /// Fetches top-performing products by revenue or profit using an RPC.
  Future<List<TopProduct>> getTopPerformingProducts({
    required DateTime startDate,
    required DateTime endDate,
    String orderBy = 'revenue',
    int limit = 5,
  }) async {
    try {
      final response = await _supabase.rpc('get_top_performing_products', params: {
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
        'p_order_by': orderBy,
        'p_limit': limit,
      });
      final data = response as List;
      return data.map((item) => TopProduct.fromJson(item)).toList();
    } catch (e) {
      print('Error in getTopPerformingProducts: $e');
      rethrow;
    }
  }

  /// Fetches key inventory metrics and alerts using RPCs.
  Future<InventoryAnalytics> getInventoryAnalytics() async {
    try {
      // Call both summary and alerts RPCs concurrently.
      final responses = await Future.wait([
        _supabase.rpc('get_inventory_summary'),
        _supabase.rpc('get_inventory_alerts'),
      ]);

      final summaryData = (responses[0] as List).first as Map<String, dynamic>;
      final alertsData = responses[1] as Map<String, dynamic>;

      // Debug logging to see actual API response
      // Only log when there are actual alerts or errors
      // print('🔍 DEBUG: Inventory Alerts Raw Response');
      print('  Low Stock Products: ${alertsData['low_stock_products']}');
      print('  Expiring Soon Products: ${alertsData['expiring_soon_products']}');
      print('  Slow Moving Products: ${alertsData['slow_moving_products']}');
      print('  Low Stock Count: ${(alertsData['low_stock_products'] as List).length}');
      print('  Expiring Soon Count: ${(alertsData['expiring_soon_products'] as List).length}');
      print('  Slow Moving Count: ${(alertsData['slow_moving_products'] as List?)?.length ?? 0}');

      // Combine results into a single model.
      return InventoryAnalytics.fromJson({
        'total_inventory_value': summaryData['total_inventory_value'],
        'total_selling_value': summaryData['total_selling_value'],
        'potential_profit': summaryData['potential_profit'],
        'profit_margin': summaryData['profit_margin'],
        'total_items': summaryData['total_items'],
        'total_batches': summaryData['total_batches'],
        'low_stock_items': (alertsData['low_stock_products'] as List).length,
        'expiring_soon_items': (alertsData['expiring_soon_products'] as List).length,
        'slow_moving_items': (alertsData['slow_moving_products'] as List?)?.length ?? 0,
      });
    } catch (e) {
      print('Error in getInventoryAnalytics: $e');
      rethrow;
    }
  }

  /// Fetches inventory analytics lists (top/bottom products by value and turnover)
  Future<Map<String, List<InventoryProduct>>> getInventoryAnalyticsLists() async {
    try {
      final response = await _supabase.rpc('get_inventory_analytics_lists');
      final data = response as Map<String, dynamic>;

      return {
        'top_value': (data['top_value_products'] as List)
            .map((item) => InventoryProduct.fromJson(item))
            .toList(),
        'fast_turnover': (data['fast_turnover_products'] as List)
            .map((item) => InventoryProduct.fromJson(item))
            .toList(),
        'slow_turnover': (data['slow_turnover_products'] as List)
            .map((item) => InventoryProduct.fromJson(item))
            .toList(),
      };
    } catch (e) {
      print('Error in getInventoryAnalyticsLists: $e');
      rethrow;
    }
  }

  /// Fetches detailed low stock products for alert screen
  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 10}) async {
    try {
      final response = await _supabase.rpc('get_inventory_alerts', params: {
        'p_low_stock_threshold': threshold,
      });
      final data = response as Map<String, dynamic>;
      return (data['low_stock_products'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error in getLowStockProducts: $e');
      rethrow;
    }
  }

  /// Fetches detailed slow moving products for alert screen
  Future<List<Map<String, dynamic>>> getSlowMovingProducts({int days = 90}) async {
    try {
      final response = await _supabase.rpc('get_inventory_alerts', params: {
        'p_slow_moving_days': days,
      });
      final data = response as Map<String, dynamic>;
      return (data['slow_moving_products'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error in getSlowMovingProducts: $e');
      rethrow;
    }
  }
}