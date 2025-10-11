import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/revenue_trend_point.dart';
import '../models/inventory_analytics.dart';
import '../models/top_product.dart';
import '../models/inventory_product.dart';
import '../models/daily_revenue.dart';
import '../models/tax_summary.dart';

// Platform-specific imports with proper conditional compilation
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:share_plus/share_plus.dart' if (dart.library.html) 'package:agricultural_pos/stub.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'package:agricultural_pos/stub.dart';
import 'package:file_saver/file_saver.dart' if (dart.library.html) 'package:agricultural_pos/stub.dart';

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

  /// NEW: Calculate tax summary using direct queries (bypasses JWT issues in RPC)
  /// This method uses the same logic as get_tax_summary RPC but with direct queries
  /// OPTIMIZED with caching and better query performance
  Future<TaxSummary> getTaxSummaryDirect(DateTime startDate, DateTime endDate) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      final storeId = user.userMetadata?['store_id'] as String?;
      if (storeId == null) {
        throw Exception('No store_id found in user metadata');
      }

      // Create cache key based on date range and store
      final cacheKey = '${storeId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
      
      // Check if we have recent cached result (within 30 seconds)
      if (_taxCache.containsKey(cacheKey)) {
        final cached = _taxCache[cacheKey]!;
        final now = DateTime.now();
        if (now.difference(cached['timestamp']).inSeconds < 30) {
          return cached['data'] as TaxSummary;
        } else {
          _taxCache.remove(cacheKey); // Remove expired cache
        }
      }

      // OPTIMIZED: Use concurrent queries with better filtering
      final futures = await Future.wait([
        // Query 1: Transactions with optimized filtering
        _supabase
            .from('transactions')
            .select('total_amount')
            .eq('store_id', storeId)
            .gte('created_at', startDate.toIso8601String())
            .lte('created_at', endDate.toIso8601String())
            .order('created_at', ascending: false), // Use index on created_at

        // Query 2: Purchase orders with status filter first (more selective)
        _supabase
            .from('purchase_orders')
            .select('total_amount')
            .eq('status', 'DELIVERED') // Filter by status first (more selective)
            .eq('store_id', storeId)
            .gte('delivery_date', startDate.toIso8601String())
            .lte('delivery_date', endDate.toIso8601String())
            .order('delivery_date', ascending: false),
      ]);

      final transactionsResponse = futures[0] as List<dynamic>;
      final purchaseOrdersResponse = futures[1] as List<dynamic>;

      // Fast aggregation using reduce
      double totalRevenue = 0;
      if (transactionsResponse.isNotEmpty) {
        totalRevenue = transactionsResponse.fold<double>(
          0, 
          (sum, tx) => sum + (tx['total_amount'] as num).toDouble()
        );
      }

      double totalExpenses = 0;
      if (purchaseOrdersResponse.isNotEmpty) {
        totalExpenses = purchaseOrdersResponse.fold<double>(
          0,
          (sum, po) => sum + (po['total_amount'] as num).toDouble()
        );
      }

      final transactionCount = transactionsResponse.length;
      final estimatedTax = totalRevenue * 0.015;

      final result = TaxSummary(
        totalRevenue: totalRevenue,
        estimatedTax: estimatedTax,
        totalExpenses: totalExpenses,
        totalTransactions: transactionCount,
      );

      // Cache the result for 30 seconds
      _taxCache[cacheKey] = {
        'data': result,
        'timestamp': DateTime.now(),
      };

      return result;
    } catch (e) {
      print('❌ Error in getTaxSummaryDirect: $e');
      rethrow;
    }
  }

  // Simple cache for tax calculations (30 second TTL)
  static final Map<String, Map<String, dynamic>> _taxCache = {};

  /// Export Sales Ledger to CSV file and share
  /// Implements the complete UX flow: RPC call -> CSV generation -> Share dialog
  /// WITH WEB PLATFORM SUPPORT
  Future<void> exportSalesLedger(DateTime startDate, DateTime endDate) async {
    try {
      // 1. Call RPC to get structured data from Supabase
      final List<dynamic> jsonData = await _supabase.rpc(
        'export_sales_ledger',
        params: {
          'p_start_date': startDate.toIso8601String(),
          'p_end_date': endDate.toIso8601String(),
        },
      );

      if (jsonData.isEmpty) {
        throw Exception('Không có dữ liệu giao dịch trong kỳ đã chọn để xuất.');
      }

      // 2. Convert JSON data to CSV format
      final List<List<dynamic>> csvData = [];
      
      // Add header row from first record keys
      if (jsonData.isNotEmpty) {
        final firstRecord = jsonData.first as Map<String, dynamic>;
        csvData.add(firstRecord.keys.toList());
      }
      
      // Add data rows
      for (final record in jsonData) {
        final row = (record as Map<String, dynamic>).values.toList();
        csvData.add(row);
      }

      // 3. Convert to CSV string with UTF-8 encoding for Vietnamese support
      const converter = ListToCsvConverter();
      final String csvString = converter.convert(csvData);

      // 4. Generate filename
      final dateRange = '${DateFormat('dd-MM-yyyy').format(startDate)}_${DateFormat('dd-MM-yyyy').format(endDate)}';
      final fileName = 'BangKeBanHang_$dateRange.csv';

      // 5. Platform-specific sharing/download/save with proper detection
      if (kIsWeb) {
        // WEB: Show message for now
        _downloadFileOnWeb(csvString, fileName);
      } else {
        // Use defaultTargetPlatform for reliable platform detection
        switch (defaultTargetPlatform) {
          case TargetPlatform.iOS:
          case TargetPlatform.android:
            // MOBILE: Use share_plus for native sharing
            await _shareFileOnMobile(csvString, fileName, dateRange);
            break;
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
          case TargetPlatform.linux:
            // DESKTOP: Use file_saver for native Save As dialog
            await _saveFileOnDesktop(csvString, fileName);
            break;
          default:
            throw Exception('Nền tảng này chưa được hỗ trợ xuất file');
        }
      }

    } catch (e) {
      // Re-throw with user-friendly message for UI
      if (e.toString().contains('Không có dữ liệu')) {
        rethrow; // Keep our custom message
      } else {
        throw Exception('Xuất file thất bại: ${e.toString()}');
      }
    }
  }

  /// Web-specific file download using browser APIs
  void _downloadFileOnWeb(String csvContent, String fileName) {
    if (!kIsWeb) {
      throw UnsupportedError('Web download only available on web platform');
    }

    // For now, show clear message that web export is not supported
    throw Exception('Chức năng xuất file chưa hỗ trợ trên web. Vui lòng sử dụng ứng dụng trên điện thoại hoặc máy tính để xuất file CSV.');
  }

  /// Mobile-specific file sharing using share_plus
  Future<void> _shareFileOnMobile(String csvContent, String fileName, String dateRange) async {
    if (kIsWeb) {
      throw UnsupportedError('Use web download instead');
    }
    
    // Save to temporary file
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    
    // Write with UTF-8 BOM for Excel compatibility
    final utf8Bom = [0xEF, 0xBB, 0xBF];
    final utf8Data = utf8.encode(csvContent);
    await file.writeAsBytes([...utf8Bom, ...utf8Data]);

    // Share file using native share dialog
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Bảng kê Bán hàng ($dateRange)',
      text: 'Bảng kê chi tiết các giao dịch bán hàng',
    );

    // Clean up temporary file after sharing
    if (result.status == ShareResultStatus.success) {
      try {
        await file.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  /// Desktop-specific file saving using file_saver
  /// Opens native "Save As" dialog on macOS/Windows/Linux
  Future<void> _saveFileOnDesktop(String csvContent, String fileName) async {
    if (kIsWeb) {
      throw UnsupportedError('Use web download instead');
    }
    
    try {
      // Prepare CSV data with UTF-8 BOM for Excel compatibility
      final utf8Bom = [0xEF, 0xBB, 0xBF];
      final utf8Data = utf8.encode(csvContent);
      final bytes = Uint8List.fromList([...utf8Bom, ...utf8Data]);

      // Use file_saver to open native "Save As" dialog
      final result = await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.csv', ''), // Remove extension as FileSaver adds it
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (result == null || result.isEmpty) {
        throw Exception('Người dùng đã hủy việc lưu file hoặc xảy ra lỗi');
      }

      // Success - file saved to user-chosen location
      // FileSaver handles the native dialog and file writing
      
    } catch (e) {
      // Re-throw with user-friendly message
      throw Exception('Không thể lưu file: ${e.toString()}');
    }
  }
}