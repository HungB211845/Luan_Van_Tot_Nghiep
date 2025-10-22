import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../../invoice/providers/invoice_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';
import '../../models/transaction.dart';
import '../../models/transaction_item_details.dart';
import '../../models/payment_method.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final bool isEmbedded; // True when shown in desktop master-detail layout

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.isEmbedded = false,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadTransactionDetails(widget.transaction.id);
    });
  }

  @override
  void didUpdateWidget(covariant TransactionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transaction.id != oldWidget.transaction.id) {
      // A new transaction has been selected in the master-detail view,
      // so we need to load its specific details.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProductProvider>().loadTransactionDetails(widget.transaction.id);
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPrintDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn định dạng hóa đơn'),
        content: const Text('Bạn muốn in hóa đơn dưới định dạng nào?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateInvoice('pdf');
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red),
                SizedBox(width: 8),
                Text('PDF'),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateInvoice('excel');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.table_chart, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Excel'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateInvoice(String format) async {
    final invoiceProvider = context.read<InvoiceProvider>();

    final file = await invoiceProvider.generateTransactionInvoice(
      widget.transaction.id,
      format,
    );

    if (mounted) {
      // Only show error snackbar if generation failed
      if (file == null && invoiceProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(invoiceProvider.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }

      // For PDF, show print option after share (if successful)
      if (file != null && format == 'pdf') {
        _showPrintOption(file);
      }
    }
  }

  void _showPrintOption(File pdfFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('In hóa đơn'),
        content: const Text('Bạn có muốn in hóa đơn này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<InvoiceProvider>().printInvoice(pdfFile);
            },
            icon: const Icon(Icons.print),
            label: const Text('In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isEmbedded ? Colors.grey[50] : null,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('Chi tiết giao dịch'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng chia sẻ sẽ được phát triển')),
              );
            },
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: LoadingWidget(message: 'Đang tải chi tiết giao dịch...'));
          }

          if (provider.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<ProductProvider>().loadTransactionDetails(widget.transaction.id),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final transaction = widget.transaction;
          final items = provider.activeTransactionItems;

          return SingleChildScrollView(
            padding: EdgeInsets.all(widget.isEmbedded ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isEmbedded) ...[
                  // Desktop header
                  const Text(
                    'Chi tiết giao dịch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Transaction Status Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giao dịch thành công',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            Text(
                              AppFormatter.formatDateTime(transaction.transactionDate),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Transaction Info Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin giao dịch',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          'Mã hóa đơn:',
                          transaction.invoiceNumber ?? 'N/A',
                          onTap: () => _copyToClipboard(transaction.invoiceNumber ?? '', 'mã hóa đơn'),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Tổng tiền:', AppFormatter.formatCurrency(transaction.totalAmount)),
                        const SizedBox(height: 12),
                        _buildInfoRow('Phương thức:', transaction.paymentMethod.displayName),
                        const SizedBox(height: 12),
                        _buildInfoRow('Khách hàng:', transaction.customerName ?? 'Khách lẻ'),
                        if (transaction.isDebt) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Trạng thái nợ:',
                            'Còn nợ',
                            valueStyle: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (transaction.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow('Ghi chú:', transaction.notes!),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Items List Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Chi tiết sản phẩm',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${items.length} sản phẩm',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                'Không có chi tiết sản phẩm',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _buildProductItem(item);
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Total Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng cộng:',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppFormatter.formatCurrency(transaction.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.print),
                        label: const Text('In hóa đơn'),
                        onPressed: _showPrintDialog,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Sao chép'),
                        onPressed: () => _copyToClipboard(
                          transaction.invoiceNumber ?? '',
                          'thông tin giao dịch',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    VoidCallback? onTap,
    TextStyle? valueStyle,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          if (onTap != null)
            Icon(Icons.copy, size: 16, color: Colors.grey[500]),
        ],
      ),
    );
  }

  Widget _buildProductItem(TransactionItemDetails item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.productSku?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item.productSku}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                AppFormatter.formatCurrency(item.subTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SL: ${item.quantity} ${item.unitLabel}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${AppFormatter.formatCurrency(item.pricePerDisplayUnit)}/${item.priceUnitName}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
