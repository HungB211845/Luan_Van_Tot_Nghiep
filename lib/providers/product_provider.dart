import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/seasonal_price.dart';
import '../models/banned_substance.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../models/company.dart';
import '../services/product_service.dart';

enum ProductStatus { idle, loading, success, error }

class ProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();

  // =====================================================
  // STATE VARIABLES
  // =====================================================

  // Products
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  Product? _selectedProduct;
  ProductCategory? _selectedCategory;
  String _searchQuery = '';

  // Batches & Inventory
  List<ProductBatch> _productBatches = [];
  Map<String, int> _stockMap = {}; // productId -> available stock
  List<Map<String, dynamic>> _expiringBatches = [];
  List<Map<String, dynamic>> _lowStockProducts = [];

  // Pricing
  List<SeasonalPrice> _seasonalPrices = [];
  Map<String, double> _currentPrices = {}; // productId -> current price

  // Banned Substances
  List<BannedSubstance> _bannedSubstances = [];

  // Companies
  List<Company> _companies = [];

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
  List<TransactionItem> _activeTransactionItems = [];
  // ============================

  // =====================================================
  // GETTERS
  // =====================================================

  List<Product> get products => _filteredProducts.isEmpty && _searchQuery.isEmpty
      ? _products
      : _filteredProducts;

  Product? get selectedProduct => _selectedProduct;
  ProductCategory? get selectedCategory => _selectedCategory;
  List<ProductBatch> get productBatches => _productBatches;
  List<SeasonalPrice> get seasonalPrices => _seasonalPrices;
  List<BannedSubstance> get bannedSubstances => _bannedSubstances;
  List<Company> get companies => _companies;

  // Cart getters
  List<CartItem> get cartItems => _cartItems;
  double get cartTotal => _cartTotal;
  int get cartItemsCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);

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
  List<TransactionItem> get activeTransactionItems => _activeTransactionItems;
  // ============================

  // Utility getters
  int getProductStock(String productId) => _stockMap[productId] ?? 0;
  double getCurrentPrice(String productId) => _currentPrices[productId] ?? 0.0;

  // =====================================================
  // PRODUCT OPERATIONS
  // =====================================================

  Future<void> loadProducts({ProductCategory? category}) async {
    _setStatus(ProductStatus.loading);
    try {
      // 1. Lấy danh sách sản phẩm (đã có sẵn stock và price từ view)
      _products = await _productService.getProducts(category: category);
      _selectedCategory = category;

      // 2. Nạp dữ liệu vào _stockMap và _currentPrices từ danh sách vừa lấy
      //    Không cần gọi thêm API nào nữa!
      for (final product in _products) {
        _stockMap[product.id] = product.availableStock ?? 0;
        _currentPrices[product.id] = product.currentPrice ?? 0.0;
      }

      // 3. Xóa bộ lọc cũ (nếu có)
      _filteredProducts = [];
      _searchQuery = '';

      _setStatus(ProductStatus.success);
      _clearError();
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
  // INVENTORY & BATCH OPERATIONS
  // =====================================================

  Future<void> loadProductBatches(String productId) async {
    _setStatus(ProductStatus.loading);
    try {
      _productBatches = await _productService.getProductBatches(productId);
      notifyListeners();
      _setStatus(ProductStatus.success);
      _clearError();
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
      _lowStockProducts = await _productService.getLowStockProducts();
      notifyListeners();
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

      // Reload current price for this product
      final currentPrice = await _productService.getCurrentPrice(productId);
      _currentPrices[productId] = currentPrice;

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
    final existingIndex = _cartItems.indexWhere((item) => item.productId == product.id);

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
      _cartItems.add(CartItem(
        productId: product.id,
        productName: product.name,
        productSku: product.sku,
        quantity: quantity,
        priceAtSale: price,
        subTotal: quantity * price,
      ));
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
    PaymentMethod paymentMethod = PaymentMethod.CASH,
    bool isDebt = false,
    String? notes,
  }) async {
    if (_cartItems.isEmpty) {
      _setError('Giỏ hàng trống');
      return null;
    }

    _setStatus(ProductStatus.loading);

    try {
      // Convert cart items to transaction items
      final transactionItems = _cartItems.map((cartItem) => TransactionItem(
        id: '', // Will be generated by database
        transactionId: '', // Will be set by service
        productId: cartItem.productId,
        batchId: null, // Service will handle FIFO selection
        quantity: cartItem.quantity,
        priceAtSale: cartItem.priceAtSale,
        subTotal: cartItem.subTotal,
        createdAt: DateTime.now(),
      )).toList();

      final transactionId = await _productService.createTransaction(
        customerId: customerId,
        items: transactionItems,
        paymentMethod: paymentMethod,
        isDebt: isDebt,
        notes: notes,
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
      _activeTransaction = await _productService.getTransactionById(transactionId);
    if (_activeTransaction == null) {
      throw Exception('Không tìm thấy giao dịch. Vui lòng thử lại.');
    }
    _activeTransactionItems = await _productService.getTransactionItems(transactionId);
    _setStatus(ProductStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // =====================================================
  // COMPANY OPERATIONS
  // =====================================================

  /// Hàm để tải danh sách nhà cung cấp
  Future<void> loadCompanies() async {
    // Không cần set status loading vì đây là tác vụ nền, không cần block UI
    try {
      _companies = await _productService.getCompanies();
      // Thông báo cho các widget đang lắng nghe rằng có dữ liệu mới
      notifyListeners();
    } catch (e) {
      // Nếu có lỗi, cập nhật trạng thái lỗi chung
      _setError(e.toString());
    }
  }

  // =====================================================
  // DASHBOARD & ANALYTICS
  // =====================================================

  Future<void> loadDashboardStats() async {
    try {
      _dashboardStats = await _productService.getDashboardStats();
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

  void _calculateCartTotal() {
    _cartTotal = _cartItems.fold(0.0, (sum, item) => sum + item.subTotal);
  }

  void _setStatus(ProductStatus status) {
    _status = status;
    notifyListeners();
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
  // REFRESH & RELOAD
  // =====================================================

  Future<void> refresh() async {
    await loadProducts(category: _selectedCategory);
    await loadAlerts();
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
}

// =====================================================
// CART ITEM MODEL
// =====================================================

class CartItem {
  final String productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double priceAtSale;
  final double subTotal;
  final double discountAmount;

  CartItem({
    required this.productId,
    required this.productName,
    required this.productSku,
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

