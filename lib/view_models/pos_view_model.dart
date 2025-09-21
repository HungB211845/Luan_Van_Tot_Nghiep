// lib/view_models/pos_view_model.dart
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';

class POSViewModel {
  final ProductProvider productProvider;
  final CustomerProvider customerProvider;

  // State cục bộ cho màn hình POS
  Customer? selectedCustomer;

  POSViewModel({
    required this.productProvider,
    required this.customerProvider,
  });

  // Hàm khởi tạo, tải các dữ liệu cần thiết
  Future<void> initialize() async {
    // Tải danh sách sản phẩm và khách hàng nếu cần
    if (productProvider.products.isEmpty) {
      await productProvider.loadProducts();
    }
    if (customerProvider.customers.isEmpty) {
      await customerProvider.loadCustomers();
    }
  }

  // Xử lý khi quét mã vạch
  Future<void> handleBarcodeScan(String sku) async {
    final product = await productProvider.scanBarcode(sku);
    if (product != null) {
      productProvider.addToCart(product, 1);
    } else {
      // Có thể xử lý báo lỗi "không tìm thấy sản phẩm" ở đây
    }
  }

  // Gán khách hàng vào đơn hàng
  void selectCustomer(Customer customer) {
    selectedCustomer = customer;
  }

  // Xử lý thanh toán cuối cùng
  Future<String?> handleCheckout({
    required PaymentMethod paymentMethod,
    bool isDebt = false,
    String? notes,
  }) async {
    // Gọi thẳng hàm checkout của ProductProvider với customerId đã chọn
    return await productProvider.checkout(
      customerId: selectedCustomer?.id,
      paymentMethod: paymentMethod,
      isDebt: isDebt,
      notes: notes,
    );
  }

  // === THÊM CÁC HELPER METHODS CHO UI ===

  // Tìm kiếm sản phẩm
  Future<void> searchProducts(String query) async {
    await productProvider.searchProducts(query);
  }

  // Tìm kiếm khách hàng
  Future<void> searchCustomers(String query) async {
    await customerProvider.searchCustomers(query);
  }

  // Thêm sản phẩm vào giỏ hàng với số lượng tùy chỉnh
  void addProductToCart(Product product, int quantity) {
    productProvider.addToCart(product, quantity);
  }

  // Hàm này cần nhận cả object Product để có thể thêm mới nếu cần
  void updateCartItemQuantity(Product product, int newQuantity) {
    if (newQuantity <= 0) {
      // Nếu số lượng mới là 0 hoặc âm, xóa khỏi giỏ hàng
      productProvider.removeFromCart(product.id);
      return;
    }

    // Kiểm tra xem sản phẩm đã có trong giỏ chưa
    final index = productProvider.cartItems.indexWhere((item) => item.productId == product.id);

    if (index != -1) {
      // Nếu ĐÃ CÓ, gọi hàm cập nhật
      productProvider.updateCartItem(product.id, newQuantity);
    } else {
      // Nếu CHƯA CÓ (tức là đang thêm từ 0 lên 1), gọi hàm thêm mới
      productProvider.addToCart(product, newQuantity);
    }
  }

  // Xóa item khỏi giỏ hàng
  void removeFromCart(String productId) {
    productProvider.removeFromCart(productId);
  }

  // Xóa toàn bộ giỏ hàng
  void clearCart() {
    productProvider.clearCart();
    selectedCustomer = null; // Reset customer selection
  }

  // Hủy chọn khách hàng
  void clearCustomerSelection() {
    selectedCustomer = null;
  }

  // === GETTERS CHO UI ===

  // Lấy danh sách sản phẩm
  List<Product> get products => productProvider.products;

  // Lấy danh sách khách hàng
  List<Customer> get customers => customerProvider.customers;

  // Lấy giỏ hàng
  List<CartItem> get cartItems => productProvider.cartItems;

  // Lấy tổng tiền
  double get cartTotal => productProvider.cartTotal;

  // Lấy số lượng items trong giỏ
  int get cartItemsCount => productProvider.cartItemsCount;

  // Kiểm tra trạng thái loading
  bool get isLoading => productProvider.isLoading || customerProvider.isLoading;

  // Kiểm tra có lỗi không
  bool get hasError => productProvider.hasError || customerProvider.hasError;

  // Lấy thông báo lỗi
  String get errorMessage {
    if (productProvider.hasError) return productProvider.errorMessage;
    if (customerProvider.hasError) return customerProvider.errorMessage;
    return '';
  }

  // Kiểm tra giỏ hàng có trống không
  bool get isCartEmpty => cartItems.isEmpty;

  // Lấy thông tin khách hàng đã chọn
  String get selectedCustomerName => selectedCustomer?.name ?? 'Khách lẻ';

  // === VALIDATION METHODS ===

  // Kiểm tra có thể checkout không
  bool canCheckout() {
    return cartItems.isNotEmpty && !isLoading;
  }

  // Validate trước khi checkout
  String? validateCheckout() {
    if (cartItems.isEmpty) {
      return 'Giỏ hàng trống';
    }

    // Kiểm tra tồn kho cho từng item
    for (final item in cartItems) {
      final stock = productProvider.getProductStock(item.productId);
      if (stock < item.quantity) {
        return 'Sản phẩm "${item.productName}" không đủ hàng tồn kho';
      }
    }

    return null; // No error
  }

  // === REFRESH METHODS ===

  // Refresh toàn bộ data
  Future<void> refresh() async {
    await Future.wait([
      productProvider.refresh(),
      customerProvider.refresh(),
    ]);
  }

  // Refresh chỉ sản phẩm
  Future<void> refreshProducts() async {
    await productProvider.loadProducts();
  }

  // Refresh chỉ khách hàng
  Future<void> refreshCustomers() async {
    await customerProvider.loadCustomers();
  }

  // === CATEGORY FILTERING ===

  // Filter products by category
  Future<void> filterProductsByCategory(ProductCategory? category) async {
    await productProvider.filterByCategory(category);
  }

  // Get quantity of product in cart
  int getProductQuantityInCart(String productId) {
    final cartItem = cartItems.firstWhere(
      (item) => item.productId == productId,
      orElse: () => CartItem(
        productId: '',
        productName: '',
        productSku: '',
        quantity: 0,
        priceAtSale: 0,
        subTotal: 0,
      ),
    );
    return cartItem.quantity;
  }
}