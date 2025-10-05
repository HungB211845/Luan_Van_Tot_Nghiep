import '../../pos/services/transaction_service.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/seasonal_price.dart';
import '../models/banned_substance.dart';
import '../widgets/price_history_widget.dart';
import '../../pos/models/transaction.dart';
import '../../pos/models/transaction_item.dart';
import '../../pos/models/transaction_item_details.dart';
import '../../pos/models/payment_method.dart';
import '../models/company.dart';
import '../services/product_service.dart';
import '../../../shared/models/paginated_result.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/providers/memory_managed_provider.dart';

enum ProductStatus { idle, loading, success, error }

class ProductProvider extends ChangeNotifier with MemoryManagedProvider {
  final ProductService _productService = ProductService();
  final TransactionService _transactionService = TransactionService();

  // =====================================================
  // STATE VARIABLES
  // =====================================================

  // Products with memory management
  List<Product> _products = [];
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

  List<Product> get products =>
      _filteredProducts.isEmpty && _searchQuery.isEmpty
      ? _products
      : _filteredProducts;

  Product? get selectedProduct => _selectedProduct;
  ProductCategory? get selectedCategory => _selectedCategory;
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
  }) async {
    _setStatus(ProductStatus.loading);
    try {
      _currentPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      _paginatedProducts = await _productService.getProductsPaginated(
        params: _currentPaginationParams,
        category: category,
      );

      // Update legacy _products list for backward compatibility
      _products = _paginatedProducts!.items;
      _selectedCategory = category;

      // Update stock and price maps
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;

        // Load price directly from product.currentSellingPrice (already synced by migration)
        _currentPrices[product.id] = product.currentSellingPrice;
      }

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
      final nextPage = await _productService.getProductsPaginated(
        params: nextParams,
        category: _selectedCategory,
      );

      // Merge results
      _paginatedProducts = _paginatedProducts!.merge(nextPage);
      _currentPaginationParams = nextParams;

      // Update legacy _products list
      _products = _paginatedProducts!.items;

      // Update stock and price maps for new products
      for (final product in nextPage.items) {
        _stockMap[product.id] = product.availableStock ?? 0;

        // Load price directly from product.currentSellingPrice (already synced by migration)
        // FIXED: Auto-sync from history if current price is 0
        double finalPrice = product.currentSellingPrice;
        if (finalPrice == 0) {
          finalPrice = await _syncPriceFromHistory(product.id);
        }
        _currentPrices[product.id] = finalPrice;
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
  }) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      await loadProductsPaginated(
        category: category,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );
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

      _paginatedProducts = await _productService.searchProductsPaginated(
        query: _searchQuery,
        params: _currentPaginationParams,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        inStock: inStock,
      );

      // Update filtered products for backward compatibility
      _filteredProducts = _paginatedProducts!.items;

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
      final nextParams = _currentPaginationParams.nextPage();
      final nextPage = await _productService.searchProductsPaginated(
        query: query,
        params: nextParams,
        category: category,
        minPrice: minPrice,
        maxPrice: maxPrice,
        inStock: inStock,
      );

      // Merge results
      _paginatedProducts = _paginatedProducts!.merge(nextPage);
      _currentPaginationParams = nextParams;

      // Update filtered products
      _filteredProducts = _paginatedProducts!.items;

      _isLoadingMore = false;
      _clearError();
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

      // 2. Nạp dữ liệu vào _stockMap và _currentPrices từ danh sách vừa lấy
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;
        
        double finalPrice = product.currentSellingPrice;
        if (finalPrice == 0) {
          finalPrice = await _syncPriceFromHistory(product.id);
        }
        _currentPrices[product.id] = finalPrice;
      }

      // 3. Xóa bộ lọc cũ (nếu có)
      _filteredProducts = [];
      _searchQuery = '';

      _setStatus(ProductStatus.success); // Notify UI only when all data is ready
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setStatus(ProductStatus.loading);

    try {
      _filteredProducts = await _productService.searchProducts(_searchQuery);
      _setStatus(ProductStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Quick search cho POS screen
  List<Product> _posSearchResults = [];
  bool get hasPosSearchResults => _posSearchResults.isNotEmpty;

  Future<void> quickSearchForPOS(String query) async {
    if (query.trim().isEmpty) {
      _posSearchResults = [];
      notifyListeners();
      return;
    }

    try {
      _posSearchResults = await _productService.quickSearchForPOS(query.trim());
      notifyListeners();
    } catch (e) {
      _posSearchResults = [];
      _setError('Lỗi tìm kiếm: ${e.toString()}');
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

      // Update stock and price maps
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;

        // Load price directly from product.currentSellingPrice (already synced by migration)
        // FIXED: Auto-sync from history if current price is 0
        double finalPrice = product.currentSellingPrice;
        if (finalPrice == 0) {
          finalPrice = await _syncPriceFromHistory(product.id);
        }
        _currentPrices[product.id] = finalPrice;
      }

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

  Future<bool> addProduct(Product product) async {
    _setStatus(ProductStatus.loading);

    try {
      final newProduct = await _productService.createProduct(product);
      _products.add(newProduct);

      // Reload all products to get updated data
      await loadProducts();

      _setStatus(ProductStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    _setStatus(ProductStatus.loading);

    try {
      final updatedProduct = await _productService.updateProduct(product);

      // Update in list
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      // Update selected product if it's the same
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

  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  Future<void> filterByCategory(ProductCategory? category) async {
    _selectedCategory = category;
    if (category == null) {
      await loadProducts();
    } else {
      await loadProducts(category: category);
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

  void addToCart(Product product, int quantity, {double? customPrice}) {
    final price = customPrice ?? getCurrentPrice(product.id);

    if (price <= 0) {
      _setError('Sản phẩm chưa có giá bán');
      return;
    }

    final stock = getProductStock(product.id);
    if (stock < quantity) {
      _setError('Không đủ hàng tồn kho (còn $stock)');
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

      if (stock < newQuantity) {
        _setError('Không đủ hàng tồn kho (còn $stock)');
        return;
      }

      _cartItems[existingIndex] = existing.copyWith(
        quantity: newQuantity,
        subTotal: newQuantity * price,
      );
    } else {
      // Add new item
      _cartItems.add(
        CartItem(
          productId: product.id,
          productName: product.name,
          productSku: product.sku,
          quantity: quantity,
          priceAtSale: price,
          subTotal: quantity * price,
        ),
      );
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
      // Convert cart items to transaction items
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
            ),
          )
          .toList();

      final transactionId = await _transactionService.createTransaction(
        customerId: customerId,
        items: transactionItems,
        paymentMethod: paymentMethod,
        notes: notes,
        debtDueDate: debtDueDate,
      );

      // Clear cart after successful transaction
      clearCart();

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

      // Clear cart after successful transaction
      clearCart();

      _setStatus(ProductStatus.success);
      _clearError();

      return transactionId;
    } catch (e) {
      _setError(e.toString());
      return null;
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

  Future<void> loadTransactionDetails(String transactionId) async {
    _setStatus(ProductStatus.loading);
    try {
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            storeId: BaseService.getDefaultStoreId(),
          ),
        );

        // Tạo object "ảo" đã gộp đủ thông tin
        enrichedItems.add(
          TransactionItemDetails(
            productId: item.productId,
            productName: product.name,
            productSku: product.sku,
            quantity: item.quantity,
            priceAtSale: item.priceAtSale,
            subTotal: item.subTotal,
          ),
        );
      }

      // Bước C: Cập nhật state với dữ liệu đã được làm giàu
      _activeTransactionItems = enrichedItems;
      _setStatus(ProductStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // =====================================================
  // DASHBOARD & ANALYTICS
  // =====================================================

  Future<void> loadDashboardStats() async {
    try {
      // Get product stats
      final productStats = await _productService.getProductDashboardStats();

      // Get transaction stats
      final transactionStats = await _transactionService.getTodaySalesStats();

      // Combine both
      _dashboardStats = {...productStats, ...transactionStats};

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
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

  // =====================================================
  // REFRESH & RELOAD
  // =====================================================

  Future<void> refresh() async {
    // Use paginated method if pagination state exists, otherwise use legacy method
    if (_paginatedProducts != null) {
      await resetProductsPagination(category: _selectedCategory);
    } else {
      await loadProducts(category: _selectedCategory);
    }
    // TEMPORARY FIX: Skip loadAlerts to avoid view errors
    // await loadAlerts();
    await loadDashboardStats();
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

  /// Sync price from history if current selling price is 0
  Future<double> _syncPriceFromHistory(String productId) async {
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
            reason: 'Auto-sync from price history',
          );
          return latestPrice;
        }
      }
      return 0.0;
    } catch (e) {
      // Silent fail - return 0 if sync fails
      return 0.0;
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

  /// Quick add batch with new selling price
  Future<bool> quickAddBatch({
    required String productId,
    required int quantity,
    required double costPrice,
    required double newSellingPrice,
  }) async {
    try {
      _setStatus(ProductStatus.loading);

      final batchId = await _productService.quickAddBatch(
        productId: productId,
        quantity: quantity,
        costPrice: costPrice,
        newSellingPrice: newSellingPrice,
      );

      if (batchId.isNotEmpty) {
        // Reload batches for this product
        await loadProductBatches(productId);

        // FIXED: Update stock after adding batch
        await _updateProductStock(productId);

        // Update selling price in local cache
        final productIndex = _products.indexWhere((p) => p.id == productId);
        if (productIndex != -1) {
          _products[productIndex] = _products[productIndex].copyWith(
            currentSellingPrice: newSellingPrice,
            // FIXED: Also update availableStock in the model if available
            availableStock: _stockMap[productId],
          );
        }

        if (_selectedProduct?.id == productId) {
          _selectedProduct = _selectedProduct!.copyWith(
            currentSellingPrice: newSellingPrice,
            availableStock: _stockMap[productId],
          );
        }

        // FIXED: Update _currentPrices cache for POS
        _currentPrices[productId] = newSellingPrice;

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

  CartItem({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.quantity,
    required this.priceAtSale,
    required this.subTotal,
    this.discountAmount = 0,
  });

  CartItem copyWith({
    int? quantity,
    double? priceAtSale,
    double? subTotal,
    double? discountAmount,
  }) {
    return CartItem(
      productId: productId,
      productName: productName,
      productSku: productSku,
      quantity: quantity ?? this.quantity,
      priceAtSale: priceAtSale ?? this.priceAtSale,
      subTotal: subTotal ?? this.subTotal,
      discountAmount: discountAmount ?? this.discountAmount,
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
      await productProvider.loadProducts();
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
