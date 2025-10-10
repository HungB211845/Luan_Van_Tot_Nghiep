import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';

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
      });
    } catch (e) {
      print('Error in getInventoryAnalytics: $e');
      rethrow;
    }
  }
}