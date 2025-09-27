import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/seasonal_price.dart';
import '../models/banned_substance.dart';
import '../models/company.dart';
import '../../../shared/models/paginated_result.dart';

class ProductService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // PRODUCT CRUD OPERATIONS
  // =====================================================

  /// Lấy products với pagination (KHÔNG load tất cả một lúc)
  Future<PaginatedResult<Product>> getProductsPaginated({
    ProductCategory? category,
    PaginationParams? params,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final paginationParams = params ?? PaginationParams.first();

      // Build base query
      var query = _supabase.from('products_with_details').select('''
        id, sku, name, category, company_id, attributes, is_active, is_banned,
        image_url, description, created_at, updated_at, min_stock_level, npk_ratio,
        active_ingredient, seed_strain, current_price, available_stock,
        company_name, store_id
      ''');
      query = addStoreFilter(query);

      // Apply filters
      if (category != null) {
        query = query.eq('category', category.toString().split('.').last);
      }

      query = query.eq('is_active', true);

      // Apply sorting
      final orderField = sortBy ?? 'name';

      // Execute paginated query
      final response = await query
          .order(orderField, ascending: ascending)
          .range(paginationParams.offset, paginationParams.offset + paginationParams.pageSize - 1);

      // Get total count
      var countQuery = addStoreFilter(
        _supabase.from('products_with_details').select('id'),
      );
      if (category != null) {
        countQuery = countQuery.eq('category', category.toString().split('.').last);
      }
      countQuery = countQuery.eq('is_active', true);
      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      return PaginatedResult.fromSupabaseResponse(
        items: products,
        totalCount: totalCount,
        offset: paginationParams.offset,
        limit: paginationParams.pageSize,
      );
    } catch (e) {
      throw Exception('Lỗi lấy danh sách sản phẩm: $e');
    }
  }

  /// Legacy method cho backward compatibility
  @Deprecated('Use getProductsPaginated() instead để tránh load quá nhiều data')
  Future<List<Product>> getProducts({ProductCategory? category}) async {
    final result = await getProductsPaginated(category: category);
    return result.items;
  }

  /// Get products filtered by company (for PO creation)
  Future<List<Product>> getProductsByCompany(String? companyId) async {
    try {
      var query = _supabase.from('products_with_details').select('''
        id, sku, name, category, company_id, attributes, is_active, is_banned,
        image_url, description, created_at, updated_at, min_stock_level, npk_ratio,
        active_ingredient, seed_strain, current_price, available_stock,
        company_name, store_id
      ''');

      // Filter by company if provided
      if (companyId != null) {
        query = query.eq('company_id', companyId);
      }

      // Only active products
      query = query.eq('is_active', true);

      // Order by name for better UX
      final response = await query.order('name', ascending: true);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error loading products by company: $e');
    }
  }

  /// Tìm kiếm products với Full-Text Search + Pagination
  /// Độ phức tạp: O(log n) thay vì O(n) của ILIKE
  /// Hỗ trợ Vietnamese language và ranking theo độ liên quan
  Future<PaginatedResult<Product>> searchProductsPaginated({
    required String query,
    PaginationParams? params,
    ProductCategory? category,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
  }) async {
    try {
      // Validate query
      if (query.trim().isEmpty) {
        return PaginatedResult.empty();
      }

      final paginationParams = params ?? PaginationParams.first();

      // Build base query với full-text search
      var queryBuilder = _supabase
          .from('products_with_details')
          .select('''
            *,
            ts_rank(search_vector, plainto_tsquery('vietnamese', '$query')) as rank
          ''')
          .textSearch('search_vector', query, config: 'vietnamese')
          .eq('is_active', true);
      queryBuilder = addStoreFilter(queryBuilder);

      // Apply filters
      if (category != null) {
        queryBuilder = queryBuilder.eq('category', category.toString().split('.').last);
      }

      if (minPrice != null) {
        queryBuilder = queryBuilder.gte('current_price', minPrice);
      }

      if (maxPrice != null) {
        queryBuilder = queryBuilder.lte('current_price', maxPrice);
      }

      if (inStock == true) {
        queryBuilder = queryBuilder.gt('available_stock', 0);
      }

      // Execute paginated query
      final response = await queryBuilder
          .order('rank', ascending: false)
          .order('name', ascending: true)
          .range(paginationParams.offset, paginationParams.offset + paginationParams.pageSize - 1);

      // Get total count cho pagination
      var countQuery = addStoreFilter(_supabase
          .from('products_with_details')
          .select('id')
          .textSearch('search_vector', query, config: 'vietnamese')
          .eq('is_active', true));

      if (category != null) {
        countQuery = countQuery.eq('category', category.toString().split('.').last);
      }
      if (minPrice != null) {
        countQuery = countQuery.gte('current_price', minPrice);
      }
      if (maxPrice != null) {
        countQuery = countQuery.lte('current_price', maxPrice);
      }
      if (inStock == true) {
        countQuery = countQuery.gt('available_stock', 0);
      }

      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      return PaginatedResult.fromSupabaseResponse(
        items: products,
        totalCount: totalCount,
        offset: paginationParams.offset,
        limit: paginationParams.pageSize,
      );
    } catch (e) {
      // Fallback về basic search
      return _fallbackSearchPaginated(query, params);
    }
  }

  /// Legacy search method cho backward compatibility
  @Deprecated('Use searchProductsPaginated() instead để có pagination')
  Future<List<Product>> searchProducts(String query) async {
    final result = await searchProductsPaginated(query: query);
    return result.items;
  }

  /// Fallback search method with pagination using ILIKE
  Future<PaginatedResult<Product>> _fallbackSearchPaginated(
    String query,
    PaginationParams? params,
  ) async {
    try {
      final paginationParams = params ?? PaginationParams.first();

      final response = await addStoreFilter(_supabase
          .from('products_with_details')
          .select('*')
          .or('name.ilike.%$query%,sku.ilike.%$query%,description.ilike.%$query%')
          .eq('is_active', true))
          .order('name', ascending: true)
          .range(paginationParams.offset, paginationParams.offset + paginationParams.pageSize - 1);

      // Get total count
      final countResponse = await addStoreFilter(
        _supabase
            .from('products_with_details')
            .select('id')
            .or('name.ilike.%$query%,sku.ilike.%$query%,description.ilike.%$query%')
            .eq('is_active', true),
      );

      final totalCount = countResponse.length;

      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      return PaginatedResult.fromSupabaseResponse(
        items: products,
        totalCount: totalCount,
        offset: paginationParams.offset,
        limit: paginationParams.pageSize,
      );
    } catch (e) {
      throw Exception('Lỗi tìm kiếm sản phẩm: $e');
    }
  }

  /// Legacy fallback search method
  @Deprecated('Use _fallbackSearchPaginated() instead')
  Future<List<Product>> _fallbackSearch(String query) async {
    final result = await _fallbackSearchPaginated(query, null);
    return result.items;
  }

  /// Product Batch Operations với Pagination
  /// Lấy all batches của một product với pagination
  Future<PaginatedResult<ProductBatch>> getProductBatchesPaginated({
    required String productId,
    PaginationParams? params,
  }) async {
    try {
      final paginationParams = params ?? PaginationParams.first();

      final response = await addStoreFilter(_supabase
          .from('product_batches')
          .select('*'))
          .eq('product_id', productId)
          .eq('is_available', true)
          .gt('quantity', 0)
          .order('received_date', ascending: false) // Newest first for display
          .range(paginationParams.offset, paginationParams.offset + paginationParams.pageSize - 1);

      // Get total count
      final countResponse = await addStoreFilter(_supabase
          .from('product_batches')
          .select('id')
          .eq('product_id', productId)
          .eq('is_available', true)
          .gt('quantity', 0));

      final totalCount = countResponse.length;

      final batches = (response as List)
          .map((json) => ProductBatch.fromJson(json))
          .toList();

      return PaginatedResult.fromSupabaseResponse(
        items: batches,
        totalCount: totalCount,
        offset: paginationParams.offset,
        limit: paginationParams.pageSize,
      );
    } catch (e) {
      throw Exception('Lỗi lấy thông tin lô hàng: $e');
    }
  }

  /// Quick search cho POS screen (tìm nhanh theo tên hoặc SKU)
  /// Optimized cho tốc độ, không cần ranking phức tạp
  Future<List<Product>> quickSearchForPOS(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      // Nếu query giống SKU pattern (có thể là barcode scan), ưu tiên exact match
      if (RegExp(r'^[A-Z0-9]{4,}$').hasMatch(query.toUpperCase())) {
        final exactMatch = await scanProductBySKU(query.toUpperCase());
        if (exactMatch != null) {
          return [exactMatch];
        }
      }

      // Otherwise use full-text search với limit nhỏ cho tốc độ
      final response = await addStoreFilter(_supabase
          .from('products_with_details')
          .select('*')
          .textSearch('search_vector', query, config: 'vietnamese')
          .eq('is_active', true)
          .gt('available_stock', 0)) // Chỉ hiện sản phẩm còn hàng
          .order('ts_rank(search_vector, plainto_tsquery(\'vietnamese\', \'$query\'))', ascending: false)
          .limit(10); // Limit nhỏ cho POS

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback cho POS
      return _quickFallbackSearch(query);
    }
  }

  /// Quick fallback search for POS
  Future<List<Product>> _quickFallbackSearch(String query) async {
    try {
      final response = await addStoreFilter(_supabase
          .from('products_with_details')
          .select('*')
          .or('name.ilike.%$query%,sku.ilike.%$query%')
          .eq('is_active', true)
          .gt('available_stock', 0))
          .order('name', ascending: true)
          .limit(10);

      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi tìm kiếm nhanh: $e');
    }
  }

  /// Lấy product theo ID
  Future<Product?> getProductById(String productId) async {
    try {
      final response = await addStoreFilter(_supabase
          .from('products_with_details')
          .select('*')
          .eq('id', productId))
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
      final existingSku = await addStoreFilter(_supabase
          .from('products')
          .select('id')
          .eq('sku', product.sku))
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

      final productData = product.toJson();
      // Remove id field for INSERT since database will generate it
      productData.remove('id');

      final response = await _supabase
          .from('products')
          .insert(addStoreId(productData))
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

      ensureAuthenticated();
      final response = await _supabase
          .from('products')
          .update(product.toJson())
          .eq('id', product.id)
          .eq('store_id', currentStoreId!)
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
      ensureAuthenticated();
      await _supabase
          .from('products')
          .update({'is_active': false})
          .eq('id', productId)
          .eq('store_id', currentStoreId!);
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
      final response = await addStoreFilter(_supabase
          .from('companies')
          .select('*'))
          .eq('is_active', true)
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
      final batchData = batch.toJson();
      // Remove id field for INSERT since database will generate it
      batchData.remove('id');

      final response = await _supabase
          .from('product_batches')
          .insert(addStoreId(batchData))
          .select()
          .single();

      return ProductBatch.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi thêm lô hàng: $e');
    }
  }

  /// Cập nhật thông tin một lô hàng
  Future<ProductBatch> updateProductBatch(ProductBatch batch) async {
    try {
      ensureAuthenticated();
      final response = await _supabase
          .from('product_batches')
          .update(batch.toJson())
          .eq('id', batch.id)
          .eq('store_id', currentStoreId!)
          .select()
          .single();
      return ProductBatch.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật lô hàng: $e');
    }
  }

  /// Xóa một lô hàng (soft delete)
  Future<void> deleteProductBatch(String batchId) async {
    try {
      ensureAuthenticated();
      await _supabase
          .from('product_batches')
          .update({'is_available': false}) // Dùng soft delete
          .eq('id', batchId)
          .eq('store_id', currentStoreId!);
    } catch (e) {
      throw Exception('Lỗi xóa lô hàng: $e');
    }
  }

  

  /// Lấy available stock cho product
  Future<int> getAvailableStock(String productId) async {
    try {
      final result = await _supabase
          .rpc('get_available_stock', params: {'product_uuid': productId});

      return result as int;
    } catch (e) {
      return 0;
    }
  }

  /// Lấy danh sách lô hàng sắp hết hạn
  Future<List<Map<String, dynamic>>> getExpiringBatches({int? months}) async {
    try {
      if (months != null) {
        // Try RPC first
        try {
          final response = await _supabase.rpc('get_expiring_batches_report', params: {'p_months': months});
          return List<Map<String, dynamic>>.from(response);
        } catch (rpcError) {
          print('RPC get_expiring_batches_report failed: $rpcError');
          return await _getExpiringBatchesFallback(months);
        }
      }
      
      // Try view first, fallback to manual query
      try {
        final response = await addStoreFilter(_supabase
            .from('expiring_batches')
            .select('*'))
            .order('days_until_expiry', ascending: true);
        return List<Map<String, dynamic>>.from(response);
      } catch (viewError) {
        print('View expiring_batches not available, using fallback: $viewError');
        return await _getExpiringBatchesFallback(1); // Default 1 month
      }
    } catch (e) {
      throw Exception('Lỗi lấy danh sách hàng sắp hết hạn: $e');
    }
  }

  /// Fallback method to get expiring batches without view/RPC
  Future<List<Map<String, dynamic>>> _getExpiringBatchesFallback(int months) async {
    try {
      final futureDate = DateTime.now().add(Duration(days: months * 30));
      
      final response = await addStoreFilter(_supabase
          .from('product_batches')
          .select('*, products(name, sku)'))
          .eq('is_available', true)
          .not('expiry_date', 'is', null)
          .lte('expiry_date', futureDate.toIso8601String().split('T')[0])
          .order('expiry_date', ascending: true);
      
      return (response as List).map((batch) {
        final expiryDate = DateTime.parse(batch['expiry_date']);
        final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
        
        return {
          'id': batch['id'],
          'product_id': batch['product_id'],
          'batch_number': batch['batch_number'],
          'quantity': batch['quantity'],
          'expiry_date': batch['expiry_date'],
          'days_until_expiry': daysUntilExpiry,
          'product_name': batch['products']?['name'] ?? 'Unknown',
          'product_sku': batch['products']?['sku'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Fallback expiring batches query failed: $e');
      return [];
    }
  }

  /// Lấy danh sách sản phẩm sắp hết hàng
  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    try {
      // Try using view first, fallback to manual query if view doesn't exist
      try {
        final response = await addStoreFilter(_supabase
            .from('low_stock_products')
            .select('*'))
            .order('current_stock', ascending: true);
        return List<Map<String, dynamic>>.from(response);
      } catch (viewError) {
        // Fallback: manual query if view doesn't exist or lacks store_id
        print('View low_stock_products not available, using fallback query: $viewError');
        return await _getLowStockProductsFallback();
      }
    } catch (e) {
      throw Exception('Lỗi lấy danh sách hàng sắp hết: $e');
    }
  }

  /// Fallback method to get low stock products without view
  Future<List<Map<String, dynamic>>> _getLowStockProductsFallback() async {
    try {
      // Get products with their current stock manually
      final response = await addStoreFilter(_supabase
          .from('products_with_details')
          .select('id, name, sku, category, min_stock_level, available_stock, company_name, is_active'))
          .eq('is_active', true)
          .order('available_stock', ascending: true);
      
      // Filter products where current stock <= min_stock_level
      final products = (response as List).where((product) {
        final currentStock = product['available_stock'] ?? 0;
        final minStock = product['min_stock_level'] ?? 0;
        return currentStock <= minStock;
      }).toList();
      
      return products.map((p) => {
        'id': p['id'],
        'name': p['name'],
        'sku': p['sku'],
        'category': p['category'],
        'min_stock_level': p['min_stock_level'],
        'current_stock': p['available_stock'],
        'company_name': p['company_name'],
        'is_active': p['is_active'],
      }).toList();
    } catch (e) {
      // If even fallback fails, return empty list
      print('Fallback low stock query failed: $e');
      return [];
    }
  }

  // =====================================================
  // SEASONAL PRICE OPERATIONS
  // =====================================================

  /// Lấy giá hiện tại của product
  Future<double> getCurrentPrice(String productId) async {
    try {
      final result = await _supabase
          .rpc('get_current_price', params: {'product_uuid': productId});

      return (result ?? 0).toDouble();
    } catch (e) {
      return 0;
    }
  }

  /// Lấy tất cả seasonal prices của product
  Future<List<SeasonalPrice>> getSeasonalPrices(String productId) async {
    try {
      final response = await addStoreFilter(_supabase
          .from('seasonal_prices')
          .select('*')
          .eq('product_id', productId))
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
          .insert(addStoreId(price.toJson()))
          .select()
          .single();

      return SeasonalPrice.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi thêm giá mới: $e');
    }
  }

  /// Cập nhật seasonal price
  Future<SeasonalPrice> updateSeasonalPrice(SeasonalPrice price) async {
    try {
      ensureAuthenticated();
      final response = await _supabase
          .from('seasonal_prices')
          .update(price.toJson())
          .eq('id', price.id)
          .eq('store_id', currentStoreId!)
          .select()
          .single();

      return SeasonalPrice.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật giá: $e');
    }
  }

  /// Xóa seasonal price (soft delete)
  Future<void> deleteSeasonalPrice(String priceId) async {
    try {
      // Dùng soft delete bằng cách update isActive = false
      ensureAuthenticated();
      await _supabase
          .from('seasonal_prices')
          .update({'is_active': false})
          .eq('id', priceId)
          .eq('store_id', currentStoreId!);
    } catch (e) {
      throw Exception('Lỗi xóa giá: $e');
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
  // DASHBOARD & ANALYTICS (PRODUCT-RELATED ONLY)
  // =====================================================

  /// Lấy product-related dashboard statistics
  Future<Map<String, dynamic>> getProductDashboardStats() async {
    try {
      // Total products
     final totalProductsResponse = await addStoreFilter(
          _supabase.from('products').select('id').eq('is_active', true),
      );

      final totalProductsCount = totalProductsResponse.length;
      // Low stock count
      final lowStockProducts = await getLowStockProducts();

      // Expiring batches count
      final expiringBatches = await getExpiringBatches();

      return {
        'total_products': totalProductsCount,
        'low_stock_count': lowStockProducts.length,
        'expiring_batches_count': expiringBatches.length,
      };
    } catch (e) {
      throw Exception('Lỗi lấy thống kê sản phẩm: $e');
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
      var query = addStoreFilter(_supabase.from('products_with_details').select('*'));

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