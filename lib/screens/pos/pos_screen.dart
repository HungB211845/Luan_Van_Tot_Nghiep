// lib/screens/pos/pos_screen.dart
import 'package:flutter/material.dart';
import '../../models/product.dart';
import 'package:provider/provider.dart';
//import '../../models/customer.dart';
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
  late POSViewModel _viewModel;
  bool _isInitializing = true;
  final _searchController = TextEditingController();
  ProductCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Khởi tạo ViewModel
    _viewModel = POSViewModel(
      productProvider: context.read<ProductProvider>(),
      customerProvider: context.read<CustomerProvider>(),
    );

    // Tải dữ liệu ban đầu
    _viewModel.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onBarcodeScanned(String sku) {
    if (sku.trim().isEmpty) return;
    _viewModel.handleBarcodeScan(sku.trim());
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán Hàng (POS)'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing
          ? const LoadingWidget()
          : Column(
              children: [
                // Phần 1: TextField tìm kiếm sản phẩm
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (query) {
                      _viewModel.searchProducts(query);
                    },
                  ),
                ),
                // Phần 2: Bộ lọc danh mục
                _buildCategoryFilters(),
                // Phần 3: Grid sản phẩm với Expanded
                Expanded(
                  child: _buildProductGrid(),
                ),
              ],
            ),
      bottomNavigationBar: _buildMiniCartFooter(),
    );
  }

  // Lưới sản phẩm
  Widget _buildProductGrid() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Không có sản phẩm nào'),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Giảm từ 3 xuống 2 cột cho mobile
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: productProvider.products.length,
          itemBuilder: (context, index) {
            final product = productProvider.products[index];
            final quantityInCart = _viewModel.getProductQuantityInCart(product.id);

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Icon category
                    Icon(
                      _getCategoryIcon(product.category),
                      size: 32,
                      color: _getCategoryColor(product.category),
                    ),
                    const SizedBox(height: 8),
                    // Tên sản phẩm
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Giá bán
                    Text(
                      '${_viewModel.productProvider.getCurrentPrice(product.id).toStringAsFixed(0)}đ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Số tồn kho
                    Text(
                      'Tồn: ${_viewModel.productProvider.getProductStock(product.id)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quantity Stepper (Shopee-style)
                    _buildQuantityStepper(product, quantityInCart),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Mini-cart footer cho mobile
  Widget _buildMiniCartFooter() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Biểu tượng giỏ hàng với badge
              Stack(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: 28,
                    color: productProvider.cartItems.isEmpty
                        ? Colors.grey[400]
                        : Theme.of(context).primaryColor,
                  ),
                  if (productProvider.cartItemsCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${productProvider.cartItemsCount}',
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
              const SizedBox(width: 12),
              // Thông tin tổng tiền
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      productProvider.cartItems.isEmpty
                          ? 'Giỏ hàng trống'
                          : '${productProvider.cartItemsCount} sản phẩm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${productProvider.cartTotal.toStringAsFixed(0)}đ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              // Nút xem giỏ hàng
              ElevatedButton(
                onPressed: productProvider.cartItems.isEmpty
                    ? null
                    : () async { // Thêm async
                        // Chờ kết quả trả về từ CartScreen
                        final needsRefresh = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );

                        // Sau khi CartScreen đóng lại và trả về kết quả
                        if (needsRefresh == true) {
                          // 1. HIỂN THỊ THÔNG BÁO THÀNH CÔNG
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thanh toán thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // 2. LÀM MỚI DỮ LIỆU Ở BACKGROUND
                          context.read<ProductProvider>().loadProducts();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text('Xem Giỏ Hàng'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Hiển thị hộp thoại xác nhận thanh toán
  void _showCheckoutDialog() {
    // Dùng StatefulBuilder để quản lý trạng thái chọn lựa bên trong dialog
    PaymentMethod selectedPaymentMethod = PaymentMethod.CASH;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Xác nhận thanh toán'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khách hàng: ${_viewModel.selectedCustomer?.name ?? "Khách lẻ"}'),
                  const SizedBox(height: 8),
                  Text(
                    'Tổng tiền: ${context.read<ProductProvider>().cartTotal.toStringAsFixed(0)}đ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(height: 24),
                  const Text('Chọn phương thức thanh toán:', style: TextStyle(fontWeight: FontWeight.w500)),
                  RadioListTile<PaymentMethod>(
                    title: const Text('Tiền mặt'),
                    value: PaymentMethod.CASH,
                    groupValue: selectedPaymentMethod,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedPaymentMethod = value!;
                      });
                    },
                  ),
                  RadioListTile<PaymentMethod>(
                    title: const Text('Ghi nợ'),
                    value: PaymentMethod.DEBT,
                    groupValue: selectedPaymentMethod,
                    // Chỉ cho phép ghi nợ nếu đã chọn khách hàng
                    onChanged: _viewModel.selectedCustomer != null ? (value) {
                      setDialogState(() {
                        selectedPaymentMethod = value!;
                      });
                    } : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext); // Đóng dialog trước
                    _viewModel.handleCheckout(
                      paymentMethod: selectedPaymentMethod,
                      isDebt: selectedPaymentMethod == PaymentMethod.DEBT,
                    ).then((transactionId) {
                      if (!mounted) return;
                      if (transactionId != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: ${context.read<ProductProvider>().errorMessage}'), backgroundColor: Colors.red),
                        );
                      }
                    });
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog chọn khách hàng
  void _showCustomerSelectionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Chọn khách hàng'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Consumer<CustomerProvider>(
              builder: (context, customerProvider, child) {
                if (customerProvider.customers.isEmpty) {
                  return const Center(
                    child: Text('Không có khách hàng nào'),
                  );
                }

                return ListView.builder(
                  itemCount: customerProvider.customers.length,
                  itemBuilder: (context, index) {
                    final customer = customerProvider.customers[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(customer.name),
                      subtitle: Text(customer.phone ?? ''),
                      onTap: () {
                        setState(() {
                          _viewModel.selectCustomer(customer);
                        });
                        Navigator.pop(dialogContext);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
          ],
        );
      },
    );
  }

  // Helper functions cho category icons và colors
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

  // Widget bộ lọc danh mục
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
              _viewModel.filterProductsByCategory(null);
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
                  _viewModel.filterProductsByCategory(selected ? category : null);
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

  // Widget điều khiển số lượng theo kiểu Shopee
  Widget _buildQuantityStepper(Product product, int quantityInCart) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút giảm
          InkWell(
            onTap: quantityInCart > 0 ? () {
              // Truyền vào cả object product thay vì chỉ product.id
              _viewModel.updateCartItemQuantity(product, quantityInCart - 1);
            } : null,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: quantityInCart > 0 ? Colors.grey[100] : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Icon(
                Icons.remove,
                size: 16,
                color: quantityInCart > 0 ? Colors.grey[700] : Colors.grey[400],
              ),
            ),
          ),
          // Hiển thị số lượng
          Container(
            width: 32,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.symmetric(
                vertical: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Center(
              child: Text(
                '$quantityInCart',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          // Nút tăng
          InkWell(
            onTap: () {
              final currentStock = _viewModel.productProvider.getProductStock(product.id);
              if (quantityInCart < currentStock) {
                // Truyền vào cả object product thay vì chỉ product.id
                _viewModel.updateCartItemQuantity(product, quantityInCart + 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không đủ hàng tồn kho'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Icon(
                Icons.add,
                size: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}