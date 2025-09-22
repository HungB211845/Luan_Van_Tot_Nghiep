// lib/screens/pos/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../providers/product_provider.dart';
import '../../providers/customer_provider.dart';
import '../../view_models/pos_view_model.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late POSViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = POSViewModel(
      productProvider: context.read<ProductProvider>(),
      customerProvider: context.read<CustomerProvider>(),
      transactionProvider: context.read<TransactionProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ Hàng'),
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
      body: Column(
        children: [
          // Nút chọn khách hàng
          _buildCustomerSelector(),
          const Divider(height: 1),
          // Danh sách giỏ hàng
          Expanded(child: _buildCartList()),
          const Divider(height: 1),
          // Tổng tiền và nút thanh toán
          _buildCartSummaryAndCheckout(),
        ],
      ),
    );
  }

  // Widget để chọn khách hàng
  Widget _buildCustomerSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: InkWell(
        onTap: () => _showCustomerSelectionDialog(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_add, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _viewModel.selectedCustomer?.name ?? '+ Thêm khách hàng',
                  style: TextStyle(
                    fontSize: 14,
                    color: _viewModel.selectedCustomer != null
                        ? Colors.black
                        : Colors.grey[600],
                  ),
                ),
              ),
              if (_viewModel.selectedCustomer != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() {
                      _viewModel.clearCustomerSelection();
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget hiển thị danh sách các món trong giỏ hàng
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
                                '${cartItem.priceAtSale.toStringAsFixed(0)}đ/đơn vị',
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
                              '${cartItem.subTotal.toStringAsFixed(0)}đ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                        // Cụm nút tăng giảm số lượng - larger for cart screen
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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

  // Widget hiển thị tổng tiền và nút thanh toán
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
                    '${productProvider.cartTotal.toStringAsFixed(0)}đ',
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
                  label: const Text('Thanh Toán Ngay'),
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

  // Hiển thị hộp thoại xác nhận thanh toán
  void _showCheckoutDialog() {
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
                    Navigator.pop(dialogContext);
                    _viewModel.handleCheckout(
                      paymentMethod: selectedPaymentMethod,
                      isDebt: selectedPaymentMethod == PaymentMethod.DEBT,
                    ).then((transactionId) {
                      if (!mounted) return;
                      if (transactionId != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thanh toán thành công!'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context); // Trở về POSScreen
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
}