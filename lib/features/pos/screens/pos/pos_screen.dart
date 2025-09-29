import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../products/models/product.dart';
import '../../models/transaction.dart';
import '../../../products/providers/product_provider.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../view_models/pos_view_model.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import '../cart/cart_screen.dart';
import '../../../products/screens/products/product_detail_screen.dart';
import '../../../../shared/transitions/cupertino_page_route.dart';

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
    return GestureDetector(
      // Add swipe gesture for iOS-style back navigation
      onHorizontalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          // Swipe right detected, navigate back to home
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Bán Hàng (POS)'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _viewModel == null
          ? const Center(child: LoadingWidget())
          : Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: Padding(
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
                                  setState(() {}); // Refresh để ẩn nút clear
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (query) {
                        _viewModel!.searchProducts(query);
                        setState(() {}); // Refresh để hiện/ẩn nút clear
                      },
                    ),
                  ),
                ),
                _buildCategoryFilters(),
                Expanded(
                  child: _buildProductGrid(),
                ),
                if (_viewModel != null) _buildMiniCartFooter(),
              ],
            ),
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
            final quantityInCart = _viewModel!.getProductQuantityInCart(product.id);
            return GestureDetector(
              onLongPress: () {
                // Navigate trực tiếp với iOS transition
                _navigateToProductDetail(product);
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Icon(_getCategoryIcon(product.category), size: 32, color: _getCategoryColor(product.category)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 4),
                      Text(AppFormatter.formatCurrency(_viewModel!.productProvider.getCurrentPrice(product.id)), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 4),
                      Text('Tồn: ${AppFormatter.formatNumber(_viewModel!.productProvider.getProductStock(product.id))}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildQuantityStepper(product, quantityInCart),
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

  Widget _buildMiniCartFooter() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, -2))]),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(Icons.shopping_cart, size: 28, color: productProvider.cartItems.isEmpty ? Colors.grey[400] : Colors.green),
                  if (productProvider.cartItemsCount > 0)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('${productProvider.cartItemsCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(productProvider.cartItems.isEmpty ? 'Giỏ hàng trống' : '${productProvider.cartItemsCount} sản phẩm', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(AppFormatter.formatCurrency(productProvider.cartTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: productProvider.cartItems.isEmpty ? null : () async {
                  final needsRefresh = await context.pushiOS<bool>(const CartScreen());
                  if (needsRefresh == true) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green));
                    context.read<ProductProvider>().refresh();
                  }
                },
                child: const Text('Xem Giỏ Hàng'),
              ),
            ],
          ),
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
                  _viewModel?.filterProductsByCategory(selected ? category : null);
                },
                selectedColor: _getCategoryColor(category).withValues(alpha: 0.2),
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
              final currentStock = _viewModel?.productProvider.getProductStock(product.id) ?? 0;
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
    // Set selected product in provider before navigation
    context.read<ProductProvider>().selectProduct(product);

    // Navigate với enhanced iOS-style transition
    context.pushiOS(const ProductDetailScreen());
  }
}