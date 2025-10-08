// =============================================================================
// PRODUCT SERVICE VỚI CACHE - NÂNG CẤP SERVICE CŨ
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agricultural_pos/features/products/models/product.dart';
import 'package:agricultural_pos/services/cache_manager.dart';
import 'package:agricultural_pos/shared/models/paginated_result.dart';

class CachedProductService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CacheManager _cache = CacheManager();

  // Paginated với cache
  Future<PaginatedResult<Product>> getProductsPaginated({
    ProductCategory? category,
    String? searchQuery,
    int page = 1,
    int limit = 20,
    String sortBy = 'name',
    bool ascending = true,
    bool useCache = true,
  }) async {
    // Tạo cache key unique cho query này
    final cacheKey = _buildCacheKey(
      'products_paginated',
      category: category?.toString(),
      search: searchQuery,
      page: page.toString(),
      limit: limit.toString(),
      sort: '${sortBy}_${ascending}',
    );

    // Thử lấy từ cache trước
    if (useCache) {
      final cachedData = await _cache.get<Map<String, dynamic>>(
        cacheKey,
        (json) => json as Map<String, dynamic>,
      );

      if (cachedData != null) {
        print('🎯 Cache HIT: $cacheKey');
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
      }
    }

    print('💾 Cache MISS: Fetching from DB...');
    
    // Nếu cache miss thì query database
    try {
      final offset = (page - 1) * limit;
      
      // Separate count query first
      var countQuery = _supabase.from('products_with_details').select('id');
      if (category != null) {
        countQuery = countQuery.eq('category', category.toString().split('.').last);
      }
      if (searchQuery?.isNotEmpty == true) {
        countQuery = countQuery.textSearch('search_vector', searchQuery!, config: 'vietnamese');
      }
      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      // Then data query
      var query = _supabase.from('products_with_details').select('*');
      
      if (category != null) {
        query = query.eq('category', category.toString().split('.').last);
      }
      
      if (searchQuery?.isNotEmpty == true) {
        query = query.textSearch('search_vector', searchQuery!, config: 'vietnamese');
      }
      
      final response = await query
          .order(sortBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      // response is already List<Map<String, dynamic>> in Supabase 2.10.1
      final result = PaginatedResult.fromSupabaseResponse(
        items: (response as List).map((json) => Product.fromJson(json as Map<String, dynamic>)).toList(),
        totalCount: totalCount,
        offset: offset,
        limit: limit,
      );

      // Cache kết quả cho lần sau
      await _cache.set(
        cacheKey,
        {
          'items': result.items.map((item) => item.toJson()).toList(),
          'totalCount': result.totalCount,
          'offset': offset,
          'limit': limit,
          'currentPage': result.currentPage,
          'hasNextPage': result.hasNextPage,
          'hasPreviousPage': result.hasPreviousPage,
          'totalPages': result.totalPages,
        },
        (data) => data,
        expiry: Duration(minutes: 3),
        persistent: false,
      );

      return result;
    } catch (e) {
      throw Exception('Lỗi lấy sản phẩm: $e');
    }
  }

  // Get products by category với cache dài hạn
  Future<List<Product>> getProductsByCategory(
    ProductCategory category, {
    bool useCache = true,
  }) async {
    final cacheKey = CacheKeys.productsByCategory(category.toString());
    
    if (useCache) {
      final cached = await _cache.get<List<Product>>(
        cacheKey,
        (json) => (json['items'] as List).map((item) => Product.fromJson(item)).toList(),
      );
      
      if (cached != null) {
        print('🎯 Category cache HIT: ${category.toString()}');
        return cached;
      }
    }

    print('💾 Category cache MISS: Fetching ${category.toString()}...');

    try {
      final response = await _supabase
          .from('products_with_details')
          .select('*')
          .eq('category', category.toString().split('.').last)
          .eq('is_active', true)
          .order('name', ascending: true);
      
      final products = (response as List)
          .map((json) => Product.fromJson(json))
          .toList();

      // Cache dài hạn cho category data
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

  // Search với cache có debounce
  Future<List<Product>> searchProducts(
    String query, {
    bool useCache = true,
    ProductCategory? category,
  }) async {
    if (query.trim().length < 2) return []; // Không search query quá ngắn
    
    final cacheKey = _buildCacheKey(
      'search',
      search: query.toLowerCase().trim(),
      category: category?.toString(),
    );
    
    if (useCache) {
      final cached = await _cache.get<List<Product>>(
        cacheKey,
        (json) => (json['items'] as List).map((item) => Product.fromJson(item)).toList(),
      );
      
      if (cached != null) {
        print('🎯 Search cache HIT: $query');
        return cached;
      }
    }

    print('💾 Search cache MISS: Searching "$query"...');

    try {
      // Use LIKE-based search instead of full-text search (no search_vector column)
      var baseQuery = _supabase
          .from('products_with_details')
          .select('*')
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
      print('🔍 Search "$query" found ${results.length} products: ${results.take(3).map((p) => p.name).join(", ")}${results.length > 3 ? "..." : ""}');

      // Cache search results nhưng không lâu vì có thể thay đổi
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

  // Dashboard stats với cache refresh định kỳ
  Future<Map<String, dynamic>> getDashboardStats({bool useCache = true}) async {
    const cacheKey = CacheKeys.dashboardStats;
    
    if (useCache) {
      final cached = await _cache.get<Map<String, dynamic>>(
        cacheKey,
        (json) => Map<String, dynamic>.from(json),
      );
      
      if (cached != null) {
        print('🎯 Dashboard cache HIT');
        return cached;
      }
    }

    print('💾 Dashboard cache MISS: Fetching stats...');

    try {
      // Dùng materialized view để lấy stats nhanh
      final response = await _supabase
          .from('product_dashboard_stats')
          .select('*');

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

      // Cache lâu vì dashboard stats không thay đổi liên tục
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

  // Low stock products với cache
  Future<List<Map<String, dynamic>>> getLowStockProducts({bool useCache = true}) async {
    const cacheKey = CacheKeys.lowStockProducts;
    
    if (useCache) {
      final cached = await _cache.get<List<Map<String, dynamic>>>(
        cacheKey,
        (json) => List<Map<String, dynamic>>.from(json['items']),
      );
      
      if (cached != null) {
        print('🎯 Low stock cache HIT');
        return cached;
      }
    }

    try {
      final response = await _supabase
          .from('low_stock_products')
          .select('*')
          .order('current_stock', ascending: true);
      
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
      await _supabase.rpc('refresh_dashboard_stats');
      await invalidateDashboardCache(); // Clear cache để force refresh
    } catch (e) {
      print('Lỗi refresh materialized view: $e');
    }
  }

  // HELPER METHODS
  String _buildCacheKey(String prefix, {
    String? category,
    String? search,
    String? page,
    String? limit,
    String? sort,
  }) {
    final parts = [prefix];
    if (category != null) parts.add(category);
    if (search != null) parts.add(search);
    if (page != null) parts.add('p$page');
    if (limit != null) parts.add('l$limit');
    if (sort != null) parts.add('s$sort');
    
    return 'cache_${parts.join('_')}';
  }
}
