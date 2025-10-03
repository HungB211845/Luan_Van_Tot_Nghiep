import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_revenue.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  // Tax rate for agricultural business (1.5% theo quy định)
  static const double TAX_RATE = 0.015;

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

  /// Get monthly revenue summary
  Future<Map<String, dynamic>> getMonthlyRevenue(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0); // Last day of month

      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transactions')
          .select('total_amount, payment_method, created_at')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final transactions = response as List;

      double totalRevenue = 0.0;
      double cashRevenue = 0.0;
      double debtRevenue = 0.0;
      int totalTransactions = transactions.length;

      for (var txn in transactions) {
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += amount;

        final paymentMethod = txn['payment_method'] as String?;
        if (paymentMethod == 'cash') {
          cashRevenue += amount;
        } else if (paymentMethod == 'debt') {
          debtRevenue += amount;
        }
      }

      final taxAmount = totalRevenue * TAX_RATE;

      return {
        'month': month,
        'year': year,
        'total_revenue': totalRevenue,
        'cash_revenue': cashRevenue,
        'debt_revenue': debtRevenue,
        'total_transactions': totalTransactions,
        'tax_amount': taxAmount,
        'net_revenue': totalRevenue - taxAmount,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get quarterly revenue summary
  Future<Map<String, dynamic>> getQuarterlyRevenue(int year, int quarter) async {
    try {
      final startMonth = (quarter - 1) * 3 + 1;
      final endMonth = quarter * 3;

      final startDate = DateTime(year, startMonth, 1);
      final endDate = DateTime(year, endMonth + 1, 0);

      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transactions')
          .select('total_amount, payment_method')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final transactions = response as List;

      double totalRevenue = 0.0;
      double cashRevenue = 0.0;
      double debtRevenue = 0.0;
      int totalTransactions = transactions.length;

      for (var txn in transactions) {
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += amount;

        final paymentMethod = txn['payment_method'] as String?;
        if (paymentMethod == 'cash') {
          cashRevenue += amount;
        } else if (paymentMethod == 'debt') {
          debtRevenue += amount;
        }
      }

      final taxAmount = totalRevenue * TAX_RATE;

      return {
        'quarter': quarter,
        'year': year,
        'total_revenue': totalRevenue,
        'cash_revenue': cashRevenue,
        'debt_revenue': debtRevenue,
        'total_transactions': totalTransactions,
        'tax_amount': taxAmount,
        'net_revenue': totalRevenue - taxAmount,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transaction_items')
          .select('''
            product_id,
            products!inner(name),
            quantity,
            sub_total
          ''')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final items = response as List;

      // Group by product and calculate totals
      final Map<String, Map<String, dynamic>> productStats = {};

      for (var item in items) {
        final productId = item['product_id'] as String;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final subTotal = (item['sub_total'] as num?)?.toDouble() ?? 0.0;
        final product = item['products'] as Map<String, dynamic>?;

        if (product != null) {
          if (!productStats.containsKey(productId)) {
            productStats[productId] = {
              'product_id': productId,
              'product_name': product['name'] ?? 'Unknown',
              'unit': '',
              'total_quantity': 0.0,
              'total_revenue': 0.0,
              'transaction_count': 0,
            };
          }

          productStats[productId]!['total_quantity'] =
              (productStats[productId]!['total_quantity'] as double) + quantity;
          productStats[productId]!['total_revenue'] =
              (productStats[productId]!['total_revenue'] as double) + subTotal;
          productStats[productId]!['transaction_count'] =
              (productStats[productId]!['transaction_count'] as int) + 1;
        }
      }

      // Sort by total revenue and return top products
      final sortedProducts = productStats.values.toList()
        ..sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));

      return sortedProducts.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get inventory value and low stock analysis
  Future<Map<String, dynamic>> getInventoryAnalytics() async {
    try {
      final response = await _supabase
          .from('product_batches')
          .select('''
            quantity,
            cost_price,
            expiry_date,
            products(name, current_selling_price)
          ''')
          .gt('quantity', 0);

      final batches = response as List;

      double totalInventoryValue = 0.0;
      double totalSellingValue = 0.0;
      int lowStockItems = 0;
      int expiringSoonItems = 0;
      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));

      for (var batch in batches) {
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        final costPrice = (batch['cost_price'] as num?)?.toDouble() ?? 0.0;
        final product = batch['products'] as Map<String, dynamic>?;
        final expiryDate = batch['expiry_date'] as String?;

        totalInventoryValue += quantity * costPrice;

        if (product != null) {
          final sellingPrice = (product['current_selling_price'] as num?)?.toDouble() ?? 0.0;
          totalSellingValue += quantity * sellingPrice;
        }

        // Check low stock (less than 10 units)
        if (quantity <= 10) {
          lowStockItems++;
        }

        // Check expiring soon
        if (expiryDate != null) {
          final expiry = DateTime.parse(expiryDate);
          if (expiry.isBefore(thirtyDaysFromNow)) {
            expiringSoonItems++;
          }
        }
      }

      final potentialProfit = totalSellingValue - totalInventoryValue;

      return {
        'total_inventory_value': totalInventoryValue,
        'total_selling_value': totalSellingValue,
        'potential_profit': potentialProfit,
        'profit_margin': totalSellingValue > 0 ? (potentialProfit / totalSellingValue) * 100 : 0.0,
        'low_stock_items': lowStockItems,
        'expiring_soon_items': expiringSoonItems,
        'total_batches': batches.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate tax summary for a given period
  static double calculateTax(double revenue) {
    return revenue * TAX_RATE;
  }

  /// Get payment method breakdown for a period
  Future<Map<String, dynamic>> getPaymentMethodBreakdown({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transactions')
          .select('payment_method, total_amount')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final transactions = response as List;

      final breakdown = <String, Map<String, dynamic>>{};

      for (var txn in transactions) {
        final method = txn['payment_method'] as String? ?? 'unknown';
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0.0;

        if (!breakdown.containsKey(method)) {
          breakdown[method] = {
            'count': 0,
            'total_amount': 0.0,
          };
        }

        breakdown[method]!['count'] = (breakdown[method]!['count'] as int) + 1;
        breakdown[method]!['total_amount'] =
            (breakdown[method]!['total_amount'] as double) + amount;
      }

      return breakdown;
    } catch (e) {
      rethrow;
    }
  }

  /// Get sales performance metrics comparing two periods
  Future<Map<String, dynamic>> getSalesPerformanceComparison({
    DateTime? currentStart,
    DateTime? currentEnd,
    DateTime? previousStart,
    DateTime? previousEnd,
  }) async {
    try {
      final currentPeriodStart = currentStart ?? DateTime.now().subtract(const Duration(days: 30));
      final currentPeriodEnd = currentEnd ?? DateTime.now();
      final previousPeriodStart = previousStart ?? currentPeriodStart.subtract(const Duration(days: 30));
      final previousPeriodEnd = previousEnd ?? currentPeriodStart.subtract(const Duration(days: 1));

      // Get current period data
      final currentData = await _getPeriodSalesData(currentPeriodStart, currentPeriodEnd);
      final previousData = await _getPeriodSalesData(previousPeriodStart, previousPeriodEnd);

      // Calculate growth percentages
      final revenueGrowth = _calculateGrowthPercentage(
        currentData['revenue'] as double,
        previousData['revenue'] as double,
      );
      final transactionGrowth = _calculateGrowthPercentage(
        (currentData['transaction_count'] as int).toDouble(),
        (previousData['transaction_count'] as int).toDouble(),
      );
      final avgOrderValueGrowth = _calculateGrowthPercentage(
        currentData['avg_order_value'] as double,
        previousData['avg_order_value'] as double,
      );

      return {
        'current_period': currentData,
        'previous_period': previousData,
        'growth_metrics': {
          'revenue_growth': revenueGrowth,
          'transaction_growth': transactionGrowth,
          'avg_order_value_growth': avgOrderValueGrowth,
        },
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get hourly sales distribution for performance analysis
  Future<List<Map<String, dynamic>>> getHourlySalesDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
      final end = endDate ?? DateTime.now();

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transactions')
          .select('created_at, total_amount')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59')
          .order('created_at');

      final transactions = response as List;

      // Group by hour (0-23)
      final hourlyData = <int, Map<String, dynamic>>{};
      for (int hour = 0; hour < 24; hour++) {
        hourlyData[hour] = {
          'hour': hour,
          'revenue': 0.0,
          'transaction_count': 0,
        };
      }

      for (var txn in transactions) {
        final createdAt = DateTime.parse(txn['created_at'] as String);
        final hour = createdAt.hour;
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0.0;

        hourlyData[hour]!['revenue'] = (hourlyData[hour]!['revenue'] as double) + amount;
        hourlyData[hour]!['transaction_count'] = (hourlyData[hour]!['transaction_count'] as int) + 1;
      }

      return hourlyData.values.toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get customer analytics including new vs returning customers
  Future<Map<String, dynamic>> getCustomerAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      // Get transactions with customer info
      final response = await _supabase
          .from('transactions')
          .select('customer_id, total_amount, created_at')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final transactions = response as List;

      // Analyze customer behavior
      final customerData = <String, Map<String, dynamic>>{};
      int totalTransactions = transactions.length;
      double totalRevenue = 0.0;

      for (var txn in transactions) {
        final customerId = txn['customer_id'] as String?;
        final amount = (txn['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += amount;

        if (customerId != null) {
          if (!customerData.containsKey(customerId)) {
            customerData[customerId] = {
              'transaction_count': 0,
              'total_spent': 0.0,
              'first_transaction': txn['created_at'],
              'last_transaction': txn['created_at'],
            };
          }

          customerData[customerId]!['transaction_count'] =
              (customerData[customerId]!['transaction_count'] as int) + 1;
          customerData[customerId]!['total_spent'] =
              (customerData[customerId]!['total_spent'] as double) + amount;
          customerData[customerId]!['last_transaction'] = txn['created_at'];
        }
      }

      // Calculate metrics
      final uniqueCustomers = customerData.length;
      final repeatCustomers = customerData.values.where((c) => (c['transaction_count'] as int) > 1).length;
      final avgTransactionsPerCustomer = uniqueCustomers > 0 ? totalTransactions / uniqueCustomers : 0.0;
      final avgRevenuePerCustomer = uniqueCustomers > 0 ? totalRevenue / uniqueCustomers : 0.0;

      return {
        'total_customers': uniqueCustomers,
        'repeat_customers': repeatCustomers,
        'repeat_customer_rate': uniqueCustomers > 0 ? (repeatCustomers / uniqueCustomers) * 100 : 0.0,
        'avg_transactions_per_customer': avgTransactionsPerCustomer,
        'avg_revenue_per_customer': avgRevenuePerCustomer,
        'total_transactions': totalTransactions,
        'total_revenue': totalRevenue,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get product category performance analysis
  Future<List<Map<String, dynamic>>> getCategoryPerformance({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('transaction_items')
          .select('''
            product_id,
            products!inner(name, category),
            quantity,
            sub_total
          ''')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final items = response as List;

      // Group by category
      final categoryStats = <String, Map<String, dynamic>>{};

      for (var item in items) {
        final product = item['products'] as Map<String, dynamic>?;
        final category = product?['category'] as String? ?? 'Khác';
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final subTotal = (item['sub_total'] as num?)?.toDouble() ?? 0.0;

        if (!categoryStats.containsKey(category)) {
          categoryStats[category] = {
            'category': category,
            'total_quantity': 0.0,
            'total_revenue': 0.0,
            'product_count': <String>{},
            'transaction_count': 0,
          };
        }

        categoryStats[category]!['total_quantity'] =
            (categoryStats[category]!['total_quantity'] as double) + quantity;
        categoryStats[category]!['total_revenue'] =
            (categoryStats[category]!['total_revenue'] as double) + subTotal;
        (categoryStats[category]!['product_count'] as Set<String>).add(item['product_id'] as String);
        categoryStats[category]!['transaction_count'] =
            (categoryStats[category]!['transaction_count'] as int) + 1;
      }

      // Convert to list and add calculated metrics
      final result = categoryStats.values.map((cat) {
        final productCount = (cat['product_count'] as Set<String>).length;
        final totalRevenue = cat['total_revenue'] as double;
        final transactionCount = cat['transaction_count'] as int;

        return {
          'category': cat['category'],
          'total_quantity': cat['total_quantity'],
          'total_revenue': totalRevenue,
          'product_count': productCount,
          'transaction_count': transactionCount,
          'avg_revenue_per_transaction': transactionCount > 0 ? totalRevenue / transactionCount : 0.0,
        };
      }).toList();

      // Sort by revenue descending
      result.sort((a, b) => (b['total_revenue'] as double).compareTo(a['total_revenue'] as double));

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper method to get sales data for a specific period
  Future<Map<String, dynamic>> _getPeriodSalesData(DateTime start, DateTime end) async {
    final startDateStr = start.toIso8601String().split('T')[0];
    final endDateStr = end.toIso8601String().split('T')[0];

    final response = await _supabase
        .from('transactions')
        .select('total_amount')
        .gte('created_at', startDateStr)
        .lte('created_at', '$endDateStr 23:59:59');

    final transactions = response as List;

    double totalRevenue = 0.0;
    int transactionCount = transactions.length;

    for (var txn in transactions) {
      totalRevenue += (txn['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final avgOrderValue = transactionCount > 0 ? totalRevenue / transactionCount : 0.0;

    return {
      'revenue': totalRevenue,
      'transaction_count': transactionCount,
      'avg_order_value': avgOrderValue,
    };
  }

  /// Helper method to calculate growth percentage
  double _calculateGrowthPercentage(double current, double previous) {
    if (previous == 0) return current > 0 ? 100.0 : 0.0;
    return ((current - previous) / previous) * 100;
  }

  /// Get inventory turnover analysis
  Future<Map<String, dynamic>> getInventoryTurnoverAnalysis({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 90));
      final end = endDate ?? DateTime.now();

      // Get all products with their batches and sales data
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            name,
            category,
            current_selling_price,
            product_batches(quantity, cost_price)
          ''');

      final products = productsResponse as List;

      // Get sales data for the period
      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      final salesResponse = await _supabase
          .from('transaction_items')
          .select('product_id, quantity, sub_total')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final sales = salesResponse as List;

      // Calculate turnover metrics for each product
      final turnoverData = <String, Map<String, dynamic>>{};

      for (var product in products) {
        final productId = product['id'] as String;
        final productName = product['name'] as String;
        final category = product['category'] as String? ?? 'Khác';
        final batches = product['product_batches'] as List? ?? [];

        // Calculate current inventory value
        double currentStock = 0.0;
        double inventoryValue = 0.0;
        for (var batch in batches) {
          final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
          final costPrice = (batch['cost_price'] as num?)?.toDouble() ?? 0.0;
          currentStock += quantity;
          inventoryValue += quantity * costPrice;
        }

        // Calculate sales for this product
        final productSales = sales.where((sale) => sale['product_id'] == productId);
        double totalSoldQuantity = 0.0;
        double totalSalesValue = 0.0;

        for (var sale in productSales) {
          totalSoldQuantity += (sale['quantity'] as num?)?.toDouble() ?? 0.0;
          totalSalesValue += (sale['sub_total'] as num?)?.toDouble() ?? 0.0;
        }

        // Calculate turnover ratio (sold quantity / average inventory)
        final avgInventory = (currentStock + totalSoldQuantity) / 2;
        final turnoverRatio = avgInventory > 0 ? totalSoldQuantity / avgInventory : 0.0;

        // Days to sell current inventory
        final daysInPeriod = end.difference(start).inDays;
        final dailySalesRate = daysInPeriod > 0 ? totalSoldQuantity / daysInPeriod : 0.0;
        final daysToSellInventory = dailySalesRate > 0 ? currentStock / dailySalesRate : double.infinity;

        turnoverData[productId] = {
          'product_id': productId,
          'product_name': productName,
          'category': category,
          'current_stock': currentStock,
          'inventory_value': inventoryValue,
          'total_sold_quantity': totalSoldQuantity,
          'total_sales_value': totalSalesValue,
          'turnover_ratio': turnoverRatio,
          'days_to_sell': daysToSellInventory.isInfinite ? -1 : daysToSellInventory.round(),
          'sales_velocity': dailySalesRate,
        };
      }

      return {
        'period_days': end.difference(start).inDays,
        'total_products': turnoverData.length,
        'product_turnover': turnoverData.values.toList(),
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get inventory aging analysis
  Future<Map<String, dynamic>> getInventoryAgingAnalysis() async {
    try {
      final response = await _supabase
          .from('product_batches')
          .select('''
            id,
            batch_number,
            quantity,
            cost_price,
            received_date,
            expiry_date,
            products(name, category)
          ''')
          .gt('quantity', 0);

      final batches = response as List;
      final now = DateTime.now();

      final agingCategories = <String, Map<String, dynamic>>{
        'fresh': {'label': 'Mới (< 30 ngày)', 'batches': <Map<String, dynamic>>[], 'total_value': 0.0},
        'medium': {'label': 'Trung bình (30-90 ngày)', 'batches': <Map<String, dynamic>>[], 'total_value': 0.0},
        'old': {'label': 'Cũ (90+ ngày)', 'batches': <Map<String, dynamic>>[], 'total_value': 0.0},
        'expiring_soon': {'label': 'Sắp hết hạn (< 30 ngày)', 'batches': <Map<String, dynamic>>[], 'total_value': 0.0},
        'expired': {'label': 'Đã hết hạn', 'batches': <Map<String, dynamic>>[], 'total_value': 0.0},
      };

      for (var batch in batches) {
        final receivedDate = batch['received_date'] != null
            ? DateTime.parse(batch['received_date'] as String)
            : null;
        final expiryDate = batch['expiry_date'] != null
            ? DateTime.parse(batch['expiry_date'] as String)
            : null;
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        final costPrice = (batch['cost_price'] as num?)?.toDouble() ?? 0.0;
        final batchValue = quantity * costPrice;

        final batchData = {
          'id': batch['id'],
          'batch_number': batch['batch_number'],
          'product_name': (batch['products'] as Map?)?['name'] ?? 'N/A',
          'category': (batch['products'] as Map?)?['category'] ?? 'Khác',
          'quantity': quantity,
          'cost_price': costPrice,
          'batch_value': batchValue,
          'received_date': receivedDate,
          'expiry_date': expiryDate,
        };

        // Check if expired first
        if (expiryDate != null && expiryDate.isBefore(now)) {
          (agingCategories['expired']!['batches'] as List<Map<String, dynamic>>).add(batchData);
          agingCategories['expired']!['total_value'] =
              (agingCategories['expired']!['total_value'] as double) + batchValue;
        }
        // Check if expiring soon
        else if (expiryDate != null && expiryDate.difference(now).inDays <= 30) {
          (agingCategories['expiring_soon']!['batches'] as List<Map<String, dynamic>>).add(batchData);
          agingCategories['expiring_soon']!['total_value'] =
              (agingCategories['expiring_soon']!['total_value'] as double) + batchValue;
        }
        // Age by received date
        else if (receivedDate != null) {
          final ageInDays = now.difference(receivedDate).inDays;
          if (ageInDays < 30) {
            (agingCategories['fresh']!['batches'] as List<Map<String, dynamic>>).add(batchData);
            agingCategories['fresh']!['total_value'] =
                (agingCategories['fresh']!['total_value'] as double) + batchValue;
          } else if (ageInDays < 90) {
            (agingCategories['medium']!['batches'] as List<Map<String, dynamic>>).add(batchData);
            agingCategories['medium']!['total_value'] =
                (agingCategories['medium']!['total_value'] as double) + batchValue;
          } else {
            (agingCategories['old']!['batches'] as List<Map<String, dynamic>>).add(batchData);
            agingCategories['old']!['total_value'] =
                (agingCategories['old']!['total_value'] as double) + batchValue;
          }
        } else {
          // No received date, consider as medium age
          (agingCategories['medium']!['batches'] as List<Map<String, dynamic>>).add(batchData);
          agingCategories['medium']!['total_value'] =
              (agingCategories['medium']!['total_value'] as double) + batchValue;
        }
      }

      final totalValue = agingCategories.values.fold<double>(
        0.0,
        (sum, cat) => sum + (cat['total_value'] as double)
      );

      return {
        'total_batches': batches.length,
        'total_inventory_value': totalValue,
        'aging_categories': agingCategories,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Get stock movement analysis
  Future<Map<String, dynamic>> getStockMovementAnalysis({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    try {

      final startDateStr = start.toIso8601String().split('T')[0];
      final endDateStr = end.toIso8601String().split('T')[0];

      // Get all stock movements (sales, adjustments, received)
      final salesResponse = await _supabase
          .from('transaction_items')
          .select('''
            product_id,
            quantity,
            created_at,
            products(name, category)
          ''')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final sales = salesResponse as List;

      // Get inventory adjustments (if exists)
      // Note: This assumes you have an inventory_adjustments table
      final adjustmentsResponse = await _supabase
          .from('inventory_adjustments')
          .select('''
            product_id,
            quantity_change,
            adjustment_type,
            created_at,
            products(name, category)
          ''')
          .gte('created_at', startDateStr)
          .lte('created_at', '$endDateStr 23:59:59');

      final adjustments = adjustmentsResponse as List;

      // Get received inventory (new batches)
      final receivedResponse = await _supabase
          .from('product_batches')
          .select('''
            product_id,
            quantity,
            received_date,
            products(name, category)
          ''')
          .gte('received_date', startDateStr)
          .lte('received_date', '$endDateStr 23:59:59');

      final received = receivedResponse as List;

      // Aggregate movements by product
      final movementData = <String, Map<String, dynamic>>{};

      // Process sales (outbound)
      for (var sale in sales) {
        final productId = sale['product_id'] as String;
        final quantity = (sale['quantity'] as num?)?.toDouble() ?? 0.0;
        final product = sale['products'] as Map<String, dynamic>?;

        if (!movementData.containsKey(productId)) {
          movementData[productId] = {
            'product_id': productId,
            'product_name': product?['name'] ?? 'N/A',
            'category': product?['category'] ?? 'Khác',
            'total_out': 0.0,
            'total_in': 0.0,
            'total_adjustments': 0.0,
            'net_movement': 0.0,
          };
        }

        movementData[productId]!['total_out'] =
            (movementData[productId]!['total_out'] as double) + quantity;
      }

      // Process adjustments
      for (var adjustment in adjustments) {
        final productId = adjustment['product_id'] as String;
        final quantityChange = (adjustment['quantity_change'] as num?)?.toDouble() ?? 0.0;
        final product = adjustment['products'] as Map<String, dynamic>?;

        if (!movementData.containsKey(productId)) {
          movementData[productId] = {
            'product_id': productId,
            'product_name': product?['name'] ?? 'N/A',
            'category': product?['category'] ?? 'Khác',
            'total_out': 0.0,
            'total_in': 0.0,
            'total_adjustments': 0.0,
            'net_movement': 0.0,
          };
        }

        movementData[productId]!['total_adjustments'] =
            (movementData[productId]!['total_adjustments'] as double) + quantityChange;
      }

      // Process received inventory (inbound)
      for (var batch in received) {
        final productId = batch['product_id'] as String;
        final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
        final product = batch['products'] as Map<String, dynamic>?;

        if (!movementData.containsKey(productId)) {
          movementData[productId] = {
            'product_id': productId,
            'product_name': product?['name'] ?? 'N/A',
            'category': product?['category'] ?? 'Khác',
            'total_out': 0.0,
            'total_in': 0.0,
            'total_adjustments': 0.0,
            'net_movement': 0.0,
          };
        }

        movementData[productId]!['total_in'] =
            (movementData[productId]!['total_in'] as double) + quantity;
      }

      // Calculate net movement for each product
      for (var product in movementData.values) {
        final totalIn = product['total_in'] as double;
        final totalOut = product['total_out'] as double;
        final totalAdjustments = product['total_adjustments'] as double;
        product['net_movement'] = totalIn - totalOut + totalAdjustments;
      }

      final movements = movementData.values.toList();
      movements.sort((a, b) => (b['total_out'] as double).compareTo(a['total_out'] as double));

      return {
        'period_days': end.difference(start).inDays,
        'total_products_moved': movements.length,
        'product_movements': movements,
        'summary': {
          'total_inbound': movements.fold<double>(0.0, (sum, p) => sum + (p['total_in'] as double)),
          'total_outbound': movements.fold<double>(0.0, (sum, p) => sum + (p['total_out'] as double)),
          'total_adjustments': movements.fold<double>(0.0, (sum, p) => sum + (p['total_adjustments'] as double)),
        },
      };
    } catch (e) {
      // If inventory_adjustments table doesn't exist, return simplified analysis
      return _getSimplifiedStockMovement(start, end);
    }
  }

  /// Simplified stock movement analysis (fallback)
  Future<Map<String, dynamic>> _getSimplifiedStockMovement(DateTime start, DateTime end) async {
    final startDateStr = start.toIso8601String().split('T')[0];
    final endDateStr = end.toIso8601String().split('T')[0];

    // Only analyze sales and received inventory
    final salesResponse = await _supabase
        .from('transaction_items')
        .select('''
          product_id,
          quantity,
          products(name, category)
        ''')
        .gte('created_at', startDateStr)
        .lte('created_at', '$endDateStr 23:59:59');

    final sales = salesResponse as List;

    final receivedResponse = await _supabase
        .from('product_batches')
        .select('''
          product_id,
          quantity,
          products(name, category)
        ''')
        .gte('received_date', startDateStr)
        .lte('received_date', '$endDateStr 23:59:59');

    final received = receivedResponse as List;

    final movementData = <String, Map<String, dynamic>>{};

    // Process sales
    for (var sale in sales) {
      final productId = sale['product_id'] as String;
      final quantity = (sale['quantity'] as num?)?.toDouble() ?? 0.0;
      final product = sale['products'] as Map<String, dynamic>?;

      if (!movementData.containsKey(productId)) {
        movementData[productId] = {
          'product_id': productId,
          'product_name': product?['name'] ?? 'N/A',
          'category': product?['category'] ?? 'Khác',
          'total_out': 0.0,
          'total_in': 0.0,
          'total_adjustments': 0.0,
          'net_movement': 0.0,
        };
      }

      movementData[productId]!['total_out'] =
          (movementData[productId]!['total_out'] as double) + quantity;
    }

    // Process received
    for (var batch in received) {
      final productId = batch['product_id'] as String;
      final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0.0;
      final product = batch['products'] as Map<String, dynamic>?;

      if (!movementData.containsKey(productId)) {
        movementData[productId] = {
          'product_id': productId,
          'product_name': product?['name'] ?? 'N/A',
          'category': product?['category'] ?? 'Khác',
          'total_out': 0.0,
          'total_in': 0.0,
          'total_adjustments': 0.0,
          'net_movement': 0.0,
        };
      }

      movementData[productId]!['total_in'] =
          (movementData[productId]!['total_in'] as double) + quantity;
    }

    // Calculate net movement
    for (var product in movementData.values) {
      final totalIn = product['total_in'] as double;
      final totalOut = product['total_out'] as double;
      product['net_movement'] = totalIn - totalOut;
    }

    final movements = movementData.values.toList();
    movements.sort((a, b) => (b['total_out'] as double).compareTo(a['total_out'] as double));

    return {
      'period_days': end.difference(start).inDays,
      'total_products_moved': movements.length,
      'product_movements': movements,
      'summary': {
        'total_inbound': movements.fold<double>(0.0, (sum, p) => sum + (p['total_in'] as double)),
        'total_outbound': movements.fold<double>(0.0, (sum, p) => sum + (p['total_out'] as double)),
        'total_adjustments': 0.0,
      },
    };
  }
}
