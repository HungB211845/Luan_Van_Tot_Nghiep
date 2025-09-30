import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../products/models/product.dart';
import '../../models/payment_method.dart';
import '../../../products/providers/product_provider.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../view_models/pos_view_model.dart';
import '../../../../shared/widgets/loading_widget.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  POSViewModel? _viewModel;
  bool _isInitialized = false;
  final _searchController = TextEditingController();
  ProductCategory? _selectedCategory;
  bool _isProcessingPayment = false;
  int _selectedTab = 0; // 0: Products, 1: Invoice

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final productProvider = context.read<ProductProvider>();
      final customerProvider = context.read<CustomerProvider>();
      _viewModel = POSViewModel(
        productProvider: productProvider,
        customerProvider: customerProvider,
        transactionProvider: context.read<TransactionProvider>(),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel?.initialize();
      });

      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Bán Hàng (POS)'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _viewModel == null
          ? const Center(child: LoadingWidget())
          : _buildAdaptiveLayout(),
    );
  }

  Widget _buildAdaptiveLayout() {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

        // Use two-column layout for landscape or tablet
        if (isLandscape || isTablet) {
          return _buildTwoColumnLayout();
        }

        // Use tab-based layout for portrait mobile
        return _buildTabBasedLayout();
      },
    );
  }

  Widget _buildTwoColumnLayout() {
    return Row(
      children: [
        // Left Column - Products (60% width)
        Expanded(flex: 6, child: _buildProductColumn()),
        // Divider
        Container(width: 1, color: Colors.grey[300]),
        // Right Column - Invoice (40% width)
        Expanded(flex: 4, child: _buildInvoiceColumn()),
      ],
    );
  }

  Widget _buildTabBasedLayout() {
    return Column(
      children: [
        // Segmented Control
        _buildSegmentedControl(),

        // Content Area
        Expanded(
          child: _selectedTab == 0
              ? _buildProductColumn()
              : _buildInvoiceColumn(),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    final cartItemCount = context.watch<ProductProvider>().cartItemsCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 20,
                      color: _selectedTab == 0
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sản phẩm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _selectedTab == 0
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedTab == 0
                            ? Colors.green
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: _selectedTab == 1
                              ? Colors.green
                              : Colors.grey[600],
                        ),
                        if (cartItemCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '$cartItemCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cartItemCount > 0
                          ? 'Hóa đơn ($cartItemCount)'
                          : 'Hóa đơn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _selectedTab == 1
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _selectedTab == 1
                            ? Colors.green
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductColumn() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm hoặc quét sản phẩm...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _viewModel!.searchProducts('');
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (query) {
              _viewModel!.searchProducts(query);
              setState(() {});
            },
          ),
        ),

        // Category Filters
        _buildCategoryFilters(),

        // Product Grid
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildInvoiceColumn() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Customer Selection Header
          _buildCustomerHeader(),

          // Invoice Items List
          Expanded(child: _buildInvoiceItemsList()),

          // Total & Payment Section (combined for mobile)
          _buildTotalAndPaymentSection(),
        ],
      ),
    );
  }

  Widget _buildTotalAndPaymentSection() {
    final total = context.watch<ProductProvider>().cartTotal;
    final hasItems = _viewModel?.cartItems.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Total Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng cộng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Flexible(
                child: Text(
                  '${total.toStringAsFixed(0)} VND',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Payment Buttons Row
          Row(
            children: [
              // Main Cash Payment Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: hasItems && !_isProcessingPayment
                        ? () => _processPayment('cash')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isProcessingPayment
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang xử lý...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Thanh Toán Tiền Mặt',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Debt Payment Button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: hasItems && !_isProcessingPayment && _viewModel?.selectedCustomer != null
                        ? () => _processPayment('debt')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _viewModel?.selectedCustomer != null 
                          ? Colors.orange 
                          : Colors.grey[300],
                      foregroundColor: _viewModel?.selectedCustomer != null 
                          ? Colors.white 
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Ghi Nợ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Bank Transfer Button
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: hasItems && !_isProcessingPayment
                        ? () => _processPayment('bank')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Chuyển Khoản',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),


        ],
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: GestureDetector(
        onTap: _selectCustomer,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _viewModel?.selectedCustomer?.name ?? 'Khách lẻ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_viewModel?.selectedCustomer != null)
                    Text(
                      'Khách hàng',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemsList() {
    if (_viewModel?.cartItems.isEmpty ?? true) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Chưa có sản phẩm nào',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Chạm vào sản phẩm để thêm',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel!.cartItems.length,
      itemBuilder: (context, index) {
        final item = _viewModel!.cartItems[index];
        return _buildInvoiceItem(item, index);
      },
    );
  }

  Widget _buildInvoiceItem(CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.priceAtSale.toStringAsFixed(0)} VND',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Quantity Controls
          Row(
            children: [
              GestureDetector(
                onTap: () => _decreaseQuantity(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 16, color: Colors.grey),
                ),
              ),

              Container(
                width: 36,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              GestureDetector(
                onTap: () => _increaseQuantity(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Total Price
          Flexible(
            child: Text(
              '${item.subTotal.toStringAsFixed(0)} VND',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.products.isEmpty) {
          return const Center(child: LoadingWidget());
        }
        if (productProvider.products.isEmpty) {
          return const Center(child: Text('Không có sản phẩm nào'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: productProvider.products.length,
          itemBuilder: (context, index) {
            final product = productProvider.products[index];
            final quantityInCart = _viewModel!.getProductQuantityInCart(
              product.id,
            );
            return GestureDetector(
              onLongPress: () {
                // Navigate trực tiếp với iOS transition
                _navigateToProductDetail(product);
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Icon(
                        _getCategoryIcon(product.category),
                        size: 24,
                        color: _getCategoryColor(product.category),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        flex: 2,
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_viewModel!.productProvider.getCurrentPrice(product.id).toStringAsFixed(0)} VND',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Tồn: ${_viewModel!.productProvider.getProductStock(product.id)}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        flex: 1,
                        child: _buildQuantityStepper(product, quantityInCart),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            FilterChip(
              label: const Text('Tất cả'),
              selected: _selectedCategory == null,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = null;
                });
                _viewModel?.filterProductsByCategory(null);
              },
              selectedColor: Colors.green.withValues(alpha: 0.2),
              checkmarkColor: Colors.green,
            ),
            const SizedBox(width: 8),
            ...ProductCategory.values.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.displayName),
                  selected: _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                    _viewModel?.filterProductsByCategory(
                      selected ? category : null,
                    );
                  },
                  selectedColor: _getCategoryColor(
                    category,
                  ).withValues(alpha: 0.2),
                  checkmarkColor: _getCategoryColor(category),
                  avatar: Icon(
                    _getCategoryIcon(category),
                    size: 16,
                    color: _selectedCategory == category
                        ? _getCategoryColor(category)
                        : Colors.grey[600],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityStepper(Product product, int quantityInCart) {
    if (quantityInCart == 0) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: const Text('Thêm'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.green),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            _viewModel?.updateCartItemQuantity(product, 1);
          },
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              _viewModel?.updateCartItemQuantity(product, quantityInCart - 1);
            },
            icon: const Icon(Icons.remove, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
          ),
          Container(
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey[300]!),
                right: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Text(
              '$quantityInCart',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () {
              final currentStock =
                  _viewModel?.productProvider.getProductStock(product.id) ?? 0;
              if (quantityInCart < currentStock) {
                _viewModel?.updateCartItemQuantity(product, quantityInCart + 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không đủ hàng tồn kho'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  void _navigateToProductDetail(Product product) {
    // No longer needed - we add directly to cart
    _onProductTap(product);
  }

  void _switchTab(int index) {
    setState(() {
      _selectedTab = index;
    });
    HapticFeedback.selectionClick();
  }

  void _onProductTap(Product product) {
    // Add product to cart instantly - no navigation needed
    _viewModel?.addProductToCart(product, 1);
    setState(() {});

    // Haptic feedback for instant satisfaction
    HapticFeedback.lightImpact();

    // Auto-switch to invoice tab after adding product for better UX
    // Only on portrait mobile mode
    final orientation = MediaQuery.of(context).orientation;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    if (orientation == Orientation.portrait && !isTablet) {
      // Briefly switch to invoice tab to show the added item
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedTab = 1;
          });
        }
      });
    }
  }

  void _selectCustomer() async {
    // TODO: Implement customer selection
    // For now, just toggle between guest and a demo customer
    if (_viewModel?.selectedCustomer == null) {
      // Select a demo customer
      setState(() {
        // This would normally come from customer selection
      });
    } else {
      // Back to guest
      _viewModel?.selectedCustomer = null;
      setState(() {});
    }
  }

  void _increaseQuantity(int index) {
    final item = _viewModel?.cartItems[index];
    if (item != null) {
      context.read<ProductProvider>().updateCartItem(
        item.productId,
        item.quantity + 1,
      );
      setState(() {});
      HapticFeedback.lightImpact();
    }
  }

  void _decreaseQuantity(int index) {
    final item = _viewModel?.cartItems[index];
    if (item != null) {
      final newQuantity = item.quantity - 1;
      if (newQuantity > 0) {
        context.read<ProductProvider>().updateCartItem(
          item.productId,
          newQuantity,
        );
      } else {
        context.read<ProductProvider>().removeFromCart(item.productId);
      }
      setState(() {});
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _processPayment(String method) async {
    try {
      final productProvider = context.read<ProductProvider>();
      // Validate cart has items
      if (productProvider.cartItems.isEmpty) {
        _showError('Giỏ hàng trống, không thể thanh toán');
        return;
      }

      // Determine payment method
      final paymentMethod = method == 'cash'
          ? PaymentMethod.cash
          : method == 'debt'
          ? PaymentMethod.debt
          : PaymentMethod.bankTransfer;
      final isDebt = method == 'debt';

      // Validate debt payment for guest customer
      if (isDebt && (_viewModel?.selectedCustomer == null)) {
        _showError('Không thể ghi nợ cho khách lẻ. Vui lòng chọn khách hàng.');
        return;
      }

      // Show loading indicator
      _showProcessingIndicator();

      // Process payment through ProductProvider checkout
      final transactionId = await productProvider.checkout(
        customerId: _viewModel?.selectedCustomer?.id,
        paymentMethod: paymentMethod,
        isDebt: isDebt,
        notes: 'POS Transaction - ${method.toUpperCase()}',
      );

      // Hide loading indicator
      _hideProcessingIndicator();

      if (transactionId != null && transactionId.isNotEmpty) {
        // Success - process completed transaction
        await _handleSuccessfulPayment(transactionId, method, paymentMethod);
      } else {
        // Payment failed
        _showError(
          productProvider.errorMessage.isNotEmpty
              ? productProvider.errorMessage
              : 'Có lỗi xảy ra khi thanh toán. Vui lòng thử lại.',
        );


      }
    } catch (e) {
      // Hide loading indicator
      _hideProcessingIndicator();

      _showError('Lỗi không mong muốn: ${e.toString()}');
    }
  }

  Future<void> _handleSuccessfulPayment(
    String transactionId,
    String method,
    PaymentMethod paymentMethod,
  ) async {
    try {
      // Update transaction provider with the new transaction
      final transactionProvider = context.read<TransactionProvider>();
      await transactionProvider.refresh();

      // Success feedback
      HapticFeedback.lightImpact();

      // Navigate to Transaction Success Screen
      await Navigator.pushNamed(
        context, 
        '/transaction-success',
        arguments: transactionId,
      );

      // After returning from success screen, reset POS for next customer
      _resetForNextCustomer();
      
    } catch (e) {
      // Even if transaction provider update fails, the payment was successful
      // Navigate to success screen anyway
      await Navigator.pushNamed(
        context, 
        '/transaction-success',
        arguments: transactionId,
      );
      
      _resetForNextCustomer();
    }
  }

  void _resetForNextCustomer() {
    setState(() {
      _selectedTab = 0; // Switch back to products tab
      // Reset customer selection to guest
      if (_viewModel != null) {
        _viewModel!.selectedCustomer = null;
      }
    });
  }

  void _showProcessingIndicator() {
    setState(() {
      _isProcessingPayment = true;
    });
  }

  void _hideProcessingIndicator() {
    setState(() {
      _isProcessingPayment = false;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Đóng',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }


}
