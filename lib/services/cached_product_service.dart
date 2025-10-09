// =============================================================================
// PRODUCT SERVICE VỚI CACHE - NÂNG CẤP SERVICE CŨ
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agricultural_pos/features/products/models/product.dart';
import 'package:agricultural_pos/services/cache_manager.dart';
import 'package:agricultural_pos/shared/models/paginated_result.dart';
import 'package:agricultural_pos/shared/services/base_service.dart';

class CachedProductService extends BaseService {
  final CacheManager _cache = CacheManager();

  // Paginated với cache VÀ STORE ISOLATION
  Future<PaginatedResult<Product>> getProductsPaginated({
    ProductCategory? category,
    String? searchQuery,
    int page = 1,
    int limit = 20,
    String sortBy = 'name',
    bool ascending = true,
    bool useCache = true,
  }) async {
    // 🚨 CRITICAL: Include store_id trong cache key để tránh cross-store data leak
    final storeId = getValidStoreId();
    
    // 🔥 FIX: Create consistent cache key - always use same parameter format
    final normalizedCategory = category?.toString().split('.').last ?? 'all';
    final normalizedSearch = searchQuery?.trim() ?? '';
    final sortDirection = ascending ? 'asc' : 'desc';
    
    final cacheKey = _buildCacheKey(
      'products_paginated',
      store: storeId,
      category: normalizedCategory,
      search: normalizedSearch.isEmpty ? null : normalizedSearch,
      page: page.toString(),
      limit: limit.toString(),
      sort: '${sortBy}_$sortDirection',
    );

    print('🔍 CACHE DEBUG: Built cache key: $cacheKey');

    // Thử lấy từ cache trước
    if (useCache) {
      final cachedData = await _cache.get<Map<String, dynamic>>(
        cacheKey,
        (json) => json as Map<String, dynamic>,
      );

      if (cachedData != null) {
        print('🎯 Cache HIT: Found ${(cachedData['items'] as List).length} cached items for key: $cacheKey');
        // Reconstruct PaginatedResult from cached data
        final items = (cachedData['items'] as List)
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
        return PaginatedResult.fromSupabaseResponse(
          items: items,
          totalCount: cachedData['totalCount'] as int,
          offset: cachedData['offset'] as int,
          limit: cachedData['limit'] as int,
        );
      } else {
        print('💾 Cache MISS: No cached data found for key: $cacheKey');
      }
    } else {
      print('💾 Cache DISABLED: useCache=false for key: $cacheKey');
    }

    print('💾 Cache MISS: Fetching from DB for store: $storeId...');
    
    // Nếu cache miss thì query database WITH STORE ISOLATION
    try {
      final offset = (page - 1) * limit;
      
      print('🔍 DEBUG: Building count query for store: $storeId');
      // 🎯 CRITICAL FIX: Add store filtering to count query with error handling AND active filter
      var countQuery = addStoreFilter(
        supabase.from('products_with_details').select('id')
      ).eq('is_active', true);  // 🚨 CRITICAL: Filter out deleted products
      
      if (category != null) {
        countQuery = countQuery.eq('category', normalizedCategory);
      }
      if (normalizedSearch.isNotEmpty) {
        // 🚨 FIX: Use LIKE search for count query too
        countQuery = countQuery.or('name.ilike.%$normalizedSearch%,sku.ilike.%$normalizedSearch%,description.ilike.%$normalizedSearch%');
      }
      
      print('🔍 DEBUG: Count query after store filter built successfully');
      print('🔍 DEBUG: Executing count query...');
      final countResponse = await countQuery;
      final totalCount = countResponse.length;
      print('🔍 DEBUG: Count query result: $totalCount items');

      print('🔍 DEBUG: Building data query for store: $storeId');
      // 🎯 CRITICAL FIX: Add store filtering to data query with error handling AND active filter
      var query = addStoreFilter(
        supabase.from('products_with_details').select('*')
      ).eq('is_active', true);  // 🚨 CRITICAL: Filter out deleted products
      
      if (category != null) {
        query = query.eq('category', normalizedCategory);
      }
      
      if (normalizedSearch.isNotEmpty) {
        // 🚨 FIX: Use LIKE search instead of full-text search (no search_vector column)
        query = query.or('name.ilike.%$normalizedSearch%,sku.ilike.%$normalizedSearch%,description.ilike.%$normalizedSearch%');
      }
      
      print('🔍 DEBUG: Data query after store filter built successfully');
      print('🔍 DEBUG: Executing data query with range $offset to ${offset + limit - 1}...');
      final response = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      print('🔍 DEBUG: Data query completed, processing ${(response as List).length} items');

      // response is already List<Map<String, dynamic>> in Supabase 2.10.1
      final result = PaginatedResult.fromSupabaseResponse(
        items: (response as List).map((json) {
          final product = Product.fromJson(json as Map<String, dynamic>);
          // 🔍 DEBUG: Verify product data including price
          print('🔍 VERIFIED: Product "${product.name}" (active: ${product.isActive}) price: ${product.currentSellingPrice} store: ${product.storeId}');
          return product;
        }).toList(),
        totalCount: totalCount,
        offset: offset,
        limit: limit,
      );

      print('🔍 DEBUG: Successfully created PaginatedResult with ${result.items.length} items');

      // Cache kết quả cho lần sau (với store_id trong key)
      final cacheData = {
        'items': result.items.map((item) => item.toJson()).toList(),
        'totalCount': result.totalCount,
        'offset': offset,
        'limit': limit,
        'currentPage': result.currentPage,
        'hasNextPage': result.hasNextPage,
        'hasPreviousPage': result.hasPreviousPage,
        'totalPages': result.totalPages,
      };
      
      await _cache.set(
        cacheKey,
        cacheData,
        (data) => data,
        expiry: Duration(minutes: 3),
        persistent: false,
      );

      print('🔍 DEBUG: Cache saved successfully for key: $cacheKey');
      print('🎯 Cache SAVED: $cacheKey with ${result.items.length} items');
      return result;
    } catch (e, stackTrace) {
      print('🚨 ERROR in getProductsPaginated: $e');
      print('🚨 STACK TRACE: $stackTrace');
      throw Exception('Lỗi lấy sản phẩm: $e');
    }
  }

  // Get products by category với cache dài hạn VÀ STORE ISOLATION
  Future<List<Product>> getProductsByCategory(
    ProductCategory category, {
    bool useCache = true,
  }) async {
    final storeId = getValidStoreId();
    final cacheKey = CacheKeys.productsByCategory('${storeId}_${category.toString()}');
    
    if (useCache) {
      final cached = await _cache.get<List<Product>>(
        cacheKey,
        (json) => (json['items'] as List).map((item) => Product.fromJson(item)).toList(),
      );
      
      if (cached != null) {
        print('🎯 Category cache HIT: ${category.toString()} for store: $storeId');
        return cached;
      }
    }

    print('💾 Category cache MISS: Fetching ${category.toString()} for store: $storeId...');

    try {
      // 🎯 CRITICAL FIX: Add store filtering
      final response = await addStoreFilter(
        supabase.from('products_with_details').select('*')
      )
          .eq('category', category.toString().split('.').last)
          .eq('is_active', true)
          .order('name', ascending: true);
      
      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Cache dài hạn cho category data (với store_id trong key)
      await _cache.set(
        cacheKey,
        products,
        (data) => {'items': data.map((item) => item.toJson()).toList()},
        expiry: Duration(minutes: 15), // Cache lâu hơn vì category ít thay đổi
        persistent: true, // Persistent vì data stable
      );

      return products;
    } catch (e) {
      throw Exception('Lỗi lấy sản phẩm theo loại: $e');
    }
  }

  // Search với cache có debounce VÀ STORE ISOLATION
  Future<List<Product>> searchProducts(
    String query, {
    bool useCache = true,
    ProductCategory? category,
  }) async {
    if (query.trim().length < 2) return []; // Không search query quá ngắn
    
    final storeId = getValidStoreId();
    final cacheKey = _buildCacheKey(
      'search',
      store: storeId,
      search: query.toLowerCase().trim(),
      category: category?.toString(),
    );
    
    if (useCache) {
      final cached = await _cache.get<List<Product>>(
        cacheKey,
        (json) => (json['items'] as List).map((item) => Product.fromJson(item)).toList(),
      );
      
      if (cached != null) {
        print('🎯 Search cache HIT: $query for store: $storeId');
        return cached;
      }
    }

    print('💾 Search cache MISS: Searching "$query" for store: $storeId...');

    try {
      // 🎯 CRITICAL FIX: Add store filtering to search
      var baseQuery = addStoreFilter(
        supabase.from('products_with_details').select('*')
      )
          .or('name.ilike.%$query%,sku.ilike.%$query%,description.ilike.%$query%')
          .eq('is_active', true);

      if (category != null) {
        baseQuery = baseQuery.eq('category', category.toString().split('.').last);
      }

      var response = await baseQuery
          .order('name', ascending: true) // Simple name ordering
          .limit(50);

      var results = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Debug: Log search results for verification
      print('🔍 Search "$query" found ${results.length} products for store $storeId: ${results.take(3).map((p) => p.name).join(", ")}${results.length > 3 ? "..." : ""}');

      // Cache search results nhưng không lâu vì có thể thay đổi (với store_id trong key)
      await _cache.set(
        cacheKey,
        results,
        (data) => {'items': data.map((item) => item.toJson()).toList()},
        expiry: Duration(minutes: 2), // Cache ngắn cho search
        persistent: false,
      );

      return results;
    } catch (e) {
      throw Exception('Lỗi tìm kiếm: $e');
    }
  }

  // Dashboard stats với cache refresh định kỳ VÀ STORE ISOLATION
  Future<Map<String, dynamic>> getDashboardStats({bool useCache = true}) async {
    final storeId = getValidStoreId();
    final cacheKey = '${CacheKeys.dashboardStats}_store_$storeId';
    
    if (useCache) {
      final cached = await _cache.get<Map<String, dynamic>>(
        cacheKey,
        (json) => Map<String, dynamic>.from(json),
      );
      
      if (cached != null) {
        print('🎯 Dashboard cache HIT for store: $storeId');
        return cached;
      }
    }

    print('💾 Dashboard cache MISS: Fetching stats for store: $storeId...');

    try {
      // 🎯 CRITICAL FIX: Add store filtering to dashboard stats
      final response = await addStoreFilter(
        supabase.from('product_dashboard_stats').select('*')
      );

      final stats = <String, dynamic>{};
      
      for (final row in response as List) {
        final category = row['category'] as String;
        stats[category] = {
          'total_products': row['total_products'],
          'in_stock_products': row['in_stock_products'],
          'low_stock_count': row['low_stock_count'],
          'avg_price': row['avg_price'],
          'total_stock_value': row['total_stock_value'],
          'last_updated': row['last_updated'],
        };
      }

      // Cache lâu vì dashboard stats không thay đổi liên tục (với store_id trong key)
      await _cache.set(
        cacheKey,
        stats,
        (data) => data,
        expiry: Duration(minutes: 10),
        persistent: true, // Persistent để app khởi động nhanh
      );

      return stats;
    } catch (e) {
      throw Exception('Lỗi lấy thống kê: $e');
    }
  }

  // Low stock products với cache VÀ STORE ISOLATION
  Future<List<Map<String, dynamic>>> getLowStockProducts({bool useCache = true}) async {
    final storeId = getValidStoreId();
    final cacheKey = '${CacheKeys.lowStockProducts}_store_$storeId';
    
    if (useCache) {
      final cached = await _cache.get<List<Map<String, dynamic>>>(
        cacheKey,
        (json) => List<Map<String, dynamic>>.from(json['items']),
      );
      
      if (cached != null) {
        print('🎯 Low stock cache HIT for store: $storeId');
        return cached;
      }
    }

    try {
      // 🎯 CRITICAL FIX: Add store filtering to low stock products
      final response = await addStoreFilter(
        supabase.from('low_stock_products').select('*')
      ).order('current_stock', ascending: true);
      
      final results = List<Map<String, dynamic>>.from(response);

      await _cache.set(
        cacheKey,
        results,
        (data) => {'items': data},
        expiry: Duration(minutes: 5),
        persistent: false,
      );

      return results;
    } catch (e) {
      throw Exception('Lỗi lấy hàng sắp hết: $e');
    }
  }

  // CACHE INVALIDATION METHODS
  Future<void> invalidateProductCache({ProductCategory? category}) async {
    if (category != null) {
      await _cache.invalidate(CacheKeys.productsByCategory(category.toString()));
    } else {
      _cache.invalidatePattern('products');
    }
  }

  Future<void> invalidateSearchCache() async {
    _cache.invalidatePattern('search');
  }

  Future<void> invalidateDashboardCache() async {
    await _cache.invalidate(CacheKeys.dashboardStats);
    await _cache.invalidate(CacheKeys.lowStockProducts);
  }

  // Refresh materialized view từ app nếu cần
  Future<void> refreshMaterializedViews() async {
    try {
      await supabase.rpc('refresh_dashboard_stats');
      await invalidateDashboardCache(); // Clear cache để force refresh
    } catch (e) {
      print('Lỗi refresh materialized view: $e');
    }
  }

  // HELPER METHODS WITH STORE ISOLATION
  String _buildCacheKey(String prefix, {
    String? store,
    String? category,
    String? search,
    String? page,
    String? limit,
    String? sort,
  }) {
    final parts = [prefix];
    if (store != null) parts.add('store_$store');  // 🎯 CRITICAL: Include store in cache key
    if (category != null && category != 'null') parts.add('cat_$category');
    if (search != null && search.isNotEmpty) parts.add('search_$search');
    if (page != null) parts.add('p$page');
    if (limit != null) parts.add('l$limit');
    if (sort != null) parts.add('s$sort');
    
    final cacheKey = 'cache_${parts.join('_')}';
    print('🔍 CACHE KEY BUILT: $cacheKey');
    return cacheKey;
  }
}
