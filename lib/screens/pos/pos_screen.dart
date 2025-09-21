import 'package:flutter/material.dart';
import '../../models/product.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../../view_models/pos_view_model.dart';
import '../../widgets/loading_widget.dart';
import '../cart/cart_screen.dart';

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
      );
      
      // Dùng addPostFrameCallback để đảm bảo việc tải dữ liệu
      // chỉ bắt đầu SAU KHI frame đầu tiên đã được build xong.
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

  void _onBarcodeScanned(String sku) {
    if (sku.trim().isEmpty || _viewModel == null) return;
    _viewModel!.handleBarcodeScan(sku.trim());
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Bán Hàng (POS)'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _viewModel == null
          ? const Center(child: LoadingWidget()) // Hiển thị loading trong khi viewModel đang được khởi tạo
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm hoặc quét sản phẩm...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (query) {
                      _viewModel!.searchProducts(query);
                    },
                  ),
                ),
                _buildCategoryFilters(),
                Expanded(
                  child: _buildProductGrid(),
                ),
              ],
            ),
      bottomNavigationBar: _viewModel == null ? null : _buildMiniCartFooter(),
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
            return Card(
              child: Column(
                children: [
                  Icon(_getCategoryIcon(product.category), size: 32, color: _getCategoryColor(product.category)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${_viewModel!.productProvider.getCurrentPrice(product.id).toStringAsFixed(0)}đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  Text('Tồn: ${_viewModel!.productProvider.getProductStock(product.id)}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  _buildQuantityStepper(product, quantityInCart),
                ],
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
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2))]),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(Icons.shopping_cart, size: 28, color: productProvider.cartItems.isEmpty ? Colors.grey[400] : Theme.of(context).primaryColor),
                  if (productProvider.cartItemsCount > 0)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('${productProvider.cartItemsCount}', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
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
                    Text('${productProvider.cartTotal.toStringAsFixed(0)}đ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: productProvider.cartItems.isEmpty ? null : () async {
                  final needsRefresh = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const CartScreen()));
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
              setState(() {
                _selectedCategory = null;
              });
              _viewModel?.filterProductsByCategory(null);
            },
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
            checkmarkColor: Theme.of(context).primaryColor,
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
                selectedColor: _getCategoryColor(category).withOpacity(0.2),
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
    );
  }

  Widget _buildQuantityStepper(Product product, int quantityInCart) {
    // Nếu chưa có trong giỏ hàng, hiển thị nút "Thêm"
    if (quantityInCart == 0) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_shopping_cart, size: 16),
          label: const Text('Thêm'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).primaryColor),
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

    // Nếu đã có trong giỏ hàng, hiển thị cụm nút +/- 
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
          // Nút Trừ
          IconButton(
            onPressed: () {
              _viewModel?.updateCartItemQuantity(product, quantityInCart - 1);
            },
            icon: const Icon(Icons.remove, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30),
          ),

          // Số lượng
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

          // Nút Cộng
          IconButton(
            onPressed: () {
              final currentStock = _viewModel?.productProvider.getProductStock(product.id) ?? 0;
              if (quantityInCart < currentStock) {
                _viewModel?.updateCartItemQuantity(product, quantityInCart + 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không đủ hàng tồn kho'),
                    backgroundColor: Colors.orange,
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
    // ... Giữ nguyên implementation
    return Icons.eco;
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
}
