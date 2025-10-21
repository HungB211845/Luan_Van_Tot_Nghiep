import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/invoice_data.dart';
import '../../pos/models/transaction.dart';

class InvoiceService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get complete invoice data for a transaction (Sales Invoice)
  ///
  /// Calls RPC function: get_invoice_data
  /// Returns InvoiceData with store info, transaction, customer, and items
  Future<InvoiceData> getTransactionInvoiceData(String transactionId) async {
    try {
      ensureAuthenticated();

      final response = await _supabase.rpc(
        'get_invoice_data',
        params: {'p_transaction_id': transactionId},
      );

      if (response == null) {
        throw Exception('Không tìm thấy dữ liệu hóa đơn cho giao dịch $transactionId');
      }

      return InvoiceData.fromTransactionRpc(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Lỗi lấy dữ liệu hóa đơn bán hàng: $e');
    }
  }

  /// Get complete invoice data for a purchase order (PO Invoice)
  ///
  /// Calls RPC function: get_po_invoice_data
  /// Returns InvoiceData with store info, PO, supplier, and items
  Future<InvoiceData> getPOInvoiceData(String poId) async {
    try {
      ensureAuthenticated();

      final response = await _supabase.rpc(
        'get_po_invoice_data',
        params: {'p_po_id': poId},
      );

      if (response == null) {
        throw Exception('Không tìm thấy dữ liệu hóa đơn cho đơn hàng $poId');
      }

      return InvoiceData.fromPurchaseOrderRpc(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Lỗi lấy dữ liệu hóa đơn nhập hàng: $e');
    }
  }

  /// Get transactions for export to Excel report
  ///
  /// Calls RPC function: get_transactions_for_export
  /// Returns list of Transaction objects with items for date range
  Future<List<Transaction>> getTransactionsForExport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      ensureAuthenticated();

      final response = await _supabase.rpc(
        'get_transactions_for_export',
        params: {
          'p_start_date': startDate.toIso8601String().split('T')[0], // DATE format
          'p_end_date': endDate.toIso8601String().split('T')[0],     // DATE format
        },
      );

      if (response == null || response == []) {
        return []; // No transactions found
      }

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final txData = item['transaction'] as Map<String, dynamic>;
        return Transaction.fromJson(txData);
      }).toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách giao dịch để xuất báo cáo: $e');
    }
  }

  /// Get export data with full details (transaction + items)
  ///
  /// Returns structured data ready for Excel export
  Future<List<Map<String, dynamic>>> getTransactionsExportData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      ensureAuthenticated();

      final response = await _supabase.rpc(
        'get_transactions_for_export',
        params: {
          'p_start_date': startDate.toIso8601String().split('T')[0],
          'p_end_date': endDate.toIso8601String().split('T')[0],
        },
      );

      if (response == null || response == []) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Lỗi lấy dữ liệu xuất báo cáo: $e');
    }
  }
}
