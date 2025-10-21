import '../../pos/services/transaction_service.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/seasonal_price.dart';
import '../models/banned_substance.dart';
import '../models/product_unit.dart'; // Multi-UoM support
import '../widgets/price_history_widget.dart';
import '../../pos/models/transaction.dart';
import '../../pos/models/transaction_item.dart';
import '../../pos/models/transaction_item_details.dart';
import '../../pos/models/payment_method.dart';
import '../services/product_service.dart';
import '../services/product_unit_service.dart'; // Multi-UoM support
import '../utils/unit_display_formatter.dart';
import '../../../shared/models/paginated_result.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/providers/memory_managed_provider.dart';
import '../../../services/cache_manager.dart';
import '../../../services/cached_product_service.dart';
import '../../../core/config/cache_config.dart';

import '../models/bulk_product_entry.dart';


enum ProductStatus { idle, loading, success, error }

class ProductProvider extends ChangeNotifier with MemoryManagedProvider {
  final ProductService _productService = ProductService();
  final CachedProductService _cachedService = CachedProductService();
  final TransactionService _transactionService = TransactionService();
  final ProductUnitService _unitService = ProductUnitService(); // Multi-UoM support

  // =====================================================
  // STATE VARIABLES
  // =====================================================

  // Products with memory management
  List<Product> _products = [];
  final Map<String, List<ProductUnit>> _unitCache = {};
  final Map<ProductCategory?, List<Product>> _productsByCategory = {};
  List<Product> _filteredProducts = [];
  Product? _selectedProduct;
  ProductCategory? _selectedCategory;
  String _searchQuery = '';

  // Constructor
  ProductProvider() {
    initializeMemoryManagement();
  }

  // Pagination state
  PaginatedResult<Product>? _paginatedProducts;
  bool _isLoadingMore = false;
  PaginationParams _currentPaginationParams = const PaginationParams();

  // Batch pagination state
  PaginatedResult<ProductBatch>? _paginatedBatches;
  bool _isBatchesLoadingMore = false;
  PaginationParams _currentBatchPaginationParams = const PaginationParams();

  // Batches & Inventory
  List<ProductBatch> _productBatches = [];
  Map<String, int> _stockMap = {}; // productId -> available stock
  List<Map<String, dynamic>> _expiringBatches = [];
  List<Map<String, dynamic>> _lowStockProducts = [];

  // Pricing
  List<SeasonalPrice> _seasonalPrices = [];
  Map<String, double> _currentPrices = {}; // productId -> current price

  // Price sync control removed - now using direct database sync via migration

  // Banned Substances
  List<BannedSubstance> _bannedSubstances = [];

  // Price sync control flag to ensure one-time sync only
  bool _hasPerformedInitialPriceSync = false;
  
  // Shopping Cart (for POS)
  List<CartItem> _cartItems = [];
  double _cartTotal = 0.0;

  // Status & Error
  ProductStatus _status = ProductStatus.idle;
  String _errorMessage = '';

  // Dashboard stats
  Map<String, dynamic> _dashboardStats = {};

  // === THÊM 2 DÒNG NÀY VÀO ===
  Transaction? _activeTransaction;
  List<TransactionItemDetails> _activeTransactionItems = [];
  // ============================

  // =====================================================
  // GETTERS
  // =====================================================

  List<Product> get products {
    return getProductsForCategory(_selectedCategory);
  }

  Product? get selectedProduct => _selectedProduct;
  ProductCategory? get selectedCategory => _selectedCategory;

  void resetSelectedCategory() {
    _selectedCategory = null;
    notifyListeners();
  }

  List<Product> getProductsForCategory(ProductCategory? category) {
    if (_searchQuery.isNotEmpty && _searchQuery.length >= 2) {
      final results = List<Product>.from(_filteredProducts);
      if (category == null) return results;
      return results.where((product) => product.category == category).toList();
    }

    if (category == null) {
      final baseList = _productsByCategory[null] ?? _products;
      return List<Product>.from(baseList);
    }

    if (_productsByCategory.containsKey(category)) {
      return List<Product>.from(_productsByCategory[category]!);
    }

    final allProducts = _productsByCategory[null] ?? _products;
    return allProducts.where((product) => product.category == category).toList();
  }
  List<ProductBatch> get productBatches => _productBatches;
  List<SeasonalPrice> get seasonalPrices => _seasonalPrices;
  List<BannedSubstance> get bannedSubstances => _bannedSubstances;

  // Cart getters
  List<CartItem> get cartItems => _cartItems;
  double get cartTotal => _cartTotal;
  int get cartItemsCount =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  // Alerts
  List<Map<String, dynamic>> get expiringBatches => _expiringBatches;
  List<Map<String, dynamic>> get lowStockProducts => _lowStockProducts;

  // Status
  ProductStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == ProductStatus.loading;
  bool get hasError => _status == ProductStatus.error;

  // Search state
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.isNotEmpty;

  // Dashboard
  Map<String, dynamic> get dashboardStats => _dashboardStats;

  // === THÊM 2 DÒNG NÀY VÀO ===
  Transaction? get activeTransaction => _activeTransaction;
  List<TransactionItemDetails> get activeTransactionItems =>
      _activeTransactionItems;
  // ============================

  // Pagination getters
  PaginatedResult<Product>? get paginatedProducts => _paginatedProducts;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreProducts => _paginatedProducts?.hasNextPage ?? false;
  PaginationParams get currentPaginationParams => _currentPaginationParams;

  // Batch pagination getters
  PaginatedResult<ProductBatch>? get paginatedBatches => _paginatedBatches;
  bool get isBatchesLoadingMore => _isBatchesLoadingMore;
  bool get hasMoreBatches => _paginatedBatches?.hasNextPage ?? false;
  PaginationParams get currentBatchPaginationParams =>
      _currentBatchPaginationParams;

  // Utility getters
  int getProductStock(String productId) => _stockMap[productId] ?? 0;
  double getCurrentPrice(String productId) => _currentPrices[productId] ?? 0.0;

  // =====================================================
  // PRODUCT OPERATIONS - PAGINATED (RECOMMENDED)
  // =====================================================

  /// Load products with pagination (recommended approach)
  Future<void> loadProductsPaginated({
    ProductCategory? category,
    int pageSize = 20,
    String? sortBy,
    bool ascending = true,
    bool useCache = true, // 🔥 CRITICAL FIX: Default to true to prevent infinite loops
  }) async {
    // 🔥 CRITICAL: Prevent overlapping calls
    if (_status == ProductStatus.loading) {
      print('⚠️ Already loading products, skipping...');
      return;
    }

    _setStatus(ProductStatus.loading);
    try {
      _currentPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      // 🎯 FIXED: Always use cache by default to prevent DB hammering
      _paginatedProducts = await _cachedService.getProductsPaginated(
        category: category,
        page: 1,
        limit: pageSize,
        sortBy: sortBy ?? 'name',
        ascending: ascending,
        useCache: useCache, // Use the parameter value
      );

      final items = List<Product>.from(_paginatedProducts!.items);
      _productsByCategory[category] = items;

      if (category == null) {
        _products = items;
      }

      _selectedCategory = category;

      await _performOneTimePriceSyncIfNeeded();

      // Clear old search state
      _filteredProducts = [];
      _searchQuery = '';

      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (!hasMoreProducts || _isLoadingMore || _paginatedProducts == null)
      return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextParams = _currentPaginationParams.nextPage();
      
      // 🎯 FIXED: Use cached service for pagination
      final nextPage = await _cachedService.getProductsPaginated(
        category: _selectedCategory,
        page: nextParams.page,
        limit: nextParams.pageSize,
        sortBy: nextParams.sortBy ?? 'name',
        ascending: nextParams.ascending,
        useCache: true,
      );

      // Merge results
      _paginatedProducts = _paginatedProducts!.merge(nextPage);
      _currentPaginationParams = nextParams;

      // Update legacy _products list
      _products = _paginatedProducts!.items;

      // 🔥 NO AUTO PRICE SYNC - use existing prices from database
      for (final product in nextPage.items) {
        _stockMap[product.id] = product.availableStock ?? 0;
        _currentPrices[product.id] = product.currentSellingPrice;
      }

      _isLoadingMore = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  /// Search products with pagination
  Future<void> searchProductsPaginated({
    required String query,
    ProductCategory? category,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int pageSize = 20,
    String? sortBy,
    bool ascending = true,
    bool useCache = true,
  }) async {
    _searchQuery = query.trim();

    // 🔥 ARCHITECTURAL FIX: Clear search properly without touching _paginatedProducts
    if (_searchQuery.isEmpty) {
      // Just clear the search results, NEVER touch _paginatedProducts
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    // 🔥 UX FIX: Don't search for queries < 2 chars, but set the query for UI state
    if (_searchQuery.length < 2) {
      // Clear search results but keep the query for UI state
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setStatus(ProductStatus.loading);
    try {
      // 🎯 FIXED: Use cached service for search
      final searchResults = await _cachedService.searchProducts(
        _searchQuery,
        useCache: useCache,
        category: category,
      );

      // 🚨 CRITICAL FIX: NEVER overwrite _paginatedProducts during search
      // Only update _filteredProducts - this maintains state separation
      _filteredProducts = searchResults;

      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load more search results
  Future<void> loadMoreSearchResults({
    required String query,
    ProductCategory? category,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
  }) async {
    if (!hasMoreProducts || _isLoadingMore || _paginatedProducts == null)
      return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // 🎯 FIXED: For search results, we don't need pagination since CachedProductService
      // returns all results at once. Just mark as complete.
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  // =====================================================
  // PRODUCT OPERATIONS - LEGACY (DEPRECATED)
  // =====================================================

  @deprecated
  Future<void> loadProducts({ProductCategory? category}) async {
    if (isLoading) return; // Prevent overlapping calls
    _setStatusSilent(ProductStatus.loading); // Use silent set
    try {
      // 1. Lấy danh sách sản phẩm (đã có sẵn stock và price từ view)
      _products = await _productService.getProducts(category: category);
      _selectedCategory = category;

      // 2. ONE-TIME price sync when loading products
      await _performOneTimePriceSyncIfNeeded();

      // 3. Xóa bộ lọc cũ (nếu có)
      _filteredProducts = [];
      _searchQuery = '';

      _setStatus(ProductStatus.success); // Notify UI only when all data is ready
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Search products with cache support (used by ProductListScreen)
  Future<void> searchProducts(String query, {bool useCache = true}) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setStatus(ProductStatus.loading);
    final stopwatch = Stopwatch()..start();

    try {
      if (useCache && CacheConfig.enableSearchCache) {
        _filteredProducts = await _cachedService.searchProducts(
          _searchQuery,
          useCache: true,
        );
        if (CacheConfig.enablePerformanceLogging) {
          stopwatch.stop();
          final ms = stopwatch.elapsedMilliseconds;
          print('🎯 Cached product search took: ${ms}ms');
          CacheMetrics.recordHit();
          CacheMetrics.recordOperationTime('search', ms);
        }
      } else {
        _filteredProducts = await _productService.searchProducts(_searchQuery);
        if (CacheConfig.enablePerformanceLogging) {
          stopwatch.stop();
          final ms = stopwatch.elapsedMilliseconds;
          print('💾 Direct product search took: ${ms}ms');
          CacheMetrics.recordMiss();
          CacheMetrics.recordOperationTime('search_direct', ms);
        }
      }
      
      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      // 🚨 CRITICAL FIX: Don't fallback to non-store-filtered old service!
      // This was causing cross-store data leakage
      print('🚨 ERROR in searchProducts: $e');
      _setError(e.toString());
      CacheMetrics.recordMiss();
    }
  }

  /// Clear search results and reset to show all products
  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    // 🔥 CRITICAL FIX: Don't reset paginated products to avoid triggering reload
    // Just clear search state and let UI show existing products
    notifyListeners();
  }

  /// Quick search cho POS screen
  List<Product> _posSearchResults = [];
  List<Product> get posSearchResults => _posSearchResults;
  bool get hasPosSearchResults => _posSearchResults.isNotEmpty;

  /// Quick search for POS with cache support (HIGH PERFORMANCE IMPACT)
  Future<void> quickSearchForPOS(String query, {bool useCache = true}) async {
    if (query.trim().isEmpty) {
      _posSearchResults = [];
      notifyListeners();
      return;
    }

    // 🔥 UX FIX: Don't search for queries < 2 chars to match other search methods
    if (query.trim().length < 2) {
      _posSearchResults = [];
      notifyListeners();
      return;
    }

    // Performance logging
    final stopwatch = Stopwatch()..start();
    
    try {
      if (useCache && CacheConfig.enableSearchCache) {
        // 🎯 FIXED: Use cached service with proper cache invalidation
        final results = await _cachedService.searchProducts(
          query.trim(),
          useCache: true,
        );
        
        // 🚨 CRITICAL: Filter out inactive products and products with 0 stock for POS
        _posSearchResults = results.where((product) => 
          product.isActive && 
          product.availableStock != null && 
          product.availableStock! > 0
        ).toList();
        
        if (CacheConfig.enablePerformanceLogging) {
          stopwatch.stop();
          final ms = stopwatch.elapsedMilliseconds;
          print('🎯 Cached POS search took: ${ms}ms, found ${_posSearchResults.length} active products');
          CacheMetrics.recordHit();
          CacheMetrics.recordOperationTime('pos_search', ms);
        }
      } else {
        _posSearchResults = await _productService.quickSearchForPOS(query.trim());
        if (CacheConfig.enablePerformanceLogging) {
          stopwatch.stop();
          final ms = stopwatch.elapsedMilliseconds;
          print('💾 Direct POS search took: ${ms}ms');
          CacheMetrics.recordMiss();
          CacheMetrics.recordOperationTime('pos_search_direct', ms);
        }
      }
      
      notifyListeners();
    } catch (e) {
      // 🚨 CRITICAL FIX: Don't fallback to non-store-filtered old service!
      // This was causing cross-store data leakage
      _posSearchResults = [];
      _setError('Lỗi tìm kiếm: ${e.toString()}');
      print('🚨 ERROR in quickSearchForPOS: $e');
      CacheMetrics.recordMiss();
    }
  }

  /// Load products filtered by company (for PO creation and supplier-specific operations)
  Future<void> loadProductsByCompany(
    String? companyId, {
    ProductCategory? category,
  }) async {
    _setStatus(ProductStatus.loading);
    try {
      // FIXED: Use ProductService method to get products by company
      _products = await _productService.getProductsByCompany(companyId);
      _selectedCategory = category;

      // Filter by category if specified
      if (category != null) {
        _products = _products
            .where((product) => product.category == category)
            .toList();
      }

      // ONE-TIME price sync for products by company
      await _performOneTimePriceSyncIfNeeded();

      // Clear old search state
      _filteredProducts = [];
      _searchQuery = '';

      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  List<Product> get posSearchResultsList => _posSearchResults;

  /// Clear search results
  void clearSearchResults() {
    _posSearchResults = [];
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  Future<Product?> addProduct(Product product) async {
    _setStatus(ProductStatus.loading);

    try {
      final newProduct = await _productService.createProduct(product);
      _products.add(newProduct);

      // Invalidate cache after product creation
      await invalidateSearchCache();
      await invalidateDashboardCache();

      // Reload all products to get updated data
      await loadProducts();

      _setStatus(ProductStatus.success);
      _clearError();
      return newProduct;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<Map<String, int>> addBulkProducts(List<ProductEntryData> entries, String companyId) async {
    _setStatus(ProductStatus.loading);
    int successCount = 0;
    int errorCount = 0;

    for (final entry in entries) {
      try {
        // 1. Create the Product with a default price of 0
        final product = Product(
          id: '',
          name: entry.name,
          category: entry.category,
          companyId: companyId,
          storeId: '', // Will be set by service
          baseUnit: entry.category == ProductCategory.PESTICIDE ? entry.pesticideBaseUnit : 'kg',
          currentSellingPrice: 0.0, // Create with 0 price first
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          attributes: {},
        );

        final createdProduct = await _productService.createProduct(product);
        final now = DateTime.now();
        final storeId = createdProduct.storeId;

        // 2. If a price was provided, update it properly to create a price history record
        if (entry.price != null && entry.price! > 0) {
          await _productService.updateCurrentSellingPrice(
            createdProduct.id,
            entry.price!,
            reason: 'Initial price on bulk add',
          );
        }

        // 3. Create UOMs based on category
        switch (entry.category) {
          case ProductCategory.FERTILIZER:
          case ProductCategory.SEED:
            await _unitService.createProductUnit(ProductUnit(
              id: '', productId: createdProduct.id, unitName: 'kg', conversionFactor: 1, unitPrice: 0, storeId: storeId, createdAt: now, updatedAt: now
            ));
            await _unitService.createProductUnit(ProductUnit(
              id: '', productId: createdProduct.id, unitName: 'Bao', conversionFactor: 50, unitPrice: 0, isDefaultSellingUnit: true, storeId: storeId, createdAt: now, updatedAt: now
            ));
            break;
          case ProductCategory.PESTICIDE:
            final config = packagingDefaults[entry.pesticidePackagingType]!;
            final volume = entry.pesticideVolume ?? (entry.pesticideBaseUnit == 'ml' ? 500.0 : 50.0);
            final quantity = entry.pesticideQuantityPerBox ?? (entry.pesticideBaseUnit == 'ml' ? 20 : 100);
            final baseUnit = entry.pesticideBaseUnit;
            
            final retailUnitName = '${config.displayName} ${volume.toStringAsFixed(0)}$baseUnit';
            final boxConversionFactor = volume * quantity;

            await _unitService.createProductUnit(ProductUnit(
              id: '', productId: createdProduct.id, unitName: baseUnit, conversionFactor: 1, unitPrice: 0, storeId: storeId, createdAt: now, updatedAt: now
            ));
            await _unitService.createProductUnit(ProductUnit(
              id: '', productId: createdProduct.id, unitName: retailUnitName, conversionFactor: volume, unitPrice: 0, isDefaultSellingUnit: true, storeId: storeId, createdAt: now, updatedAt: now
            ));
            await _unitService.createProductUnit(ProductUnit(
              id: '', productId: createdProduct.id, unitName: 'Thùng', conversionFactor: boxConversionFactor, unitPrice: 0, storeId: storeId, createdAt: now, updatedAt: now
            ));
            break;
        }
        successCount++;
      } catch (e) {
        debugPrint('Failed to create bulk product "${entry.name}": $e');
        errorCount++;
      }
    }

    await invalidateCache();
    await loadProductsPaginated(); 

    _setStatus(ProductStatus.success);
    return {'success': successCount, 'error': errorCount};
  }

  Future<bool> updateProduct(Product product) async {
    _setStatus(ProductStatus.loading);

    try {
      // Service call now returns the fully updated product from the DB
      // The RPC called by the service has already recalculated all unit prices atomically
      final updatedProduct = await _productService.updateProduct(product);

      // Invalidate cache to force reload of fresh data on next access
      await invalidateSearchCache();
      await invalidateDashboardCache();

      // Update product in the main list
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      // Update selected product if it's the same one being edited
      if (_selectedProduct?.id == product.id) {
        _selectedProduct = updatedProduct;
      }

      _setStatus(ProductStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _setStatus(ProductStatus.loading);

    try {
      await _productService.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);

      if (_selectedProduct?.id == productId) {
        _selectedProduct = null;
      }

      _setStatus(ProductStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void selectProduct(Product? product) {
    _selectedProduct = product;
    notifyListeners();
  }

  Future<void> filterByCategory(
    ProductCategory? category, {
    bool persistSelection = true,
  }) async {
    final previousCategory = _selectedCategory;
    await loadProductsPaginated(category: category, useCache: true);
    if (!persistSelection) {
      _selectedCategory = previousCategory;
      notifyListeners();
    }
  }

  // =====================================================
  // INVENTORY & BATCH OPERATIONS - PAGINATED
  // =====================================================

  /// Load product batches with pagination
  Future<void> loadProductBatchesPaginated({
    required String productId,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false, // Default: newest first
  }) async {
    _setStatus(ProductStatus.loading);
    try {
      _currentBatchPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      _paginatedBatches = await _productService.getProductBatchesPaginated(
        productId: productId,
        params: _currentBatchPaginationParams,
      );

      // Update legacy _productBatches list for backward compatibility
      _productBatches = _paginatedBatches!.items;

      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load more batches (pagination)
  Future<void> loadMoreBatches(String productId) async {
    if (!hasMoreBatches || _isBatchesLoadingMore || _paginatedBatches == null)
      return;

    _isBatchesLoadingMore = true;
    notifyListeners();

    try {
      final nextParams = _currentBatchPaginationParams.nextPage();
      final nextPage = await _productService.getProductBatchesPaginated(
        productId: productId,
        params: nextParams,
      );

      // Merge results
      _paginatedBatches = _paginatedBatches!.merge(nextPage);
      _currentBatchPaginationParams = nextParams;

      // Update legacy _productBatches list
      _productBatches = _paginatedBatches!.items;

      _isBatchesLoadingMore = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _isBatchesLoadingMore = false;
      _setError(e.toString());
    }
  }

  // =====================================================
  // INVENTORY & BATCH OPERATIONS - LEGACY
  // =====================================================

  @deprecated
  Future<void> loadProductBatches(String productId) async {
    if (isLoading) return; // Prevent overlapping calls
    _setStatusSilent(ProductStatus.loading); // Use silent set
    try {
      _productBatches = await _productService.getProductBatches(productId);
      _setStatus(ProductStatus.success); // Notify UI only when all data is ready
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> addProductBatch(ProductBatch batch) async {
    try {
      final newBatch = await _productService.addProductBatch(batch);
      _productBatches.add(newBatch);

      // Update stock for this product
      await _updateProductStock(batch.productId);

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateProductBatch(ProductBatch batch) async {
    _setStatus(ProductStatus.loading);
    try {
      final updatedBatch = await _productService.updateProductBatch(batch);
      final index = _productBatches.indexWhere((b) => b.id == batch.id);
      if (index != -1) {
        _productBatches[index] = updatedBatch;
      }
      await _updateProductStock(batch.productId); // Cập nhật lại tồn kho
      _setStatus(ProductStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Refresh inventory after goods receipt from PO
  Future<void> refreshInventoryAfterGoodsReceipt(
    List<String> productIds,
  ) async {
    try {
      // Refresh stock for affected products
      for (final productId in productIds) {
        await _updateProductStock(productId);
      }

      // Refresh current product batches if viewing a specific product
      if (_selectedProduct != null &&
          productIds.contains(_selectedProduct!.id)) {
        await loadProductBatches(_selectedProduct!.id);
      }

      // Refresh paginated batches if loaded with a specific product
      if (_paginatedBatches != null &&
          _selectedProduct != null &&
          productIds.contains(_selectedProduct!.id)) {
        await loadProductBatchesPaginated(
          productId: _selectedProduct!.id,
          pageSize: 20,
        );
      }

      // Refresh expiring batches report if it was loaded
      if (_expiringBatches.isNotEmpty) {
        await loadExpiringBatchesReport();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing inventory after goods receipt: $e');
    }
  }

  // Refresh all inventory data
  Future<void> refreshAllInventoryData() async {
    try {
      _setStatus(ProductStatus.loading);

      // Reload stock map for all products
      final products = _products.isNotEmpty
          ? _products
          : await _productService.getProducts();
      for (final product in products) {
        await _updateProductStock(product.id);
      }

      // Refresh expiring batches report if it was loaded
      if (_expiringBatches.isNotEmpty) {
        await loadExpiringBatchesReport();
      }

      _setStatus(ProductStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> deleteProductBatch(String batchId, String productId) async {
    _setStatus(ProductStatus.loading);
    try {
      await _productService.deleteProductBatch(batchId);
      _productBatches.removeWhere((b) => b.id == batchId);
      await _updateProductStock(productId); // Cập nhật lại tồn kho
      _setStatus(ProductStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> loadAlerts() async {
    try {
      _expiringBatches = await _productService.getExpiringBatches();
      // TEMPORARY FIX: Skip low stock products to avoid view error
      // _lowStockProducts = await _productService.getLowStockProducts();
      _lowStockProducts = []; // Empty list for now
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadExpiringBatchesReport({int months = 1}) async {
    _setStatus(ProductStatus.loading);
    try {
      _expiringBatches = await _productService.getExpiringBatches(
        months: months,
      );
      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // =====================================================
  // PRICING OPERATIONS
  // =====================================================

  Future<void> loadSeasonalPrices(String productId) async {
    _setStatus(ProductStatus.loading);
    try {
      _seasonalPrices = await _productService.getSeasonalPrices(productId);
      notifyListeners();
      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> addSeasonalPrice(SeasonalPrice price) async {
    try {
      final newPrice = await _productService.addSeasonalPrice(price);
      _seasonalPrices.insert(0, newPrice);

      // Update current price map
      _currentPrices[price.productId] = newPrice.sellingPrice;

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateSeasonalPrice(SeasonalPrice price) async {
    _setStatus(ProductStatus.loading);
    try {
      final updatedPrice = await _productService.updateSeasonalPrice(price);
      final index = _seasonalPrices.indexWhere((p) => p.id == price.id);
      if (index != -1) {
        _seasonalPrices[index] = updatedPrice;
      }

      // Update current price map if this is the active price
      if (updatedPrice.isActive && updatedPrice.isCurrentlyActive) {
        _currentPrices[price.productId] = updatedPrice.sellingPrice;
      }

      _setStatus(ProductStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteSeasonalPrice(String priceId, String productId) async {
    _setStatus(ProductStatus.loading);
    try {
      await _productService.deleteSeasonalPrice(priceId);
      _seasonalPrices.removeWhere((p) => p.id == priceId);

      // FIXED: Get current price from products.current_selling_price
      final product = _products.firstWhere((p) => p.id == productId);
      _currentPrices[productId] = product.currentSellingPrice;

      _setStatus(ProductStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // =====================================================
  // SHOPPING CART OPERATIONS (POS)
  // =====================================================

  // Multi-UoM: async method to support unit selection
  Future<void> addToCart(Product product, int quantity, {double? customPrice, ProductUnit? selectedUnit}) async {
    // 🔥 ENHANCED: Calculate unit-specific price by loading all units if needed
    double price;
    if (customPrice != null) {
      price = customPrice;
    } else if (selectedUnit != null && selectedUnit.unitPrice > 0) {
      // Use database price if available
      price = selectedUnit.unitPrice;
    } else {
      // Calculate price on-the-fly
      final productPrice = product.currentSellingPrice;
      if (productPrice <= 0) {
        price = getCurrentPrice(product.id); // Fallback
      } else if (selectedUnit == null) {
        price = productPrice; // No unit specified
      } else {
        // Load all units to find default unit's conversion factor
        try {
          final allUnits = await getProductUnits(product.id);
          final defaultUnit = allUnits.firstWhere(
            (u) => u.isDefaultSellingUnit,
            orElse: () => allUnits.isNotEmpty ? allUnits.first : selectedUnit,
          );
          
          if (selectedUnit.id == defaultUnit.id) {
            // This IS the default unit → full product price
            price = productPrice; // 660K ✅
          } else {
            // This is NOT default unit → calculate from default unit's conversion factor
            price = productPrice / defaultUnit.conversionFactor; // 660K ÷ 50 = 13.2K ✅
          }
        } catch (e) {
          // Fallback if loading units fails
          debugPrint('Error loading units for price calculation: $e');
          price = productPrice; // Use product price as fallback
        }
      }
    }

    if (price <= 0) {
      _setError('Sản phẩm chưa có giá bán');
      return;
    }

    // CRITICAL FIX: Load unit cụ thể, KHÔNG BAO GIỜ dùng "đơn vị" generic
    debugPrint('🔍 [addToCart] Product: ${product.name} (${product.id})');
    debugPrint('🔍 [addToCart] selectedUnit: ${selectedUnit?.unitName ?? "NULL"}');

    ProductUnit? unit = selectedUnit;
    if (unit == null) {
      // Try loading default unit first
      debugPrint('🔍 [addToCart] Loading default unit...');
      unit = await _unitService.getDefaultUnit(product.id);
      debugPrint('🔍 [addToCart] Default unit: ${unit?.unitName ?? "NULL"}');

      // If no default unit, load all units and take the first one
      if (unit == null) {
        try {
          debugPrint('🔍 [addToCart] Loading all units...');
          final units = await getProductUnits(product.id);
          debugPrint('🔍 [addToCart] Found ${units.length} units');
          if (units.isNotEmpty) {
            unit = units.first;
            debugPrint('🔍 [addToCart] Using first unit: ${unit.unitName}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to load units for product ${product.id}: $e');
        }
      }

      // Last resort: create a temporary base unit (kg/ml) - NOT "đơn vị"
      if (unit == null) {
        final baseUnitName = product.baseUnit ?? 'kg';
        debugPrint('🔍 [addToCart] Creating temporary unit: $baseUnitName');
        unit = ProductUnit(
          id: '',
          productId: product.id,
          unitName: baseUnitName,
          conversionFactor: 1.0,
          unitPrice: price,
          isDefaultSellingUnit: true,
          isActive: true,
          storeId: BaseService.getDefaultStoreId(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }

    debugPrint('✅ [addToCart] Final unit: ${unit.unitName} (factor: ${unit.conversionFactor})');

    final unitConversionFactor = unit.conversionFactor;
    final baseUnitQty = quantity * unitConversionFactor;

    // Check stock using base unit quantity
    final stock = getProductStock(product.id);
    if (stock < baseUnitQty) {
      _setError('Không đủ hàng tồn kho (còn ${stock ~/ unitConversionFactor} ${unit.unitName})');
      return;
    }

    // Check if product already in cart
    final existingIndex = _cartItems.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex != -1) {
      // Update existing item
      final existing = _cartItems[existingIndex];
      final newQuantity = existing.quantity + quantity;
      final newBaseUnitQty = newQuantity * unitConversionFactor;

      if (stock < newBaseUnitQty) {
        _setError('Không đủ hàng tồn kho (còn ${stock ~/ unitConversionFactor} ${unit.unitName})');
        return;
      }

      _cartItems[existingIndex] = existing.copyWith(
        quantity: newQuantity,
        subTotal: newQuantity * price,
      );
    } else {
      // Add new item with unit information (unit is ALWAYS available now)
      final cartItem = CartItem(
        productId: product.id,
        productName: product.name,
        productSku: product.sku,
        quantity: quantity,
        priceAtSale: price,
        subTotal: quantity * price,
        selectedUnitId: unit.id,
        selectedUnitName: unit.unitName, // ✅ LUÔN có tên unit cụ thể
        selectedUnitConversionFactor: unitConversionFactor,
      );

      debugPrint('✅ [CartItem Created] unitName: "${cartItem.selectedUnitName}", price: ${cartItem.priceAtSale}');
      _cartItems.add(cartItem);
    }

    _calculateCartTotal();
    _clearError();
    notifyListeners();
  }

  void updateCartItem(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      final item = _cartItems[index];
      final stock = getProductStock(productId);

      if (stock < newQuantity) {
        _setError('Không đủ hàng tồn kho (còn $stock)');
        return;
      }

      _cartItems[index] = item.copyWith(
        quantity: newQuantity,
        subTotal: newQuantity * item.priceAtSale,
      );

      _calculateCartTotal();
      _clearError();
      notifyListeners();
    }
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _calculateCartTotal();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _cartTotal = 0.0;
    notifyListeners();
  }

  Future<String?> checkout({
    String? customerId,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    bool isDebt = false,
    String? notes,
    DateTime? debtDueDate, // Due date for debt transactions
  }) async {
    if (_cartItems.isEmpty) {
      _setError('Giỏ hàng trống');
      return null;
    }

    _setStatus(ProductStatus.loading);

    try {
      debugPrint('🔍 [checkout] Converting ${_cartItems.length} cart items...');

      // Convert cart items to transaction items
      // Multi-UoM: Map unit fields for historical tracking
      final transactionItems = _cartItems.map((cartItem) {
        final txItem = TransactionItem(
          id: '', // Will be generated by database
          transactionId: '', // Will be set by service
          productId: cartItem.productId,
          batchId: null, // Service will handle FIFO selection
          quantity: cartItem.quantity,
          priceAtSale: cartItem.priceAtSale,
          subTotal: cartItem.subTotal,
          createdAt: DateTime.now(),
          storeId: BaseService.getDefaultStoreId(),
          unitId: cartItem.selectedUnitId,
          unitName: cartItem.selectedUnitName,
          unitConversionFactor: cartItem.selectedUnitConversionFactor,
          baseUnitQuantity: cartItem.baseUnitQuantity,
        );

        debugPrint('✅ [TransactionItem] ${cartItem.productName}: unitName="${txItem.unitName}", price=${txItem.priceAtSale}');
        return txItem;
      }).toList();

      final transactionId = await _transactionService.createTransaction(
        customerId: customerId,
        items: transactionItems,
        paymentMethod: paymentMethod,
        notes: notes,
        debtDueDate: debtDueDate,
      );

      // 🔥 FIX: Store sold product IDs before clearing cart
      final soldProductIds = _cartItems.map((item) => item.productId).toSet();

      // Clear cart after successful transaction
      clearCart();

      // 🔥 FIX: Refresh stock cache after successful sale
      await _refreshStockAfterTransaction(soldProductIds);

      _setStatus(ProductStatus.success);
      _clearError();

      return transactionId; // Trả về thành công ngay lập tức
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Finalize credit sale with surcharge amount (used by ConfirmCreditSaleSheet)
  Future<String?> finalizeCreditSaleWithSurcharge({
    required String customerId,
    required double surchargeAmount,
    String? notes,
    DateTime? debtDueDate,
  }) async {
    if (_cartItems.isEmpty) {
      _setError('Giỏ hàng trống');
      return null;
    }

    _setStatus(ProductStatus.loading);

    try {
      // Convert cart items to transaction items
      // Multi-UoM: Map unit fields for historical tracking
      final transactionItems = _cartItems
          .map(
            (cartItem) => TransactionItem(
              id: '', // Will be generated by database
              transactionId: '', // Will be set by service
              productId: cartItem.productId,
              batchId: null, // Service will handle FIFO selection
              quantity: cartItem.quantity,
              priceAtSale: cartItem.priceAtSale,
              subTotal: cartItem.subTotal,
              createdAt: DateTime.now(),
              storeId: BaseService.getDefaultStoreId(),
              unitId: cartItem.selectedUnitId,
              unitName: cartItem.selectedUnitName,
              unitConversionFactor: cartItem.selectedUnitConversionFactor,
              baseUnitQuantity: cartItem.baseUnitQuantity,
            ),
          )
          .toList();

      final transactionId = await _transactionService.createTransaction(
        customerId: customerId,
        items: transactionItems,
        paymentMethod: PaymentMethod.debt,
        notes: notes,
        debtDueDate: debtDueDate,
        surchargeAmount: surchargeAmount, // Pass surcharge amount
      );

      // 🔥 FIX: Store sold product IDs before clearing cart
      final soldProductIds = _cartItems.map((item) => item.productId).toSet();

      // Clear cart after successful transaction
      clearCart();

      // 🔥 FIX: Refresh stock cache after successful credit sale
      await _refreshStockAfterTransaction(soldProductIds);

      _setStatus(ProductStatus.success);
      _clearError();

      return transactionId;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Refresh stock cache after successful transaction
  /// This ensures Product screens show updated stock immediately
  Future<void> _refreshStockAfterTransaction(Set<String> soldProductIds) async {
    try {
      print('🔄 Refreshing stock cache after transaction...');
      
      // 🚀 OPTIMIZED: Only refresh stock for products that were sold
      // This is more efficient than refreshing all cached products
      for (final productId in soldProductIds) {
        try {
          final updatedStock = await _productService.getAvailableStock(productId);
          _stockMap[productId] = updatedStock;
          
          // Also update the stock in product objects if they exist
          final productIndex = _products.indexWhere((p) => p.id == productId);
          if (productIndex != -1) {
            final productName = _products[productIndex].name;
            _products[productIndex] = _products[productIndex].copyWith(
              availableStock: updatedStock,
            );
            print('📦 Updated stock for $productName: $updatedStock');
          }
          
          // Update selected product if it matches
          if (_selectedProduct?.id == productId) {
            _selectedProduct = _selectedProduct!.copyWith(
              availableStock: updatedStock,
            );
          }
        } catch (e) {
          print('Warning: Failed to refresh stock for product $productId: $e');
          // Continue with other products even if one fails
        }
      }
      
      print('✅ Stock cache refreshed for ${soldProductIds.length} sold products');
      notifyListeners(); // Update UI with new stock values
    } catch (e) {
      print('⚠️ Error refreshing stock after transaction: $e');
      // Don't throw error since transaction was successful
    }
  }

  Future<Product?> scanBarcode(String sku) async {
    try {
      final product = await _productService.scanProductBySKU(sku);
      return product;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // =====================================================
  // BANNED SUBSTANCES
  // =====================================================

  Future<void> loadBannedSubstances() async {
    try {
      _bannedSubstances = await _productService.getBannedSubstances();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> addBannedSubstance(BannedSubstance substance) async {
    try {
      final newSubstance = await _productService.addBannedSubstance(substance);
      _bannedSubstances.insert(0, newSubstance);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // =====================================================
  // TRANSACTION DETAILS
  // =====================================================

  // Transaction loading state (separate from product loading)
  bool _isLoadingTransaction = false;
  bool get isLoadingTransaction => _isLoadingTransaction;

  Future<void> loadTransactionDetails(String transactionId) async {
    // 🔥 CRITICAL FIX: Use separate loading state for transactions
    _isLoadingTransaction = true;
    notifyListeners();
    
    try {
      print('📋 Loading transaction details for ID: $transactionId');
      
      // Bước A: Lấy dữ liệu thô từ Service như cũ
      _activeTransaction = await _transactionService.getTransactionById(
        transactionId,
      );
      if (_activeTransaction == null) {
        throw Exception('Không tìm thấy giao dịch. Vui lòng thử lại.');
      }
      final rawItems = await _transactionService.getTransactionItems(
        transactionId,
      );

      // Bước B: "Làm giàu" dữ liệu (Enrichment)
      final List<TransactionItemDetails> enrichedItems = [];
      final Map<String, List<ProductUnit>> unitCache = {};
      for (final item in rawItems) {
        // Tìm sản phẩm tương ứng trong danh sách sản phẩm tổng mà Provider đang có
        final product = _products.firstWhere(
          (p) => p.id == item.productId,
          // orElse để tránh bị crash nếu không tìm thấy sản phẩm
          orElse: () => Product(
            id: item.productId,
            name: 'Sản phẩm không xác định',
            sku: 'N/A',
            category: ProductCategory.FERTILIZER, // Default
            attributes: {},
            baseUnit: 'unit', // Default base unit
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            storeId: BaseService.getDefaultStoreId(),
          ),
        );

        // Load product units for Multi-UoM display (with simple cache per product)
        List<ProductUnit> productUnits = unitCache[product.id] ?? const <ProductUnit>[];
        if (!unitCache.containsKey(product.id)) {
          try {
            productUnits = await getProductUnits(product.id);
          } catch (e) {
            productUnits = [];
            debugPrint('⚠️ Failed to load units for product ${product.name}: $e');
          }
          unitCache[product.id] = productUnits;
        } else {
          productUnits = unitCache[product.id]!;
        }

        debugPrint('🔍 [loadTransactionDetails] Item: ${product.name}');
        debugPrint('🔍 [loadTransactionDetails] Raw item.unitName: "${item.unitName}"');
        debugPrint('🔍 [loadTransactionDetails] Raw item.priceAtSale: ${item.priceAtSale}');

        // Tìm unit matching với unit đã bán (theo unitId hoặc unitName)
        ProductUnit? matchedUnit;
        if (productUnits.isNotEmpty) {
          if (item.unitId != null) {
            try {
              matchedUnit = productUnits.firstWhere(
                (u) => u.id == item.unitId,
              );
              debugPrint('🔍 [loadTransactionDetails] Matched by unitId: ${matchedUnit.unitName}');
            } catch (_) {
              matchedUnit = null;
            }
          }
          if (matchedUnit == null && item.unitName != null) {
            try {
              matchedUnit = productUnits.firstWhere(
                (u) => u.unitName.toLowerCase() == item.unitName!.toLowerCase(),
              );
              debugPrint('🔍 [loadTransactionDetails] Matched by unitName: ${matchedUnit.unitName}');
            } catch (_) {
              debugPrint('⚠️ [loadTransactionDetails] No matching unit found for "${item.unitName}"');
              matchedUnit = null;
            }
          }
        }

        final baseUnitName = product.effectiveBaseUnit;

        // ĐƠN GIẢN: Dùng thông tin đã lưu, KHÔNG fallback về defaultUnit
        String unitLabel;
        if (matchedUnit != null && productUnits.isNotEmpty) {
          unitLabel = UnitDisplayFormatter.label(
            unit: matchedUnit,
            units: productUnits,
            baseUnitName: baseUnitName,
          );
        } else {
          // Không tìm được matchedUnit → dùng trực tiếp item.unitName
          unitLabel = item.unitName ?? baseUnitName;
        }

        double? selectedConversion =
            item.unitConversionFactor ?? matchedUnit?.conversionFactor;
        if ((selectedConversion == null || selectedConversion <= 0) &&
            item.baseUnitQuantity != null &&
            item.quantity > 0) {
          selectedConversion = item.baseUnitQuantity! / item.quantity;
        }
        if (selectedConversion != null && selectedConversion <= 0) {
          selectedConversion = null;
        }

        // ĐƠN GIẢN: Dùng trực tiếp thông tin đã lưu, không tính toán lại
        // item.priceAtSale ĐÃ ĐÚNG từ lúc bán - không cần convert!
        String priceUnitName = matchedUnit?.unitName ?? item.unitName ?? baseUnitName;
        double pricePerDisplayUnit = item.priceAtSale;

        debugPrint('✅ [loadTransactionDetails] priceUnitName: "$priceUnitName", pricePerDisplayUnit: $pricePerDisplayUnit');

        final double? baseUnitQuantity = item.baseUnitQuantity ??
            (selectedConversion != null
                ? selectedConversion * item.quantity
                : null);

        // Tạo object "ảo" đã gộp đủ thông tin
        enrichedItems.add(
          TransactionItemDetails(
            productId: item.productId,
            productName: product.name,
            productSku: product.sku,
            quantity: item.quantity,
            priceAtSale: item.priceAtSale,
            subTotal: item.subTotal,
            unitId: item.unitId ?? matchedUnit?.id,
            unitName: item.unitName ?? matchedUnit?.unitName,
            unitConversionFactor: selectedConversion,
            baseUnitQuantity: baseUnitQuantity,
            unitLabel: unitLabel,
            pricePerDisplayUnit: pricePerDisplayUnit,
            priceUnitName: priceUnitName,
          ),
        );
      }

      // Bước C: Cập nhật state với dữ liệu đã được làm giàu
      _activeTransactionItems = enrichedItems;
      _isLoadingTransaction = false;
      _errorMessage = '';
      _status = ProductStatus.success;
      
      print('✅ Transaction details loaded successfully');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading transaction details: $e');
      _isLoadingTransaction = false;
      _setError(e.toString());
    }
  }

  // =====================================================
  // DASHBOARD & ANALYTICS
  // =====================================================

  /// Load dashboard statistics (direct load only - cache disabled)
  Future<void> loadDashboardStats({bool useCache = true}) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Get product stats directly  
      final productStats = await _productService.getProductDashboardStats();
      
      // Get transaction stats
      final transactionStats = await _transactionService.getTodaySalesStats();
      
      // Combine both
      _dashboardStats = {...productStats, ...transactionStats};
      
      if (CacheConfig.enablePerformanceLogging) {
        stopwatch.stop();
        final ms = stopwatch.elapsedMilliseconds;
        print('💾 Direct dashboard stats loaded in: ${ms}ms');
        CacheMetrics.recordMiss();
        CacheMetrics.recordOperationTime('dashboard_direct', ms);
      }

      notifyListeners();
    } catch (e) {
      // Graceful degradation

      notifyListeners();
    } catch (e) {
      // Graceful degradation
      if (useCache) {
        if (kDebugMode) {
          print('Cache stats failed, falling back to direct load: $e');
        }
        return loadDashboardStats(useCache: true);
      }
      
      _setError(e.toString());
      CacheMetrics.recordMiss();
    }
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  Future<void> _updateProductStock(String productId) async {
    try {
      final stock = await _productService.getAvailableStock(productId);
      _stockMap[productId] = stock;
    } catch (e) {
      // Silent fail for individual stock updates
    }
  }

  // Price sync methods removed - now handled by database migration sync_prices_from_history.sql

  /// Force refresh products data from database (useful after price sync migration)
  Future<void> forceRefreshProducts() async {
    try {
      _setStatus(ProductStatus.loading);

      // Clear current data
      _products.clear();
      _filteredProducts.clear();
      _currentPrices.clear();
      _stockMap.clear();

      // Reload first page
      await loadProducts();
    } catch (e) {
      _setError('Failed to refresh products: $e');
    }
  }

  void _calculateCartTotal() {
    _cartTotal = _cartItems.fold(0.0, (sum, item) => sum + item.subTotal);
  }

  void _setStatus(ProductStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setStatusSilent(ProductStatus status) {
    _status = status;
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = ProductStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // =====================================================
  // CACHE MANAGEMENT
  // =====================================================
  
  /// Invalidate product cache to force fresh data
  Future<void> invalidateCache() async {
    await _cachedService.invalidateProductCache();
    await _cachedService.invalidateSearchCache();
    await _cachedService.invalidateDashboardCache();
    _productsByCategory.clear();
    _unitCache.clear();
  }

  /// Force refresh dashboard stats with cache support
  Future<void> refreshDashboardStats({bool useCache = true}) async {
    try {
      _dashboardStats = await _cachedService.getDashboardStats(useCache: useCache);
      notifyListeners();
    } catch (e) {
      _setError('Lỗi tải thống kê: ${e.toString()}');
    }
  }

  /// Get cache performance metrics
  Map<String, dynamic> getCacheMetrics() {
    return CacheManager().getStats();
  }

  // =====================================================
  // PAGINATION UTILITIES
  // =====================================================

  /// Reset pagination state and reload first page
  Future<void> resetProductsPagination({
    ProductCategory? category,
    int pageSize = 20,
    String? sortBy,
    bool ascending = true,
  }) async {
    _paginatedProducts = null;
    _isLoadingMore = false;
    _currentPaginationParams = const PaginationParams();

    await loadProductsPaginated(
      category: category,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Reset batch pagination state and reload first page
  Future<void> resetBatchesPagination({
    required String productId,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    _paginatedBatches = null;
    _isBatchesLoadingMore = false;
    _currentBatchPaginationParams = const PaginationParams();

    await loadProductBatchesPaginated(
      productId: productId,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Clear all pagination state
  void clearPaginationState() {
    _paginatedProducts = null;
    _paginatedBatches = null;
    _isLoadingMore = false;
    _isBatchesLoadingMore = false;
    _currentPaginationParams = const PaginationParams();
    _currentBatchPaginationParams = const PaginationParams();
    notifyListeners();
  }

  /// ONE-TIME price sync when user enters the app (no cache invalidation)
  Future<void> _performOneTimePriceSyncIfNeeded() async {
    // 🔥 CRITICAL: Only sync once per session to prevent loops
    if (_hasPerformedInitialPriceSync) {
      print('✅ Initial price sync already performed, skipping...');
      // Still need to update maps for all products
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;
        _currentPrices[product.id] = product.currentSellingPrice;
      }
      return;
    }
    
    try {
      final productsWithZeroPrice = _products.where((p) => p.currentSellingPrice == 0).toList();
      
      if (productsWithZeroPrice.isEmpty) {
        // Only log when debug is enabled
        if (kDebugMode) print('✅ All products have valid prices, no sync needed');
        // Update stock and price maps for all products
        for (final product in _products) {
          _stockMap[product.id] = product.availableStock ?? 0;
          _currentPrices[product.id] = product.currentSellingPrice;
          // Remove individual price logging to reduce spam
          // if (kDebugMode) print('💰 Using existing price for ${product.name}: ${product.currentSellingPrice}');
        }
      } else {
        print('🔄 ONE-TIME SYNC: Found ${productsWithZeroPrice.length} products with 0 price, syncing...');
        
        bool hasSyncedAnyPrice = false;
        for (final product in _products) {
          _stockMap[product.id] = product.availableStock ?? 0;
          
          if (product.currentSellingPrice == 0) {
            // Try to sync from price history WITHOUT cache invalidation
            final syncedPrice = await _syncPriceFromHistoryWithoutInvalidation(product.id);
            _currentPrices[product.id] = syncedPrice > 0 ? syncedPrice : 0.0;
            if (syncedPrice > 0) {
              hasSyncedAnyPrice = true;
            }
            print('🔄 Synced ${product.name}: ${_currentPrices[product.id]}');
          } else {
            _currentPrices[product.id] = product.currentSellingPrice;
            // Remove price logging to reduce spam
            // if (kDebugMode) print('💰 Using existing price for ${product.name}: ${product.currentSellingPrice}');
          }
        }
        
        // 🔥 CRITICAL FIX: If we synced any prices, force reload to get updated DB view
        if (hasSyncedAnyPrice) {
          print('🔄 Prices synced, reloading products to get updated DB view...');
          // Force reload products to get updated prices from database view
          _products = await _productService.getProducts(category: _selectedCategory);
          // Update maps with fresh data
          for (final product in _products) {
            _stockMap[product.id] = product.availableStock ?? 0;
            _currentPrices[product.id] = product.currentSellingPrice;
            print('🔄 Refreshed ${product.name}: ${product.currentSellingPrice}');
          }
        }
        
        print('✅ ONE-TIME SYNC completed');
      }
      
      // Mark as completed to prevent future syncs
      _hasPerformedInitialPriceSync = true;
    } catch (e) {
      print('⚠️ ONE-TIME SYNC failed: $e');
      // Fallback: just use existing prices
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;
        _currentPrices[product.id] = product.currentSellingPrice;
      }
      // Still mark as completed to prevent retries
      _hasPerformedInitialPriceSync = true;
    }
  }

  /// Sync price from history WITHOUT cache invalidation (silent sync)
  Future<double> _syncPriceFromHistoryWithoutInvalidation(String productId) async {
    try {
      final history = await _productService.getPriceHistory(
        productId,
        limit: 1,
      );
      if (history.isNotEmpty) {
        final latestPrice = (history.first['new_price'] as num).toDouble();
        if (latestPrice > 0) {
          // Update database current_selling_price with latest from history
          await _productService.updateCurrentSellingPrice(
            productId,
            latestPrice,
            reason: 'One-time sync on app load',
          );
          
          // 🔥 CRITICAL FIX: Update selected product if it's the same
          if (_selectedProduct?.id == productId) {
            _selectedProduct = _selectedProduct!.copyWith(
              currentSellingPrice: latestPrice,
            );
          }
          
          // Update product in memory list
          final productIndex = _products.indexWhere((p) => p.id == productId);
          if (productIndex != -1) {
            _products[productIndex] = _products[productIndex].copyWith(
              currentSellingPrice: latestPrice,
            );
          }
          
          print('🔄 Silent price sync: $productId = $latestPrice');
          return latestPrice;
        }
      }
      return 0.0;
    } catch (e) {
      print('⚠️ Silent price sync failed for $productId: $e');
      return 0.0;
    }
  }

  Future<void> refresh() async {
    // 🚨 EMERGENCY FIX: Disable price sync in normal refresh
    // Just reload data without price sync to prevent infinite loops
    try {
      _setStatus(ProductStatus.loading);
      
      // Clear cache to force fresh data load
      await _cachedService.invalidateProductCache();
      await _cachedService.invalidateSearchCache();
      
      // Use paginated method if pagination state exists, otherwise use legacy method
      if (_paginatedProducts != null) {
        await resetProductsPagination(category: _selectedCategory);
      } else {
        await loadProducts(category: _selectedCategory);
      }
      
      // Load dashboard stats without price sync
      await loadDashboardStats();
      
      _setStatus(ProductStatus.success);
    } catch (e) {
      _setError('Refresh failed: $e');
    }
  }

  Future<void> refreshProduct(String productId) async {
    try {
      final product = await _productService.getProductById(productId);
      if (product != null) {
        final index = _products.indexWhere((p) => p.id == productId);
        if (index != -1) {
          _products[index] = product;
          await _updateProductStock(productId);
          notifyListeners();
        }
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // =====================================================
  // MEMORY MANAGEMENT OVERRIDES
  // =====================================================

  @override
  void clearNonEssentialData() {
    // Clear filtered/cached data that can be regenerated
    _filteredProducts.clear();
    _searchQuery = '';

    // Clear maps that can be refetched
    _stockMap = managedMap(_stockMap, maxSize: 100);
    _currentPrices = managedMap(_currentPrices, maxSize: 100);

    // Price sync control maps removed - now using direct database sync

    // Clear expired analytics data
    if (isDataExpired('dashboard_stats')) {
      _dashboardStats.clear();
    }
    if (isDataExpired('expiring_batches')) {
      _expiringBatches.clear();
    }
    if (isDataExpired('low_stock')) {
      _lowStockProducts.clear();
    }

    updateItemCount(_calculateTotalItems());
    notifyListeners();
  }

  @override
  void performMemoryOptimization() {
    // Aggressive memory cleanup

    // Keep only essential products (limit to 500 most recent)
    _products = managedList(_products, maxSize: 500);

    // Clear all non-essential lists
    _productBatches = managedList(_productBatches, maxSize: 200);
    _seasonalPrices = managedList(_seasonalPrices, maxSize: 100);
    _bannedSubstances = managedList(_bannedSubstances, maxSize: 50);

    // Clear cart if not actively being used
    // Note: This check is done in the auto-clear timer, so we skip it here

    // Clear transaction data if old
    if (isDataExpired('active_transaction')) {
      _activeTransaction = null;
      _activeTransactionItems.clear();
    }

    // Force garbage collection hint
    updateItemCount(_calculateTotalItems());

    if (kDebugMode) {
      print(
        'ProductProvider: Memory optimization completed. Total items: ${_calculateTotalItems()}',
      );
    }

    notifyListeners();
  }

  int _calculateTotalItems() {
    return _products.length +
        _filteredProducts.length +
        _productBatches.length +
        _seasonalPrices.length +
        _bannedSubstances.length +
        _cartItems.length +
        _stockMap.length +
        _currentPrices.length +
        _expiringBatches.length +
        _lowStockProducts.length;
  }

  /// Get comprehensive memory statistics
  Map<String, dynamic> getProviderMemoryStats() {
    final baseStats = getMemoryStats();
    return {
      ...baseStats,
      'products_count': _products.length,
      'filtered_products_count': _filteredProducts.length,
      'batches_count': _productBatches.length,
      'cart_items_count': _cartItems.length,
      'stock_map_size': _stockMap.length,
      'prices_map_size': _currentPrices.length,
      'expiring_batches_count': _expiringBatches.length,
      'low_stock_count': _lowStockProducts.length,
      'total_calculated_items': _calculateTotalItems(),
    };
  }

  /// Calculate average cost price for a product from all batches
  Future<double> calculateAverageCostPrice(String productId) async {
    try {
      return await _productService.calculateAverageCostPrice(productId);
    } catch (e) {
      _setError('Lỗi tính giá vốn trung bình: $e');
      return 0.0;
    }
  }

  /// Calculate gross profit percentage for a product
  Future<double> calculateGrossProfitPercentage(String productId) async {
    try {
      return await _productService.calculateGrossProfitPercentage(productId);
    } catch (e) {
      _setError('Lỗi tính lợi nhuận gộp: $e');
      return 0.0;
    }
  }

  /// Sync price from history ONLY when user explicitly requests it (manual action)
  Future<double> syncPriceFromHistoryOnUserAction(String productId) async {
    try {
      final history = await _productService.getPriceHistory(
        productId,
        limit: 1,
      );
      if (history.isNotEmpty) {
        final latestPrice = (history.first['new_price'] as num).toDouble();
        if (latestPrice > 0) {
          // Update database current_selling_price with latest from history
          await _productService.updateCurrentSellingPrice(
            productId,
            latestPrice,
            reason: 'User-requested sync from price history',
          );
          
          // Update local cache
          _currentPrices[productId] = latestPrice;
          
          // Update product in memory if exists
          final productIndex = _products.indexWhere((p) => p.id == productId);
          if (productIndex != -1) {
            _products[productIndex] = _products[productIndex].copyWith(
              currentSellingPrice: latestPrice,
            );
          }
          
          // Update selected product if it's the same
          if (_selectedProduct?.id == productId) {
            _selectedProduct = _selectedProduct!.copyWith(
              currentSellingPrice: latestPrice,
            );
          }
          
          // 🔥 CRITICAL: Invalidate cache ONLY for user-requested sync
          await _cachedService.invalidateProductCache();
          
          print('🔄 User-requested price sync: $productId = $latestPrice');
          notifyListeners();
          return latestPrice;
        }
      }
      return 0.0;
    } catch (e) {
      print('⚠️ User-requested price sync failed for $productId: $e');
      return 0.0;
    }
  }

  /// Manual refresh with price sync (pull-to-refresh action)
  Future<void> refreshWithPriceSync() async {
    try {
      _setStatus(ProductStatus.loading);
      
      // 🔥 CRITICAL: Reset sync flag to allow manual price sync
      _hasPerformedInitialPriceSync = false;
      
      // Clear cache to force fresh data load
      await _cachedService.invalidateProductCache();
      await _cachedService.invalidateSearchCache();
      
      // Reload products first
      if (_paginatedProducts != null) {
        await resetProductsPagination(category: _selectedCategory);
      } else {
        await loadProducts(category: _selectedCategory);
      }
      
      // Sync prices for products with 0 price (user explicit action)
      final productsToSync = _products.where((p) => p.currentSellingPrice == 0).toList();
      if (productsToSync.isNotEmpty) {
        print('🔄 User refresh: Syncing ${productsToSync.length} products with 0 price');
        
        for (final product in productsToSync) {
          final syncedPrice = await syncPriceFromHistoryOnUserAction(product.id);
          if (syncedPrice > 0) {
            print('✅ Synced ${product.name}: $syncedPrice');
          }
        }
      }
      
      // Load dashboard stats
      await loadDashboardStats();
      
      _setStatus(ProductStatus.success);
    } catch (e) {
      _setError('Refresh with price sync failed: $e');
    }
  }

  /// Update current selling price for a product
  Future<bool> updateCurrentSellingPrice(
    String productId,
    double newPrice, {
    String reason = 'Manual price update',
  }) async {
    try {
      _setStatus(ProductStatus.loading);

      final success = await _productService.updateCurrentSellingPrice(
        productId,
        newPrice,
        reason: reason,
      );

      if (success) {
        // Update local product cache
        final productIndex = _products.indexWhere((p) => p.id == productId);
        if (productIndex != -1) {
          _products[productIndex] = _products[productIndex].copyWith(
            currentSellingPrice: newPrice,
          );
        }

        // Update selected product if it's the same
        if (_selectedProduct?.id == productId) {
          _selectedProduct = _selectedProduct!.copyWith(
            currentSellingPrice: newPrice,
          );
        }

        // FIXED: Update _currentPrices cache for POS
        _currentPrices[productId] = newPrice;

        _setStatus(ProductStatus.success);
        notifyListeners();
      } else {
        _setError('Không thể cập nhật giá bán');
      }

      return success;
    } catch (e) {
      _setError('Lỗi cập nhật giá bán: $e');
      return false;
    }
  }

  Future<bool> updateProductPrice(String productId, double newPrice) async {
    try {
      await _productService.updateCurrentSellingPrice(
        productId,
        newPrice,
        reason: 'Manual update from UI',
      );
      // Manually update the price in the local cache/state
      _currentPrices[productId] = newPrice;
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = _products[index].copyWith(currentSellingPrice: newPrice);
      }
      if (_selectedProduct?.id == productId) {
        _selectedProduct = _selectedProduct!.copyWith(currentSellingPrice: newPrice);
      }
      notifyListeners();
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Quick add batch with new selling price
  /// 🔥 FIXED: Service returns Product, not String. Database RPC handles unit price sync.
  Future<bool> quickAddBatch({
    required String productId,
    required int quantity,
    required double costPrice,
    required double newSellingPrice,
  }) async {
    try {
      _setStatus(ProductStatus.loading);

      final updatedProduct = await _productService.quickAddBatch(
        productId: productId,
        quantity: quantity,
        costPrice: costPrice,
        newSellingPrice: newSellingPrice,
      );

      if (updatedProduct != null) {
        // Reload batches for this product
        await loadProductBatches(productId);

        // FIXED: Update stock after adding batch
        await _updateProductStock(productId);

        // 🔥 FIXED: Use updated product from service (already has latest price from RPC)
        final productIndex = _products.indexWhere((p) => p.id == productId);
        if (productIndex != -1) {
          _products[productIndex] = updatedProduct.copyWith(
            availableStock: _stockMap[productId], // Use refreshed stock
          );
        }

        if (_selectedProduct?.id == productId) {
          _selectedProduct = updatedProduct.copyWith(
            availableStock: _stockMap[productId],
          );
        }

        // FIXED: Update _currentPrices cache for POS from returned product
        _currentPrices[productId] = updatedProduct.currentSellingPrice;

        _setStatus(ProductStatus.success);
        notifyListeners();
        return true;
      } else {
        _setError('Không thể thêm lô hàng');
        return false;
      }
    } catch (e) {
      _setError('Lỗi thêm lô hàng nhanh: $e');
      return false;
    }
  }

  /// 🔥 NEW: Directly update products from PO receiving flow
  void updateProductsFromPO(List<Product> updatedProducts) {
    for (final product in updatedProducts) {
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
      }
      // Also update the selected product if it matches
      if (_selectedProduct?.id == product.id) {
        _selectedProduct = product;
      }
      // Update caches
      _stockMap[product.id] = product.availableStock ?? 0;
      _currentPrices[product.id] = product.currentSellingPrice;
    }
    // Notify listeners after all updates are done
    notifyListeners();
  }

  /// Quick add batch with unit conversion support
  /// 🔥 FIXED: Service returns Product, not String. Database RPC handles unit price sync atomically.
  Future<bool> quickAddBatchWithUnit({
    required String productId,
    required int quantity,
    required double costPrice,
    required double newSellingPrice,
    String? unitId, // Unit ID for conversion
  }) async {
    try {
      _setStatus(ProductStatus.loading);

      final updatedProduct = await _productService.quickAddBatch(
        productId: productId,
        quantity: quantity,
        costPrice: costPrice,
        newSellingPrice: newSellingPrice,
        unitId: unitId, // Pass unit ID for conversion
      );

      if (updatedProduct != null) {
        // Reload batches for this product
        await loadProductBatches(productId);

        // FIXED: Update stock after adding batch
        await _updateProductStock(productId);

        // 🔥 FIXED: Use updated product from service (RPC has already updated all unit prices atomically)
        final productIndex = _products.indexWhere((p) => p.id == productId);
        if (productIndex != -1) {
          _products[productIndex] = updatedProduct.copyWith(
            availableStock: _stockMap[productId], // Use refreshed stock
          );
        }

        if (_selectedProduct?.id == productId) {
          _selectedProduct = updatedProduct.copyWith(
            availableStock: _stockMap[productId],
          );
        }

        // FIXED: Update _currentPrices cache for POS from returned product
        _currentPrices[productId] = updatedProduct.currentSellingPrice;

        _setStatus(ProductStatus.success);
        notifyListeners();
        return true;
      } else {
        _setError('Không thể thêm lô hàng');
        return false;
      }
    } catch (e) {
      _setError('Lỗi thêm lô hàng nhanh với đơn vị: $e');
      return false;
    }
  }

  /// Lấy lịch sử thay đổi giá của một sản phẩm
  Future<List<PriceHistoryItem>> getPriceHistory(String productId) async {
    try {
      final rawHistory = await _productService.getPriceHistory(productId);

      return rawHistory.map((json) {
        final profiles = json['profiles'] as Map<String, dynamic>?;
        final displayName = profiles?['display_name'] as String?;

        return PriceHistoryItem(
          id: json['id'] as String,
          newPrice: (json['new_price'] as num).toDouble(),
          oldPrice: json['old_price'] != null
              ? (json['old_price'] as num).toDouble()
              : null,
          changedAt: DateTime.parse(json['changed_at'] as String),
          reason: json['reason'] as String?,
          userWhoChanged: displayName ?? 'Người dùng không xác định',
        );
      }).toList();
    } catch (e) {
      _setError('Lỗi lấy lịch sử giá: $e');
      return [];
    }
  }

  // =====================================================
  // CACHE MANAGEMENT METHODS
  // =====================================================

  /// Invalidate search cache (call after product updates)
  Future<void> invalidateSearchCache() async {
    if (CacheConfig.enableSearchCache) {
      await _cachedService.invalidateSearchCache();
      if (CacheConfig.enableCacheLogging) {
        print('🧹 Search cache invalidated');
      }
    }
  }

  /// Invalidate dashboard cache (DISABLED - no dashboard cache)
  Future<void> invalidateDashboardCache() async {
    // Dashboard cache disabled - no action needed
    if (CacheConfig.enableCacheLogging) {
      print('⏭️ Dashboard cache invalidation skipped (disabled)');
    }
  }

  /// Force refresh all cached data
  @Deprecated('Use refreshProductsByIds() for product-specific updates')
  Future<void> refreshAllCache() async {
    await invalidateSearchCache();
    // Dashboard cache disabled - just reload directly
    await loadDashboardStats(useCache: true);

    if (CacheConfig.enableCacheLogging) {
      print('🔄 Search cache refreshed (dashboard direct load)');
    }
  }

  /// Refresh specific products after price/inventory updates
  /// This ensures cache stays synchronized with database changes
  Future<void> refreshProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return;

    try {
      print('🔄 Refreshing ${productIds.length} products after update...');

      for (final productId in productIds) {
        // Reload product from database to get latest data
        final product = await _productService.getProductById(productId);
        if (product != null) {
          // Update in main products list
          final index = _products.indexWhere((p) => p.id == productId);
          if (index != -1) {
            _products[index] = product;
            print('✅ Updated ${product.name} in products list: ${product.currentSellingPrice}');
          }

          // Update selected product if it matches
          if (_selectedProduct?.id == productId) {
            _selectedProduct = product;
            print('✅ Updated selected product: ${product.name}');
          }

          // Update price cache (critical for POS display)
          _currentPrices[productId] = product.currentSellingPrice;
          print('💰 Updated price cache for ${product.name}: ${product.currentSellingPrice}');

          // Update stock cache
          _stockMap[productId] = product.availableStock ?? 0;
          print('📦 Updated stock cache for ${product.name}: ${product.availableStock ?? 0}');
        }
      }

      // Notify listeners to rebuild UI with updated data
      notifyListeners();
      print('✅ Successfully refreshed ${productIds.length} products');
    } catch (e) {
      print('❌ Error refreshing products: $e');
      // Don't throw - this is a cache refresh operation, not critical
    }
  }

  /// Get cache performance metrics
  Map<String, dynamic> getCacheStats() {
    final cacheStats = CacheMetrics.getStats();
    final providerStats = getProviderMemoryStats();
    
    return {
      'cache_performance': cacheStats,
      'provider_memory': providerStats,
      'cache_config': {
        'search_enabled': CacheConfig.enableSearchCache,
        'stats_enabled': CacheConfig.enableStatsCache,
        'logging_enabled': CacheConfig.enableCacheLogging,
      },
    };
  }

  // =====================================================
  // MULTI-UOM OPERATIONS
  // =====================================================

  /// Get product units for Multi-UoM support
  /// Used by UI components to display unit selection
  Future<List<ProductUnit>> getProductUnits(String productId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _unitCache.containsKey(productId)) {
      return List<ProductUnit>.from(_unitCache[productId]!);
    }
    try {
      final units = await _unitService.getProductUnits(productId);
      _unitCache[productId] = units;
      return List<ProductUnit>.from(units);
    } catch (e) {
      print('Error loading product units: $e');
      return List<ProductUnit>.from(_unitCache[productId] ?? []);
    }
  }

  /// 🔥 NEW: Refresh product units cache for a specific product
  /// Used to ensure UI shows latest unit configuration after changes
  Future<void> refreshProductUnitsCache(
    String productId, {
    bool forceNetwork = false,
    List<ProductUnit>? prefetchedUnits,
  }) async {
    try {
      if (prefetchedUnits != null && prefetchedUnits.isNotEmpty) {
        _unitCache[productId] = prefetchedUnits;
        notifyListeners();
        if (!forceNetwork) {
          return;
        }
      }
      if (forceNetwork) {
        _unitCache.remove(productId);
      }
      final units = await _unitService.getProductUnits(productId);
      _unitCache[productId] = units;
      print('✅ Refreshed product units cache for product: $productId');
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing product units cache: $e');
    }
  }

  Future<void> refreshProductSummary(String productId) async {
    try {
      final product = await _productService.getProductById(productId);
      if (product == null) return;

      void replaceProductInList(List<Product> list) {
        final idx = list.indexWhere((p) => p.id == productId);
        if (idx != -1) {
          list[idx] = product;
        } else {
          list.insert(0, product);
        }
      }

      // Update master list
      replaceProductInList(_products);

      // Update category caches
      final ProductCategory category = product.category;
      if (_productsByCategory.containsKey(null)) {
        replaceProductInList(_productsByCategory[null]!);
      } else {
        _productsByCategory[null] = List<Product>.from(_products);
      }
      if (_productsByCategory.containsKey(category)) {
        replaceProductInList(_productsByCategory[category]!);
      } else {
        _productsByCategory[category] = _products
            .where((p) => p.category == category)
            .toList();
      }

      // Update filtered results if present
      if (_filteredProducts.isNotEmpty) {
        replaceProductInList(_filteredProducts);
      }

      // Update selected product if necessary
      if (_selectedProduct?.id == productId) {
        _selectedProduct = product;
      }

      // Update supporting caches (prices, search)
      _currentPrices[productId] = product.currentSellingPrice;

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing product summary for $productId: $e');
    }
  }

  /// Get default selling unit for a product
  Future<ProductUnit?> getDefaultUnit(String productId) async {
    try {
      return await _unitService.getDefaultUnit(productId);
    } catch (e) {
      print('Error loading default unit: $e');
      return null;
    }
  }

}

// =====================================================
// CART ITEM MODEL
// =====================================================

class CartItem {
  final String productId;
  final String productName;
  final String? productSku;
  final int quantity;
  final double priceAtSale;
  final double subTotal;
  final double discountAmount;

  // Multi-UoM support
  final String? selectedUnitId;
  final String selectedUnitName;
  final double selectedUnitConversionFactor;

  CartItem({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    required this.priceAtSale,
    required this.subTotal,
    this.discountAmount = 0,
    this.selectedUnitId,
    this.selectedUnitName = '',
    this.selectedUnitConversionFactor = 1.0,
  });

  // Computed property: quantity in base unit
  double get baseUnitQuantity => quantity * selectedUnitConversionFactor;

  CartItem copyWith({
    int? quantity,
    double? priceAtSale,
    double? subTotal,
    double? discountAmount,
    String? selectedUnitId,
    String? selectedUnitName,
    double? selectedUnitConversionFactor,
  }) {
    return CartItem(
      productId: productId,
      productName: productName,
      productSku: productSku,
      quantity: quantity ?? this.quantity,
      priceAtSale: priceAtSale ?? this.priceAtSale,
      subTotal: subTotal ?? this.subTotal,
      discountAmount: discountAmount ?? this.discountAmount,
      selectedUnitId: selectedUnitId ?? this.selectedUnitId,
      selectedUnitName: selectedUnitName ?? this.selectedUnitName,
      selectedUnitConversionFactor: selectedUnitConversionFactor ?? this.selectedUnitConversionFactor,
    );
  }
}

// =====================================================
// PRODUCT LIST VIEW MODEL (FOR COMPLEX SCREENS)
// =====================================================

class ProductListViewModel {
  final ProductProvider productProvider;

  ProductListViewModel(this.productProvider);

  Future<void> initialize() async {
    if (productProvider.products.isEmpty) {
      await productProvider.loadProductsPaginated(useCache: true);
    }
    await productProvider.loadAlerts();
  }

  Future<void> handleSearch(String query) async {
    await productProvider.searchProducts(query);
  }

  Future<void> handleCategoryFilter(ProductCategory? category) async {
    productProvider.filterByCategory(category);
  }

  void handleProductTap(Product product) {
    productProvider.selectProduct(product);
  }

  // Validation methods
  String? validateProductName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Tên sản phẩm không được để trống';
    }
    if (name.trim().length < 2) {
      return 'Tên sản phẩm phải có ít nhất 2 ký tự';
    }
    return null;
  }

  String? validateSKU(String? sku) {
    if (sku == null || sku.trim().isEmpty) {
      return 'SKU không được để trống';
    }
    if (sku.trim().length < 3) {
      return 'SKU phải có ít nhất 3 ký tự';
    }
    return null;
  }

  String? validatePrice(String? price) {
    if (price == null || price.trim().isEmpty) {
      return 'Giá không được để trống';
    }

    final priceValue = double.tryParse(price.trim());
    if (priceValue == null || priceValue <= 0) {
      return 'Giá phải là số dương';
    }

    return null;
  }
}
