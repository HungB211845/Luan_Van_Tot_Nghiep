import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/seasonal_price.dart';
import '../models/banned_substance.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../models/company.dart';

class ProductService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // PRODUCT CRUD OPERATIONS
  // =====================================================

  /// Lấy tất cả products với details (price, stock, company)
  Future<List<Product>> getProducts({ProductCategory? category}) async {
    try {
      var query = _supabase.from('products_with_details').select('''
        id, sku, name, category, company_id, attributes, is_active, is_banned,
        image_url, description, created_at, updated_at, npk_ratio,
        active_ingredient, seed_strain, current_price, available_stock,
        contains_banned_substance, company_name
      ''');

      if (category != null) {
        query = query.eq('category', category.toString().split('.').last);
      }

      final response = await query.order('name', ascending: true);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách sản phẩm: $e');
    }
  }

  /// Tìm kiếm products theo tên, SKU, hoặc attributes
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await _supabase
          .from('products_with_details')
          .select('*')
          .or('name.ilike.%$query%,sku.ilike.%$query%,description.ilike.%$query%')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi tìm kiếm sản phẩm: $e');
    }
  }

  /// Lấy product theo ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await _supabase
          .from('products_with_details')
          .select('*')
          .eq('id', productId)
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin sản phẩm: $e');
    }
  }

  /// Tạo product mới
  Future<Product> createProduct(Product product) async {
    try {
      // Check SKU duplicate
      final existingSku = await _supabase
          .from('products')
          .select('id')
          .eq('sku', product.sku)
          .maybeSingle();

      if (existingSku != null) {
        throw Exception('SKU "${product.sku}" đã tồn tại');
      }

      // Check banned substances for pesticides
      if (product.category == ProductCategory.PESTICIDE) {
        final isBanned = await checkBannedSubstance(
          product.pesticideAttributes?.activeIngredient ?? ''
        );
        if (isBanned) {
          throw Exception('Hoạt chất "${product.pesticideAttributes?.activeIngredient}" đã bị cấm sử dụng');
        }
      }

      final response = await _supabase
          .from('products')
          .insert(product.toJson())
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi tạo sản phẩm mới: $e');
    }
  }

  /// Cập nhật product
  Future<Product> updateProduct(Product product) async {
    try {
      // Check banned substances for pesticides
      if (product.category == ProductCategory.PESTICIDE) {
        final isBanned = await checkBannedSubstance(
          product.pesticideAttributes?.activeIngredient ?? ''
        );
        if (isBanned) {
          throw Exception('Hoạt chất "${product.pesticideAttributes?.activeIngredient}" đã bị cấm sử dụng');
        }
      }

      final response = await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .select()
          .single();

      return Product.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật sản phẩm: $e');
    }
  }

  /// Xóa product (soft delete)
  Future<void> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId);
    } catch (e) {
      throw Exception('Lỗi xóa sản phẩm: $e');
    }
  }

  /// Check if active ingredient is banned
  Future<bool> checkBannedSubstance(String activeIngredient) async {
    try {
      // Direct check since we only have ingredient name
      final bannedList = await _supabase
          .from('banned_substances')
          .select('active_ingredient_name')
          .eq('is_active', true);

      return bannedList.any((item) =>
          item['active_ingredient_name'].toString().toLowerCase() ==
          activeIngredient.toLowerCase());
    } catch (e) {
      return false; // If error, assume not banned to be safe
    }
  }

  // =====================================================
  // COMPANY OPERATIONS
  // =====================================================

  /// Lấy danh sách tất cả nhà cung cấp
  Future<List<Company>> getCompanies() async {
    try {
      final response = await _supabase
          .from('companies')
          .select('*')
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Company.fromJson(json))
          .toList();
    } catch (e) {
      // Ném ra lỗi để Provider có thể bắt và xử lý
      throw Exception('Lỗi khi tải danh sách nhà cung cấp: $e');
    }
  }

  // =====================================================
  // PRODUCT BATCH OPERATIONS (FIFO & INVENTORY)
  // =====================================================

  /// Lấy all batches của một product
  Future<List<ProductBatch>> getProductBatches(String productId) async {
    try {
      final response = await _supabase
          .from('product_batches')
          .select('*')
          .eq('product_id', productId)
          .eq('is_available', true)
          .order('received_date', ascending: true); // FIFO order

      return (response as List)
          .map((json) => ProductBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy thông tin lô hàng: $e');
    }
  }

  /// Thêm batch mới (nhập kho)
  Future<ProductBatch> addProductBatch(ProductBatch batch) async {
    try {
      final response = await _supabase
          .from('product_batches')
          .insert(batch.toJson())
          .select()
          .single();

      return ProductBatch.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi thêm lô hàng: $e');
    }
  }

  /// Update batch quantity (khi bán hàng)
  Future<void> updateBatchQuantity(String batchId, int newQuantity) async {
    try {
      await _supabase
          .from('product_batches')
          .update({'quantity': newQuantity})
          .eq('id', batchId);
    } catch (e) {
      throw Exception('Lỗi cập nhật số lượng lô hàng: $e');
    }
  }

  /// Lấy available stock cho product
  Future<int> getAvailableStock(String productId) async {
    try {
      final result = await _supabase
          .rpc('get_available_stock', params: {'product_id_param': productId});

      return result as int;
    } catch (e) {
      return 0;
    }
  }

  /// Lấy danh sách lô hàng sắp hết hạn
  Future<List<Map<String, dynamic>>> getExpiringBatches() async {
    try {
      final response = await _supabase
          .from('expiring_batches')
          .select('*')
          .order('days_until_expiry', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Lỗi lấy danh sách hàng sắp hết hạn: $e');
    }
  }

  /// Lấy danh sách sản phẩm sắp hết hàng
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      final response = await _supabase
          .from('low_stock_products')
          .select('*')
          .order('current_stock', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Lỗi lấy danh sách hàng sắp hết: $e');
    }
  }

  // =====================================================
  // SEASONAL PRICE OPERATIONS
  // =====================================================

  /// Lấy giá hiện tại của product
  Future<double> getCurrentPrice(String productId) async {
    try {
      final result = await _supabase
          .rpc('get_current_price', params: {'product_id_param': productId});

      return (result ?? 0).toDouble();
    } catch (e) {
      return 0;
    }
  }

  /// Lấy tất cả seasonal prices của product
  Future<List<SeasonalPrice>> getSeasonalPrices(String productId) async {
    try {
      final response = await _supabase
          .from('seasonal_prices')
          .select('*')
          .eq('product_id', productId)
          .order('start_date', ascending: false);

      return (response as List)
          .map((json) => SeasonalPrice.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử giá: $e');
    }
  }

  /// Thêm seasonal price mới
  Future<SeasonalPrice> addSeasonalPrice(SeasonalPrice price) async {
    try {
      // Deactivate old prices that overlap
      await _supabase
          .from('seasonal_prices')
          .update({'is_active': false})
          .eq('product_id', price.productId)
          .gte('end_date', price.startDate.toIso8601String().split('T')[0])
          .lte('start_date', price.endDate.toIso8601String().split('T')[0]);

      final response = await _supabase
          .from('seasonal_prices')
          .insert(price.toJson())
          .select()
          .single();

      return SeasonalPrice.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi thêm giá mới: $e');
    }
  }

  // =====================================================
  // BANNED SUBSTANCES OPERATIONS
  // =====================================================

  /// Lấy danh sách banned substances
  Future<List<BannedSubstance>> getBannedSubstances() async {
    try {
      final response = await _supabase
          .from('banned_substances')
          .select('*')
          .eq('is_active', true)
          .order('banned_date', ascending: false);

      return (response as List)
          .map((json) => BannedSubstance.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách chất cấm: $e');
    }
  }

  /// Thêm banned substance mới
  Future<BannedSubstance> addBannedSubstance(BannedSubstance substance) async {
    try {
      final response = await _supabase
          .from('banned_substances')
          .insert(substance.toJson())
          .select()
          .single();

      return BannedSubstance.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi thêm chất cấm: $e');
    }
  }

  // =====================================================
  // TRANSACTION OPERATIONS (POS SALES)
  // =====================================================

  /// Tạo transaction mới với items (bán hàng)
  Future<String> createTransaction({
    required String? customerId,
    required List<TransactionItem> items,
    required PaymentMethod paymentMethod,
    bool isDebt = false,
    String? notes,
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
        'is_debt': isDebt,
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
          await updateBatchQuantity(batch.id, 0);
        } else {
          // Partial use of batch
          await updateBatchQuantity(batch.id, batch.quantity - remainingToReduce);
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

  /// Generate invoice number
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
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

  // =====================================================
  // DASHBOARD & ANALYTICS
  // =====================================================

  /// Lấy dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Total products
     final totalProductsResponse = await _supabase
          .from('products')
          .select('id')
          .eq('is_active', true);

      final totalProductsCount = totalProductsResponse.length;
      // Low stock count
      final lowStockProducts = await getLowStockProducts();

      // Expiring batches count
      final expiringBatches = await getExpiringBatches();

      // Today's sales
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
        'total_products': totalProductsCount,
        'low_stock_count': lowStockProducts.length,
        'expiring_batches_count': expiringBatches.length,
        'today_revenue': todayRevenue,
        'today_transactions': todaySales.length,
      };
    } catch (e) {
      throw Exception('Lỗi lấy thống kê dashboard: $e');
    }
  }

  /// Search products by barcode/SKU for POS
  Future<Product?> scanProductBySKU(String sku) async {
    try {
      final response = await _supabase
          .from('products_with_details')
          .select('*')
          .eq('sku', sku)
          .eq('is_active', true)
          .maybeSingle();

      return response != null ? Product.fromJson(response) : null;
    } catch (e) {
      throw Exception('Lỗi quét mã sản phẩm: $e');
    }
  }

  // =====================================================
  // PRODUCT SORTING & FILTERING
  // =====================================================

  /// Lấy products với sorting và filtering
  Future<List<Product>> getProductsSorted({
    String sortBy = 'name',
    bool ascending = true,
    ProductCategory? category,
    bool? lowStock,
    bool? expiringSoon,
  }) async {
    try {
      var query = _supabase.from('products_with_details').select('*');

      // Filtering
      if (category != null) {
        query = query.eq('category', category.toString().split('.').last);
      }

      if (lowStock == true) {
        query = query.lt('available_stock', 10); // Assuming low stock threshold
      }

      // Sorting
      String orderField;
      switch (sortBy) {
        case 'name':
          orderField = 'name';
          break;
        case 'price':
          orderField = 'current_price';
          break;
        case 'stock':
          orderField = 'available_stock';
          break;
        case 'created_at':
          orderField = 'created_at';
          break;
        default:
          orderField = 'name';
      }

      final response = await query
          .eq('is_active', true)
          .order(orderField, ascending: ascending);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi sắp xếp sản phẩm: $e');
    }
  }
}