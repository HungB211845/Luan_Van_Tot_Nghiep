import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tax_summary.dart';

class TaxService {
  final _supabase = Supabase.instance.client;

  /// Fetches tax summary for a given date range
  /// Calls RPC: get_tax_summary(p_start_date, p_end_date)
  Future<TaxSummary> getTaxSummary(DateTime startDate, DateTime endDate) async {
    try {
      // Enhanced debug: Check authentication and JWT structure
      final user = _supabase.auth.currentUser;
      print('🔍 DEBUG Tax Service - Enhanced Authentication check:');
      print('  - User authenticated: ${user != null}');
      if (user != null) {
        print('  - User ID: ${user.id}');
        print('  - User metadata: ${user.userMetadata}');
        print('  - App metadata: ${user.appMetadata}');
        print('  - JWT claims store_id: ${user.appMetadata?['store_id']}');
        
        // Check session
        final session = _supabase.auth.currentSession;
        print('  - Session exists: ${session != null}');
        if (session != null) {
          print('  - Access token length: ${session.accessToken.length}');
          print('  - Refresh token exists: ${session.refreshToken != null}');
        }
        
        // Check BaseService store ID
        print('  - BaseService currentStoreId: ${_supabase.auth.currentUser?.appMetadata?['store_id']}');
        
        // Get store_id from user metadata
        final storeId = user.userMetadata?['store_id'] as String?;
        print('  - Store ID from user metadata: $storeId');
      }

      print('🚀 Calling get_tax_summary RPC with params:');
      print('  - Start date: ${startDate.toIso8601String()}');
      print('  - End date: ${endDate.toIso8601String()}');

      // ALTERNATIVE APPROACH: Call RPC with explicit store_id parameter
      final storeId = user?.userMetadata?['store_id'] as String?;
      if (storeId == null) {
        throw Exception('No store_id found in user metadata');
      }

      // Try direct query first to see if there's any data
      print('🔍 DEBUG: Checking transactions table directly...');
      final directQuery = await _supabase
          .from('transactions')
          .select('id, total_amount, created_at')
          .eq('store_id', storeId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());
      
      print('🔍 DEBUG: Direct transactions query returned: ${directQuery.length} records');
      if (directQuery.isNotEmpty) {
        final totalRevenue = directQuery.fold<double>(0, (sum, tx) => sum + (tx['total_amount'] as num).toDouble());
        print('🔍 DEBUG: Total revenue from direct query: $totalRevenue');
      }

      // Check purchase orders too
      final poQuery = await _supabase
          .from('purchase_orders')
          .select('id, total_amount, delivery_date, status')
          .eq('store_id', storeId)
          .eq('status', 'DELIVERED')
          .gte('delivery_date', startDate.toIso8601String())
          .lte('delivery_date', endDate.toIso8601String());
      
      print('🔍 DEBUG: Direct purchase_orders query returned: ${poQuery.length} records');
      if (poQuery.isNotEmpty) {
        final totalExpenses = poQuery.fold<double>(0, (sum, po) => sum + (po['total_amount'] as num).toDouble());
        print('🔍 DEBUG: Total expenses from direct query: $totalExpenses');
      }

      // Now try the RPC
      final response = await _supabase.rpc('get_tax_summary', params: {
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      });

      print('✅ RPC Response received: $response');
      
      final taxSummary = TaxSummary.fromJson(response as Map<String, dynamic>);
      print('✅ TaxSummary parsed successfully: totalRevenue=${taxSummary.totalRevenue}, estimatedTax=${taxSummary.estimatedTax}');
      
      return taxSummary;
    } catch (e) {
      print('❌ Error in getTaxSummary: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Fetches sales ledger data for export
  /// Calls RPC: get_sales_ledger_for_export(p_start_date, p_end_date)
  /// Returns list of transactions with: transaction_id, date, customer_name, total_amount
  Future<List<Map<String, dynamic>>> getSalesLedgerForExport(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _supabase.rpc('get_sales_ledger_for_export', params: {
        'p_start_date': startDate.toIso8601String(),
        'p_end_date': endDate.toIso8601String(),
      });

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error in getSalesLedgerForExport: $e');
      rethrow;
    }
  }

  /// Export sales ledger to CSV format (Future implementation)
  /// This will be implemented later to generate CSV file from ledger data
  Future<String> exportSalesLedgerToCSV(DateTime startDate, DateTime endDate) async {
    // TODO: Implement CSV export functionality
    // Will use package:csv or similar to generate CSV from getSalesLedgerForExport data
    throw UnimplementedError('CSV export will be implemented in next iteration');
  }
}
