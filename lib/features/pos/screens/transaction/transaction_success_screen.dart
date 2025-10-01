import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final String transactionId;

  const TransactionSuccessScreen({Key? key, required this.transactionId})
    : super(key: key);

  @override
  State<TransactionSuccessScreen> createState() =>
      _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen> {
  @override
  void initState() {
    super.initState();
    print('📱 TransactionSuccessScreen initialized with ID: ${widget.transactionId}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Success screen entry haptic feedback
        HapticFeedback.mediumImpact();
        print('🔄 Loading transaction details...');
        context.read<ProductProvider>().loadTransactionDetails(
          widget.transactionId,
        );
      }
    });
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch thành công'),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingWidget();
          }

          if (provider.hasError || provider.activeTransaction == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Không thể tải chi tiết giao dịch',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final transaction = provider.activeTransaction!;
          final items = provider.activeTransactionItems;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Thanh toán thành công!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Mã đơn hàng:',
                          transaction.invoiceNumber ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Tổng tiền:',
                          _formatCurrency(transaction.totalAmount),
                        ),
                        if (transaction.customerId != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Mã khách hàng:',
                            transaction.customerId!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Chi tiết đơn hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item =
                          items[index]; // 'item' bây giờ là một TransactionItemDetails
                      return ListTile(
                        title: Text(item.productName), // <-- Dùng productName
                        subtitle: Text(
                          'SKU: ${item.productSku} - Số lượng: ${item.quantity}',
                        ),
                        trailing: Text(_formatCurrency(item.subTotal)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    if (!mounted) return;

                    // Haptic feedback khi bấm nút tạo giao dịch mới
                    HapticFeedback.lightImpact();

                    // Chỉ cần quay về POS screen.
                    // POS screen sẽ tự động xử lý việc làm mới dữ liệu.
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop(); // Close TransactionSuccess, return to POS
                    }
                  },
                  child: const Text('Tạo Giao Dịch Mới'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
