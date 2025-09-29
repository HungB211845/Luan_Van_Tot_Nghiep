import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/payment_method.dart';
import '../../../products/providers/product_provider.dart';
import '../../../customers/providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../view_models/pos_view_model.dart';
import '../transaction/transaction_success_screen.dart';
import '../../../../shared/utils/formatter.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late POSViewModel _viewModel;
  final TextEditingController _customerSearchController = TextEditingController();
  final FocusNode _customerSearchFocus = FocusNode();
  List<dynamic> _filteredCustomers = [];
  bool _showCustomerDropdown = false;

  @override
  void initState() {
    super.initState();
    _viewModel = POSViewModel(
      productProvider: context.read<ProductProvider>(),
      customerProvider: context.read<CustomerProvider>(),
      transactionProvider: context.read<TransactionProvider>(),
    );

    // Khởi tạo danh sách khách hàng đã lọc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers().then((_) {
        setState(() {
          _filteredCustomers = context.read<CustomerProvider>().customers;
        });
      });
    });
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _customerSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ Hàng & Thanh Toán'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Nút xóa toàn bộ giỏ hàng
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              if (productProvider.cartItems.isEmpty) return Container();
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () => _showClearCartDialog(),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _hideCustomerDropdown,
        child: Column(
          children: [
            // Phần 1: Widget chọn khách hàng
            _buildCustomerSelector(),
            const Divider(height: 1),
            // Phần 2: Danh sách sản phẩm trong giỏ hàng
            Expanded(
              child: _buildCartList(),
            ),
            // Phần 3: Container cố định - Tổng tiền và nút thanh toán
            _buildCartSummaryAndCheckout(),
          ],
        ),
      ),
    );
  }

  // Widget tìm kiếm khách hàng thông minh
  Widget _buildCustomerSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _customerSearchController,
            focusNode: _customerSearchFocus,
            decoration: InputDecoration(
              hintText: _viewModel.selectedCustomer != null
                  ? '${_viewModel.selectedCustomer!.name} - ${_viewModel.selectedCustomer!.phone ?? ""}'
                  : 'Tìm khách hàng (tên, SĐT, địa chỉ)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _viewModel.selectedCustomer != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _viewModel.clearCustomerSelection();
                          _customerSearchController.clear();
                          _showCustomerDropdown = false;
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: _viewModel.selectedCustomer != null,
              fillColor: _viewModel.selectedCustomer != null
                  ? Colors.green.withOpacity(0.1)
                  : null,
            ),
            onChanged: _onCustomerSearchChanged,
            onTap: () {
              if (_viewModel.selectedCustomer == null) {
                setState(() {
                  _showCustomerDropdown = true;
                });
              }
            },
            readOnly: _viewModel.selectedCustomer != null,
          ),

          // Dropdown danh sách khách hàng
          if (_showCustomerDropdown && _viewModel.selectedCustomer == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: _filteredCustomers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Không tìm thấy khách hàng nào'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(
                            customer.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.phone != null && customer.phone!.isNotEmpty)
                                Text(
                                  customer.phone!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (customer.address != null && customer.address!.isNotEmpty)
                                Text(
                                  customer.address!,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _viewModel.selectCustomer(customer);
                              _customerSearchController.text = '${customer.name} - ${customer.phone ?? ""}';
                              _showCustomerDropdown = false;
                            });
                            _customerSearchFocus.unfocus();
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  // Phần 2: ListView hiển thị chi tiết các sản phẩm trong giỏ hàng
  Widget _buildCartList() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.cartItems.isEmpty) {
          return Column(
            children: [
              const Spacer(),
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Giỏ hàng trống',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thêm sản phẩm để bắt đầu',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: productProvider.cartItems.length,
          itemBuilder: (context, index) {
            final cartItem = productProvider.cartItems[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cartItem.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SKU: ${cartItem.productSku}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppFormatter.formatCurrency(cartItem.priceAtSale)}/đơn vị',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              AppFormatter.formatCurrency(cartItem.subTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Nút xóa sản phẩm
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                              onPressed: () => _showRemoveItemDialog(cartItem),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số lượng:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Nút tăng/giảm số lượng
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nút giảm
                              InkWell(
                                onTap: () {
                                  productProvider.updateCartItem(cartItem.productId, cartItem.quantity - 1);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      bottomLeft: Radius.circular(6),
                                    ),
                                  ),
                                  child: const Icon(Icons.remove, size: 20),
                                ),
                              ),
                              // Hiển thị số lượng
                              Container(
                                width: 60,
                                height: 36,
                                decoration: const BoxDecoration(color: Colors.white),
                                child: Center(
                                  child: Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              // Nút tăng
                              InkWell(
                                onTap: () {
                                  productProvider.updateCartItem(cartItem.productId, cartItem.quantity + 1);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(6),
                                      bottomRight: Radius.circular(6),
                                    ),
                                  ),
                                  child: const Icon(Icons.add, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Phần 3: Container cố định - Tổng tiền và nút thanh toán
  Widget _buildCartSummaryAndCheckout() {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tổng cộng (${productProvider.cartItemsCount} sản phẩm):',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    AppFormatter.formatCurrency(productProvider.cartTotal),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: productProvider.cartItems.isEmpty
                      ? null
                      : () => _showCheckoutDialog(),
                  icon: const Icon(Icons.payment, size: 24),
                  label: const Text('Thanh Toán'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog xác nhận xóa sản phẩm khỏi giỏ hàng
  void _showRemoveItemDialog(CartItem cartItem) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa sản phẩm'),
          content: Text('Bạn có chắc muốn xóa "${cartItem.productName}" khỏi giỏ hàng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductProvider>().removeFromCart(cartItem.productId);
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  // Dialog xác nhận xóa toàn bộ giỏ hàng
  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa toàn bộ giỏ hàng'),
          content: const Text('Bạn có chắc muốn xóa tất cả sản phẩm trong giỏ hàng?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                context.read<ProductProvider>().clearCart();
                _viewModel.clearCustomerSelection();
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Xóa Tất Cả'),
            ),
          ],
        );
      },
    );
  }

  // Tìm kiếm khách hàng thông minh
  void _onCustomerSearchChanged(String query) {
    final customerProvider = context.read<CustomerProvider>();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = customerProvider.customers;
        _showCustomerDropdown = false;
      } else {
        _showCustomerDropdown = true;
        // Tìm kiếm theo tên, số điện thoại và địa chỉ
        _filteredCustomers = customerProvider.customers.where((customer) {
          final searchLower = query.toLowerCase();
          final nameMatch = customer.name.toLowerCase().contains(searchLower);
          final phoneMatch = customer.phone?.toLowerCase().contains(searchLower) ?? false;
          final addressMatch = customer.address?.toLowerCase().contains(searchLower) ?? false;

          return nameMatch || phoneMatch || addressMatch;
        }).toList();
      }
    });
  }

  // Ẩn dropdown khi tap ra ngoài
  void _hideCustomerDropdown() {
    setState(() {
      _showCustomerDropdown = false;
    });
  }

  // Hiển thị hộp thoại xác nhận thanh toán
  void _showCheckoutDialog() {
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    // Chụp lấy Navigator và ScaffoldMessenger trước khi vào dialog
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
                    'Tổng tiền: ${AppFormatter.formatCurrency(context.read<ProductProvider>().cartTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(height: 24),
                  const Text('Chọn phương thức thanh toán:', style: TextStyle(fontWeight: FontWeight.w500)),
                  RadioListTile<PaymentMethod>(
                    title: const Text('Tiền mặt'),
                    value: PaymentMethod.cash,
                    groupValue: selectedPaymentMethod,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedPaymentMethod = value!;
                      });
                    },
                  ),
                  RadioListTile<PaymentMethod>(
                    title: const Text('Ghi nợ'),
                    value: PaymentMethod.debt,
                    groupValue: selectedPaymentMethod,
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
                  onPressed: () async {
                    // Ghi lại Navigator và ScaffoldMessenger TRƯỚC khi await
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final provider = context.read<ProductProvider>();

                    Navigator.pop(dialogContext); // Đóng dialog

                    final transactionId = await _viewModel.handleCheckout(
                      paymentMethod: selectedPaymentMethod,
                      isDebt: selectedPaymentMethod == PaymentMethod.debt,
                    );

                    if (transactionId != null) {
                      // Dùng push thay vì pushReplacement để có thể quay lại POS
                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => TransactionSuccessScreen(
                            key: ValueKey('transaction_success_$transactionId'),
                            transactionId: transactionId,
                          ),
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Lỗi: ${provider.errorMessage}'), backgroundColor: Colors.red),
                      );
                    }
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
}