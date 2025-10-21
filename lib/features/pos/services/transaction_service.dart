import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../../products/models/product_batch.dart'; // Cần cho _reduceInventoryFIFO
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../models/payment_method.dart';
import '../../../shared/models/paginated_result.dart';
import '../../debt/services/debt_service.dart';

class TransactionService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DebtService _debtService;

  TransactionService({DebtService? debtService})
      : _debtService = debtService ?? DebtService();

  // =====================================================
  // TRANSACTION OPERATIONS (POS SALES)
  // =====================================================

  /// Tạo transaction mới với items (bán hàng)
  Future<String> createTransaction({
    required String? customerId,
    required List<TransactionItem> items,
    required PaymentMethod paymentMethod,
    String? notes,
    DateTime? debtDueDate, // Due date for debt transactions
    double surchargeAmount = 0.0, // Phụ phí cho giao dịch ghi nợ
  }) async {
    try {
      ensureAuthenticated();
      // Tính base amount từ items và final total amount
      final baseAmount = items.fold<double>(
        0, (sum, item) => sum + item.subTotal
      );
      final totalAmount = baseAmount + surchargeAmount;

      final transactionTimestamp = DateTime.now().toUtc();

      // Tạo transaction trước
      final transactionData = addStoreId({
        'customer_id': customerId,
        'total_amount': totalAmount,
        'surcharge_amount': surchargeAmount,
        'is_debt': paymentMethod == PaymentMethod.debt, // Xác định isDebt dựa vào paymentMethod
        'payment_method': paymentMethod.value,
        'notes': notes,
        'invoice_number': _generateInvoiceNumber(),
        'transaction_date': transactionTimestamp.toIso8601String(),
      });

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
        return addStoreId(itemData);
      }).toList();

      // 🔍 DEBUG: In ra itemsData trước khi INSERT vào database
      print('🔍 [TransactionService.createTransaction] Inserting ${itemsData.length} items into database:');
      for (var i = 0; i < itemsData.length; i++) {
        final itemData = itemsData[i];
        print('  Item ${i + 1}: unit_name="${itemData['unit_name']}", price=${itemData['price_at_sale']}, quantity=${itemData['quantity']}');
        print('  Full JSON: $itemData');
      }

      await _supabase
          .from('transaction_items')
          .insert(itemsData);

      // Update inventory using optimized batch FIFO function
      await _updateInventoryBatchFIFO(items);

      // Create debt record if payment method is debt
      if (paymentMethod == PaymentMethod.debt && customerId != null) {
        try {
          await _debtService.createDebtFromTransaction(
            transaction: Transaction.fromJson(transactionResponse),
            customerId: customerId,
            dueDate: debtDueDate,
            notes: notes,
          );
        } catch (debtError) {
          // Log debt creation error but don't fail the transaction
          // Transaction is already created, debt can be created manually later
          print('Warning: Failed to create debt record: $debtError');
        }
      }

      return transactionId;
    } catch (e) {
      throw Exception('Lỗi tạo giao dịch: $e');
    }
  }

  /// Update inventory using optimized batch FIFO function
  Future<void> _updateInventoryBatchFIFO(List<TransactionItem> items) async {
    try {
      ensureAuthenticated();

      // Start performance tracking
      final stopwatch = Stopwatch()..start();

      // Prepare items for batch processing
      // Multi-UoM: Pass base_unit_quantity to RPC for FIFO calculation
      final itemsJson = items.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'base_unit_quantity': item.baseUnitQuantity ?? item.quantity.toDouble(),
      }).toList();

      final response = await _supabase.rpc(
        'update_inventory_fifo_batch',
        params: {'items_json': itemsJson},
      );

      stopwatch.stop();

      // Log slow queries for performance monitoring
      if (stopwatch.elapsedMilliseconds > 100) {
        await _logSlowQuery(
          'update_inventory_fifo_batch',
          stopwatch.elapsedMilliseconds,
          {'items_count': items.length},
        );
      }

      final result = response as Map<String, dynamic>;

      if (result['success'] != true) {
        throw Exception('Lỗi cập nhật tồn kho: ${result['error']}');
      }

      // Check for insufficient stock
      final insufficientStock = result['insufficient_stock'] as List<dynamic>;
      if (insufficientStock.isNotEmpty) {
        final shortages = insufficientStock.map((item) {
          return 'Sản phẩm ${item['product_id']}: thiếu ${item['shortage']} từ ${item['requested_quantity']}';
        }).join(', ');
        throw Exception('Không đủ hàng tồn kho: $shortages');
      }

    } catch (e) {
      throw Exception('Lỗi cập nhật tồn kho: $e');
    }
  }

  /// Generate invoice number
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
    return 'INV$dateStr$timeStr';
  }

  /// Log slow queries for performance monitoring
  /// TEMPORARILY DISABLED: Causing database overload during timeout issues
  Future<void> _logSlowQuery(
    String queryType,
    int executionTimeMs,
    Map<String, dynamic> queryParams,
  ) async {
    // DISABLED: This was creating infinite loop when database is slow
    // Re-enable after database performance is fixed
    return;

    /* ORIGINAL CODE - COMMENTED OUT
    try {
      await _supabase.rpc(
        'log_slow_query',
        params: {
          'p_query_type': queryType,
          'p_execution_time_ms': executionTimeMs,
          'p_query_params': queryParams,
        },
      );
    } catch (e) {
      // Don't throw on logging errors, just print them
      print('Failed to log slow query: $e');
    }
    */
  }

  // =====================================================
  // CORE TRANSACTION SEARCH METHOD (NEW)
  // =====================================================

  /// Performs a comprehensive, paginated search for transactions using the optimized `search_transactions_with_items` RPC function.
  /// This is the primary method for fetching transactions with optional transaction items included.
  Future<PaginatedResult<Transaction>> searchTransactions({
    String? searchText,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    List<PaymentMethod>? paymentMethods,
    List<String>? customerIds,
    String? debtStatus, // 'paid', 'unpaid', or 'all'
    bool includeItems = false, // New parameter to include transaction items
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      ensureAuthenticated();

      // Start performance tracking
      final stopwatch = Stopwatch()..start();

      final params = {
        'p_search_text': searchText,
        'p_start_date': startDate?.toIso8601String(),
        'p_end_date': endDate?.toIso8601String(),
        'p_min_amount': minAmount,
        'p_max_amount': maxAmount,
        'p_payment_methods': paymentMethods?.map((e) => e.value).toList(),
        'p_customer_ids': customerIds,
        'p_debt_status': debtStatus,
        'p_include_items': includeItems,
        'p_page': page,
        'p_page_size': pageSize,
      };

      // Remove null values from params to avoid sending them to Supabase
      params.removeWhere((key, value) => value == null);

      final response = await _supabase.rpc(
        'search_transactions_with_items',
        params: params,
      );

      stopwatch.stop();

      // Log slow queries for performance monitoring
      if (stopwatch.elapsedMilliseconds > 100) {
        await _logSlowQuery(
          'search_transactions_with_items',
          stopwatch.elapsedMilliseconds,
          params,
        );
      }

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return PaginatedResult.empty();
      }

      final transactions = data.map((json) => Transaction.fromRpcJson(json)).toList();
      final totalCount = data.first['total_count'] as int;

      return PaginatedResult.fromSupabaseResponse(
        items: transactions,
        totalCount: totalCount,
        offset: (page - 1) * pageSize,
        limit: pageSize,
      );
    } catch (e) {
      // Log the error for better debugging
      print('Error in searchTransactions RPC call: $e');
      throw Exception('Lỗi tìm kiếm giao dịch: $e');
    }
  }

  @deprecated
  Future<PaginatedResult<Transaction>> getTransactionHistoryPaginated({
    PaginationParams? params,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
  }) async {
    return searchTransactions(
      customerIds: customerId != null ? [customerId] : null,
      startDate: startDate,
      endDate: endDate,
      debtStatus: isDebt == null ? null : (isDebt ? 'unpaid' : 'paid'),
      paymentMethods: paymentMethod != null ? [paymentMethod] : null,
      page: params?.page ?? 1,
      pageSize: params?.pageSize ?? 20,
    );
  }

  @deprecated
  Future<PaginatedResult<Transaction>> searchTransactionsPaginated({
    required String query,
    PaginationParams? params,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
  }) async {
    return searchTransactions(
      searchText: query,
      customerIds: customerId != null ? [customerId] : null,
      startDate: startDate,
      endDate: endDate,
      debtStatus: isDebt == null ? null : (isDebt ? 'unpaid' : 'paid'),
      paymentMethods: paymentMethod != null ? [paymentMethod] : null,
      page: params?.page ?? 1,
      pageSize: params?.pageSize ?? 20,
    );
  }

  @deprecated
  Future<PaginatedResult<Transaction>> getDebtTransactionsPaginated({
    PaginationParams? params,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return searchTransactions(
      customerIds: customerId != null ? [customerId] : null,
      startDate: startDate,
      endDate: endDate,
      debtStatus: 'unpaid',
      page: params?.page ?? 1,
      pageSize: params?.pageSize ?? 20,
    );
  }

  @deprecated
  Future<PaginatedResult<Transaction>> getTodayTransactionsPaginated({
    PaginationParams? params,
    String? customerId,
    PaymentMethod? paymentMethod,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return searchTransactions(
      customerIds: customerId != null ? [customerId] : null,
      startDate: startOfDay,
      endDate: endOfDay,
      paymentMethods: paymentMethod != null ? [paymentMethod] : null,
      page: params?.page ?? 1,
      pageSize: params?.pageSize ?? 20,
    );
  }

  // =====================================================
  // TRANSACTION QUERIES - LEGACY (DEPRECATED)
  // =====================================================

  @deprecated
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

  /// Lấy transaction items của một transaction (DEPRECATED - use getTransactionWithItems)
  @deprecated
  Future<List<TransactionItem>> getTransactionItems(String transactionId) async {
    // Use the legacy method for backward compatibility
    try {
      ensureAuthenticated();

      final response = await _supabase
          .from('transaction_items')
          .select()
          .eq('transaction_id', transactionId)
          .eq('store_id', BaseService.getDefaultStoreId());

      return response.map<TransactionItem>((data) => TransactionItem(
        id: data['id'],
        transactionId: data['transaction_id'],
        productId: data['product_id'],
        batchId: data['batch_id'],
        quantity: data['quantity'],
        priceAtSale: (data['price_at_sale'] as num).toDouble(),
        subTotal: (data['sub_total'] as num).toDouble(),
        discountAmount: (data['discount_amount'] as num?)?.toDouble() ?? 0.0,
        storeId: data['store_id'],
        createdAt: DateTime.parse(data['created_at']),
        // 🔥 FIX: Parse unit fields for Multi-UoM support
        unitId: data['unit_id'] as String?,
        unitName: data['unit_name'] as String?,
        unitConversionFactor: (data['unit_conversion_factor'] as num?)?.toDouble(),
        baseUnitQuantity: (data['base_unit_quantity'] as num?)?.toDouble(),
      )).toList();
    } catch (e) {
      throw Exception('Lỗi lấy transaction items: $e');
    }
  }

  /// Lấy transaction với items (1 query thay vì 2) - OPTIMIZED
  Future<Transaction?> getTransactionWithItems(String transactionId) {
    print('[DEBUG] Service: Fetching tx with id: $transactionId for store: ${BaseService.getDefaultStoreId()}');
    return _fetchTransactionWithItems(transactionId: transactionId);
  }

  Future<Transaction?> getTransactionWithItemsByInvoice(String invoiceNumber) {
    print('[DEBUG] Service: Fetching tx with invoice: $invoiceNumber for store: ${BaseService.getDefaultStoreId()}');
    return _fetchTransactionWithItems(invoiceNumber: invoiceNumber);
  }

  Future<Transaction?> _fetchTransactionWithItems({
    String? transactionId,
    String? invoiceNumber,
  }) async {
    assert(
      (transactionId != null && invoiceNumber == null) ||
          (transactionId == null && invoiceNumber != null),
      'Provide either transactionId or invoiceNumber',
    );

    try {
      ensureAuthenticated();

      final stopwatch = Stopwatch()..start();
      final storeId = BaseService.getDefaultStoreId();

      var query = _supabase
          .from('transactions')
          .select('''
            id, created_at, store_id, customer_id, total_amount,
            payment_method, is_debt, transaction_date, notes, invoice_number,
            customers(name),
            transaction_items(
              id, product_id, batch_id, quantity,
              price_at_sale, sub_total, discount_amount,
              unit_id, unit_name, unit_conversion_factor, base_unit_quantity,
              store_id, created_at,
              products(name, sku)
            )
          ''');

      if (transactionId != null) {
        query = query.eq('id', transactionId);
      }
      if (invoiceNumber != null) {
        query = query.eq('invoice_number', invoiceNumber);
      }
      if (storeId != null) {
        query = query.eq('store_id', storeId);
      }

      final response = await query.maybeSingle();

      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > 100) {
        await _logSlowQuery(
          'get_transaction_with_items',
          stopwatch.elapsedMilliseconds,
          {
            if (transactionId != null) 'transaction_id': transactionId,
            if (invoiceNumber != null) 'invoice_number': invoiceNumber,
          },
        );
      }

      if (response == null) {
        final key = transactionId ?? invoiceNumber;
        print('[TransactionService] No transaction found for key=$key');
        return null;
      }

      print('[TransactionService] Transaction found for ${transactionId ?? invoiceNumber}');
      return _convertNestedTransactionResponse(response);
    } catch (e) {
      throw Exception('Lỗi lấy giao dịch với items: $e');
    }
  }

  /// Convert nested Supabase response to Transaction with items
  Transaction _convertNestedTransactionResponse(Map<String, dynamic> response) {
    // Extract transaction items from nested response
    final List<TransactionItem> items = [];
    final transactionItemsData = response['transaction_items'] as List<dynamic>? ?? [];

    for (final itemData in transactionItemsData) {
      final productData = itemData['products'] as Map<String, dynamic>? ?? {};

      // 🔍 DEBUG: Print raw Supabase response để verify unit fields
      print('🔍 [TransactionService] Raw itemData from Supabase:');
      print('  unit_id: ${itemData['unit_id']}');
      print('  unit_name: ${itemData['unit_name']}');
      print('  unit_conversion_factor: ${itemData['unit_conversion_factor']}');
      print('  base_unit_quantity: ${itemData['base_unit_quantity']}');
      print('  Full itemData keys: ${itemData.keys.toList()}');

      // Create TransactionItem with product info
      final unitPrice = _toDouble(itemData['price_at_sale']) ??
          _toDouble(itemData['unit_price']) ??
          (_toDouble(itemData['sub_total']) ?? 0.0) /
              (itemData['quantity'] as num).clamp(1, double.infinity);

      final item = TransactionItem(
        id: itemData['id'] as String,
        transactionId: response['id'] as String,
        productId: itemData['product_id'] as String,
        batchId: itemData['batch_id'] as String?,
        quantity: itemData['quantity'] as int,
        priceAtSale: unitPrice,
        subTotal: _toDouble(itemData['sub_total']) ?? 0.0,
        discountAmount: (itemData['discount_amount'] as num?)?.toDouble() ?? 0.0,
        storeId: (itemData['store_id'] as String?) ?? (response['store_id'] as String),
        createdAt: itemData['created_at'] != null
            ? DateTime.parse(itemData['created_at'] as String)
            : DateTime.parse(response['created_at'] as String),
        unitId: itemData['unit_id'] as String?,
        unitName: itemData['unit_name'] as String?,
        unitConversionFactor: (itemData['unit_conversion_factor'] as num?)?.toDouble(),
        baseUnitQuantity: (itemData['base_unit_quantity'] as num?)?.toDouble(),
      );

      items.add(item);
    }

    // Extract customer info
    final customerData = response['customers'] as Map<String, dynamic>?;
    final customerName = customerData?['name'] as String?;

    // Create Transaction
    final transaction = Transaction(
      id: response['id'] as String,
      storeId: response['store_id'] as String,
      customerId: response['customer_id'] as String?,
      totalAmount: (response['total_amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromString(response['payment_method'] as String),
      isDebt: response['is_debt'] as bool,
      transactionDate: DateTime.parse(response['transaction_date'] as String),
      notes: response['notes'] as String?,
      invoiceNumber: response['invoice_number'] as String?,
      createdAt: DateTime.parse(response['created_at'] as String),
      customerName: customerName,
    );

    return transaction;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Lấy thông tin một giao dịch theo ID (DEPRECATED - use getTransactionWithItems for better performance)
  @deprecated
  Future<Transaction?> getTransactionById(String transactionId) async {
    try {
      final response = await addStoreFilter(_supabase
          .from('transactions')
          .select())
          .eq('id', transactionId)
          .maybeSingle();
      return response == null ? null : Transaction.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin giao dịch: $e');
    }
  }

  @deprecated
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
      final todaySales = await addStoreFilter(_supabase
          .from('transactions')
          .select('total_amount'))
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
