import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../products/models/product.dart';
import '../../models/payment_method.dart';
import '../../../products/providers/product_provider.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../view_models/pos_view_model.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../core/routing/route_names.dart';
import '../../../customers/models/customer.dart';
import '../../../customers/screens/customers/customer_list_screen.dart';
import 'confirm_credit_sale_sheet.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({Key? key}) : super(key: key);

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with SingleTickerProviderStateMixin {
  POSViewModel? _viewModel;
  bool _isInitialized = false;
  final _searchController = TextEditingController();
  ProductCategory? _selectedCategory;
  bool _isProcessingPayment = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_handleTabSelection);
    _searchController.addListener(() {
        _viewModel?.searchProducts(_searchController.text);
        setState(() {});
    });
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
      setState(() {});
      HapticFeedback.selectionClick();
    }
  }

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
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
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
    // Material Design breakpoints:
    // - Mobile: < 600px (tabs)
    // - Tablet: 600-1200px (2-column 6:4)
    // - Desktop: > 1200px (2-column 7:3)
    const double tabletBreakpoint = 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletBreakpoint) {
          // Tablet or Desktop layout: side-by-side
          return _buildTwoColumnLayout(constraints.maxWidth);
        }
        // Mobile layout: tabs
        return _buildTabBasedLayout();
      },
    );
  }

  Widget _buildTwoColumnLayout(double screenWidth) {
    // Adjust ratio based on screen width
    // Tablet (600-1200): 6:4 ratio (60% products, 40% invoice)
    // Desktop (>1200): 7:3 ratio (70% products, 30% invoice)
    const double desktopBreakpoint = 1200;
    final isDesktop = screenWidth >= desktopBreakpoint;
    final productFlex = isDesktop ? 7 : 6;
    final invoiceFlex = isDesktop ? 3 : 4;

    return Row(
      children: [
        Expanded(
          flex: productFlex,
          child: _buildProductColumn(),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: invoiceFlex,
          child: _buildInvoiceColumn(),
        ),
      ],
    );
  }

  Widget _buildTabBasedLayout() {
    return Column(
      children: [
        _buildCustomTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductColumn(),
              _buildInvoiceColumn(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTabBar() {
    final cartItemCount = context.watch<ProductProvider>().cartItemsCount;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_view_rounded, size: 20, color: _tabController?.index == 0 ? Colors.green : Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Sản phẩm', style: TextStyle(fontSize: 16, fontWeight: _tabController?.index == 0 ? FontWeight.w600 : FontWeight.w500, color: _tabController?.index == 0 ? Colors.green : Colors.grey[600])),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.receipt_long, size: 20, color: _tabController?.index == 1 ? Colors.green : Colors.grey[600]),
                    if (cartItemCount > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text('$cartItemCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text('Hóa đơn', style: TextStyle(fontSize: 16, fontWeight: _tabController?.index == 1 ? FontWeight.w600 : FontWeight.w500, color: _tabController?.index == 1 ? Colors.green : Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductColumn() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm hoặc quét sản phẩm...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        _buildCategoryFilters(),
        Expanded(child: _buildProductGrid()),
      ],
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: _selectedCategory == null,
            onSelected: (selected) {
              setState(() => _selectedCategory = null);
              _viewModel?.filterProductsByCategory(null);
            },
            selectedColor: Colors.green.withOpacity(0.2),
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
                  setState(() => _selectedCategory = selected ? category : null);
                  _viewModel?.filterProductsByCategory(selected ? category : null);
                },
                selectedColor: Colors.green.withOpacity(0.2),
                checkmarkColor: Colors.green,
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // REBUILT to use 3 columns and new aspect ratio
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
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 3 columns
            childAspectRatio: 0.8, // Make cards more square
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: productProvider.products.length,
          itemBuilder: (context, index) {
            final product = productProvider.products[index];
            final quantityInCart = _viewModel!.getProductQuantityInCart(product.id);
            return _buildProductCard(product, quantityInCart);
          },
        );
      },
    );
  }

  // NEW, REFACTORED PRODUCT CARD
  Widget _buildProductCard(Product product, int quantityInCart) {
    final bool inCart = quantityInCart > 0;
    final stock = _viewModel!.productProvider.getProductStock(product.id);
    final bool isLowStock = stock <= (product.minStockLevel ?? 10);

    return GestureDetector(
      onTap: () {
        _viewModel?.updateCartItemQuantity(product, quantityInCart + 1);
        HapticFeedback.lightImpact();
      },
      onLongPress: () {
        if (inCart) {
          _viewModel?.updateCartItemQuantity(product, 0);
          HapticFeedback.heavyImpact();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inCart ? Colors.green : Colors.grey[200]!,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 40),
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppFormatter.formatCurrency(_viewModel!.productProvider.getCurrentPrice(product.id)),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            // Quantity Badge (top-right)
            if (inCart)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: Text(
                    '$quantityInCart',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            // Low Stock Badge (top-left)
            if (isLowStock && !inCart) // Only show if not already in cart to avoid clutter
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'Tồn: $stock',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceColumn() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          _buildCustomerHeader(),
          Expanded(child: _buildInvoiceItemsList()),
          _buildTotalAndPaymentSection(),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return GestureDetector(
      onTap: _selectCustomer,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.green, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_viewModel?.selectedCustomer?.name ?? 'Khách lẻ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (_viewModel?.selectedCustomer != null) Text('Khách hàng', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _selectCustomer() async {
    final selectedCustomer = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(builder: (context) => const CustomerListScreen(isSelectionMode: true)),
    );
    if (selectedCustomer != null) {
      setState(() => _viewModel?.selectedCustomer = selectedCustomer);
    }
  }

  Widget _buildInvoiceItemsList() {
    if (_viewModel?.cartItems.isEmpty ?? true) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có sản phẩm nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(AppFormatter.formatCurrency(item.priceAtSale), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => _decreaseQuantity(index),
                child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: const Icon(Icons.remove, size: 16, color: Colors.grey)),
              ),
              Container(width: 36, alignment: Alignment.center, child: Text('${item.quantity}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              GestureDetector(
                onTap: () => _increaseQuantity(index),
                child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.add, size: 16, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _increaseQuantity(int index) {
    final item = _viewModel?.cartItems[index];
    if (item != null) {
      context.read<ProductProvider>().updateCartItem(item.productId, item.quantity + 1);
    }
  }

  void _decreaseQuantity(int index) {
    final item = _viewModel?.cartItems[index];
    if (item != null) {
      context.read<ProductProvider>().updateCartItem(item.productId, item.quantity - 1);
    }
  }

  Widget _buildTotalAndPaymentSection() {
    final total = context.watch<ProductProvider>().cartTotal;
    final hasItems = _viewModel?.cartItems.isNotEmpty ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[300]!))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              Flexible(child: Text(AppFormatter.formatCurrency(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasItems && !_isProcessingPayment ? _showPaymentActionSheet : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, disabledBackgroundColor: Colors.grey[300], disabledForegroundColor: Colors.grey[500]),
              child: _isProcessingPayment
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))), SizedBox(width: 12), Text('Đang xử lý...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])
                  : const Text('Thanh Toán', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentActionSheet() {
    final customerName = _viewModel?.selectedCustomer?.name ?? 'Khách lẻ';
    final hasCustomer = _viewModel?.selectedCustomer != null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text('Chọn phương thức thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
              const Divider(height: 1),
              _buildPaymentOption(icon: Icons.money, title: 'Tiền mặt', color: Colors.green, onTap: () { Navigator.pop(context); _processPayment('cash'); }),
              _buildPaymentOption(icon: Icons.credit_card, title: hasCustomer ? 'Ghi nợ cho $customerName' : 'Ghi nợ (Chọn khách hàng trước)', color: Colors.orange, enabled: hasCustomer, onTap: hasCustomer ? () { Navigator.pop(context); _showCreditSaleConfirmation(); } : null),
              _buildPaymentOption(icon: Icons.account_balance, title: 'Chuyển khoản', color: Colors.blue, onTap: () { Navigator.pop(context); _processPayment('bank'); }),
              const Divider(height: 1),
              InkWell(onTap: () => Navigator.pop(context), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), child: const Text('Hủy', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red)))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({required IconData icon, required String title, required Color color, bool enabled = true, VoidCallback? onTap}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: enabled ? color.withOpacity(0.1) : Colors.grey[100], shape: BoxShape.circle), child: Icon(icon, color: enabled ? color : Colors.grey[400], size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: enabled ? Colors.black87 : Colors.grey[400]))),
            if (enabled) Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(String method) async {
    if (!mounted) return;
    final productProvider = context.read<ProductProvider>();
    if (productProvider.cartItems.isEmpty) {
      _showError('Giỏ hàng trống, không thể thanh toán');
      return;
    }
    final paymentMethod = method == 'cash' ? PaymentMethod.cash : (method == 'debt' ? PaymentMethod.debt : PaymentMethod.bankTransfer);
    if (paymentMethod == PaymentMethod.debt && _viewModel?.selectedCustomer == null) {
      _showError('Không thể ghi nợ cho khách lẻ. Vui lòng chọn khách hàng.');
      return;
    }
    setState(() => _isProcessingPayment = true);
    try {
      final transactionId = await productProvider.checkout(
        customerId: _viewModel?.selectedCustomer?.id,
        paymentMethod: paymentMethod,
        isDebt: paymentMethod == PaymentMethod.debt,
      );
      if (transactionId != null) {
        await _handleSuccessfulPayment(transactionId);
      } else {
        _showError(productProvider.errorMessage.isNotEmpty ? productProvider.errorMessage : 'Lỗi không xác định');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _handleSuccessfulPayment(String transactionId) async {
    if (!mounted) return;
    await HapticFeedback.heavyImpact();
    await Navigator.of(context, rootNavigator: true).pushNamed(
      RouteNames.transactionSuccess,
      arguments: transactionId,
    );
    if (mounted) {
      _resetForNextCustomer();
      context.read<ProductProvider>().loadProducts();
      context.read<TransactionProvider>().loadTransactions();
    }
  }

  void _resetForNextCustomer() {
    context.read<ProductProvider>().clearCart();
    if (mounted) {
      setState(() {
        _viewModel?.selectedCustomer = null;
        _tabController?.animateTo(0);
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showCreditSaleConfirmation() {
    final customer = _viewModel?.selectedCustomer;
    if (customer == null) {
      _showError('Không có khách hàng được chọn');
      return;
    }

    final productProvider = context.read<ProductProvider>();
    final baseAmount = productProvider.cartTotal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmCreditSaleSheet(
        customer: customer,
        baseAmount: baseAmount,
        onCancel: () => Navigator.pop(context),
        onConfirm: (surchargeAmount) {
          Navigator.pop(context);
          _processCreditSaleWithSurcharge(customer.id, surchargeAmount);
        },
      ),
    );
  }

  Future<void> _processCreditSaleWithSurcharge(String customerId, double surchargeAmount) async {
    if (!mounted) return;
    final productProvider = context.read<ProductProvider>();
    if (productProvider.cartItems.isEmpty) {
      _showError('Giỏ hàng trống, không thể thanh toán');
      return;
    }

    setState(() => _isProcessingPayment = true);
    try {
      final transactionId = await productProvider.finalizeCreditSaleWithSurcharge(
        customerId: customerId,
        surchargeAmount: surchargeAmount,
      );

      if (transactionId != null) {
        await _handleSuccessfulPayment(transactionId);
      } else {
        _showError(productProvider.errorMessage.isNotEmpty ? productProvider.errorMessage : 'Lỗi không xác định');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }
}
