import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_batch.dart'; // Cần cho _reduceInventoryFIFO
import '../models/transaction.dart';
import '../models/transaction_item.dart';
// import '../models/customer.dart'; // Tạm thời bỏ comment
// import 'debt_service.dart'; // Tạm thời bỏ comment

// enum PaymentMethod { CASH, DEBT } // Tạm thời bỏ comment, sẽ dùng từ models/transaction.dart

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final DebtService _debtService; // Tạm thời bỏ comment

  TransactionService(); // Tạm thời không inject DebtService

  // =====================================================
  // TRANSACTION OPERATIONS (POS SALES)
  // =====================================================

  /// Tạo transaction mới với items (bán hàng)
  Future<String> createTransaction({
    required String? customerId,
    required List<TransactionItem> items,
    required PaymentMethod paymentMethod,
    String? notes,
    // Customer? customer, // Tạm thời bỏ comment
  }) async {
    try {
      // Tính total amount
      final totalAmount = items.fold<double>(
        0, (sum, item) => sum + item.subTotal
      );

      // Tạo transaction trước
      final transactionData = {
        'customer_id': customerId,
        'total_amount': totalAmount,
        'is_debt': paymentMethod == PaymentMethod.DEBT, // Xác định isDebt dựa vào paymentMethod
        'payment_method': paymentMethod.toString().split('.').last,
        'notes': notes,
        'invoice_number': _generateInvoiceNumber(),
      };

      final transactionResponse = await _supabase
          .from('transactions')
          .insert(transactionData)
          .select()
          .single();

      final transactionId = transactionResponse['id'];

      // Thêm transaction items
      final itemsData = items.map((item) {
        final itemData = item.toJson();
        itemData['transaction_id'] = transactionId;
        return itemData;
      }).toList();

      await _supabase
          .from('transaction_items')
          .insert(itemsData);

      // Update inventory (trừ stock theo FIFO)
      for (final item in items) {
        await _reduceInventoryFIFO(item.productId, item.quantity);
      }

      // Nếu là giao dịch ghi nợ, tạo bản ghi nợ (sẽ được xử lý sau khi DebtService hoàn thiện)
      // if (paymentMethod == PaymentMethod.DEBT && customer != null) {
      //   await _debtService.createDebtFromTransaction(
      //     Transaction.fromJson(transactionResponse),
      //     customer,
      //   );
      // }

      return transactionId;
    } catch (e) {
      throw Exception('Lỗi tạo giao dịch: $e');
    }
  }

  /// Reduce inventory theo FIFO (First In First Out)
  Future<void> _reduceInventoryFIFO(String productId, int quantityToReduce) async {
    try {
      // Lấy batches theo FIFO order
      final batches = await _supabase
          .from('product_batches')
          .select('*')
          .eq('product_id', productId)
          .eq('is_available', true)
          .gt('quantity', 0)
          .or('expiry_date.is.null,expiry_date.gt.${DateTime.now().toIso8601String().split('T')[0]}')
          .order('received_date', ascending: true);

      int remainingToReduce = quantityToReduce;

      for (final batchData in batches) {
        if (remainingToReduce <= 0) break;

        final batch = ProductBatch.fromJson(batchData);

        if (batch.quantity <= remainingToReduce) {
          // Use up entire batch
          remainingToReduce -= batch.quantity;
          await _updateBatchQuantity(batch.id, 0); // Gọi hàm private
        } else {
          // Partial use of batch
          await _updateBatchQuantity(batch.id, batch.quantity - remainingToReduce); // Gọi hàm private
          remainingToReduce = 0;
        }
      }

      if (remainingToReduce > 0) {
        throw Exception('Không đủ hàng tồn kho (thiếu $remainingToReduce)');
      }
    } catch (e) {
      throw Exception('Lỗi cập nhật tồn kho: $e');
    }
  }

  /// Update batch quantity (khi bán hàng) - Di chuyển từ ProductService
  Future<void> _updateBatchQuantity(String batchId, int newQuantity) async {
    try {
      await _supabase
          .from('product_batches')
          .update({'quantity': newQuantity})
          .eq('id', batchId);
    } catch (e) {
      throw Exception('Lỗi cập nhật số lượng lô hàng: $e');
    }
  }

  /// Generate invoice number
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
    return 'INV$dateStr$timeStr';
  }

  /// Lấy transaction history
  Future<List<Transaction>> getTransactionHistory({
    String? customerId,
    int limit = 50,
  }) async {
    try {
      var query = _supabase
          .from('transactions')
          .select('*');

      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      final response = await query
          .order('transaction_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử giao dịch: $e');
    }
  }

  /// Lấy transaction items của một transaction
  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    try {
      final response = await _supabase
          .from('transaction_items')
          .select('*')
          .eq('transaction_id', transactionId);

      return (response as List)
          .map((json) => TransactionItem.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy chi tiết giao dịch: $e');
    }
  }

  /// Lấy thông tin một giao dịch theo ID
Future<Transaction?> getTransactionById(String transactionId) async {
  try {
    final response = await _supabase
        .from('transactions')
        .select()
        .eq('id', transactionId)
        .maybeSingle();
    return response == null ? null : Transaction.fromJson(response);
  } catch (e) {
    throw Exception('Lỗi lấy thông tin giao dịch: $e');
  }
}

  /// Lấy transactions với debt flag
  Future<List<Transaction>> getDebtTransactions({String? customerId}) async {
    try {
      var query = _supabase
          .from('transactions')
          .select('*')
          .eq('is_debt', true);

      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      final response = await query
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách giao dịch nợ: $e');
    }
  }

  /// Get today's sales statistics
  Future<Map<String, dynamic>> getTodaySalesStats() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final todaySales = await _supabase
          .from('transactions')
          .select('total_amount')
          .gte('transaction_date', '${today}T00:00:00')
          .lt('transaction_date', '${today}T23:59:59');

      final todayRevenue = todaySales.fold<double>(
        0, (sum, sale) => sum + (sale['total_amount'] as num).toDouble()
      );

      return {
        'today_revenue': todayRevenue,
        'today_transactions': todaySales.length,
      };
    } catch (e) {
      throw Exception('Lỗi lấy thống kê bán hàng hôm nay: $e');
    }
  }
}