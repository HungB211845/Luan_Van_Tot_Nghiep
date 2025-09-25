import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../models/purchase_order.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/product_provider.dart';
import '../../../../core/routing/route_names.dart';

class PurchaseOrderDetailScreen extends StatefulWidget {
  final PurchaseOrder purchaseOrder;

  const PurchaseOrderDetailScreen({Key? key, required this.purchaseOrder})
      : super(key: key);

  static const String routeName = '/po-detail';

  @override
  _PurchaseOrderDetailScreenState createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<PurchaseOrderProvider>()
          .loadPODetails(widget.purchaseOrder.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.purchaseOrder.poNumber ?? 'Chi tiết đơn hàng'),
      ),
      body: Consumer<PurchaseOrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.selectedPO == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.selectedPO == null) {
            return const Center(child: Text('Không thể tải chi tiết đơn hàng.'));
          }

          final po = provider.selectedPO!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(po),
                const SizedBox(height: 24),
                _buildPOItems(provider),
                const SizedBox(height: 24),
                if (po.status == PurchaseOrderStatus.DELIVERED)
                  _buildGeneratedBatches(provider),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader(PurchaseOrder po) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PO: ${po.poNumber}', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Chip(
              label: Text(po.status.name),
              backgroundColor: Colors.orange[100],
            ),
            const Divider(height: 24),
            _buildInfoRow('Nhà cung cấp:', po.supplierName ?? 'N/A'),
            _buildInfoRow('Ngày đặt:', AppFormatter.formatDate(po.orderDate)),
            _buildInfoRow('Tổng tiền:', AppFormatter.formatCurrency(po.totalAmount)),
          ],
        ),
      ),
    );
  }

  Widget _buildPOItems(PurchaseOrderProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Các sản phẩm đã đặt', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.selectedPOItems.length,
          itemBuilder: (context, index) {
            final item = provider.selectedPOItems[index];
            final titleText = item.productName != null && item.productName!.isNotEmpty
                ? item.productName!
                : 'Sản phẩm: ${item.productId}';
            return ListTile(
              title: Text(titleText),
              subtitle: Text('SL: ${item.quantity} ${item.unit ?? ''}'),
              trailing: Text(AppFormatter.formatCurrency(item.totalCost)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGeneratedBatches(PurchaseOrderProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Các lô hàng đã tạo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (provider.batchesForPO.isEmpty)
          const Text('Chưa có lô hàng nào được tạo từ đơn này.'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.batchesForPO.length,
          itemBuilder: (context, index) {
            final batch = provider.batchesForPO[index];
            final productTitle = batch.productName ?? 'ID: ${batch.productId}';
            final supplierLine = batch.supplierName != null && batch.supplierName!.isNotEmpty
                ? 'NCC: ${batch.supplierName}'
                : null;
            return ListTile(
              title: Text(productTitle),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lô: ${batch.batchNumber}'),
                  if (supplierLine != null) Text(supplierLine),
                ],
              ),
              trailing: Text('SL: ${batch.quantity}'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, child) {
        final po = provider.selectedPO;
        if (po == null) return const SizedBox.shrink();

        // Show different actions based on PO status
        if (po.status == PurchaseOrderStatus.DELIVERED) {
          // Already delivered - show info
          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(top: BorderSide(color: Colors.green.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã nhận hàng thành công',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 16,
                        ),
                      ),
                      if (po.deliveryDate != null)
                        Text(
                          'Ngày nhận: ${AppFormatter.formatDate(po.deliveryDate!)}',
                          style: TextStyle(color: Colors.green.shade600, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (po.status != PurchaseOrderStatus.SENT && po.status != PurchaseOrderStatus.CONFIRMED) {
          return const SizedBox.shrink();
        }

        // Show goods receipt action for pending POs
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, -2),
                blurRadius: 4,
                color: Colors.black12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đơn hàng đã sẵn sàng để nhận',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatter.formatCurrency(po.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Icon(Icons.inventory, size: 24),
                  label: Text(
                    provider.isLoading ? 'Đang xử lý...' : 'Xác Nhận Nhận Hàng',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  onPressed: provider.isLoading ? null : () => _showGoodsReceiptDialog(context, po, provider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGoodsReceiptDialog(BuildContext context, PurchaseOrder po, PurchaseOrderProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory, color: Colors.green.shade600),
            const SizedBox(width: 8),
            const Text('Xác Nhận Nhận Hàng'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn đang chuẩn bị nhận hàng cho:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PO: ${po.poNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Tổng tiền: ${AppFormatter.formatCurrency(po.totalAmount)}'),
                  Text('Số sản phẩm: ${provider.selectedPOItems.length} item(s)'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hành động này sẽ:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text('• Đánh dấu đơn hàng là "Đã Giao"'),
            const Text('• Tạo lô hàng (ProductBatch) cho từng sản phẩm'),
            const Text('• Cập nhật tồn kho hệ thống'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Thao tác này không thể hoàn tác',
                      style: TextStyle(color: Colors.amber.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Xác Nhận Nhận'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Capture dependencies BEFORE closing dialog to avoid using context after dispose
              final productProvider = context.read<ProductProvider>();
              final navigator = Navigator.of(context);
              // Close dialog first
              navigator.pop();

              final success = await provider.receivePO(po.id);
              if (!mounted) return;
              if (mounted) {
                if (success) {
                  // Refresh inventory after successful goods receipt
                  final productIds = provider.getProductIdsFromPO(po.id);
                  await productProvider.refreshInventoryAfterGoodsReceipt(productIds);
                  // Force refresh all inventory data to ensure UI reflects new stock across the app
                  await productProvider.refreshAllInventoryData();
                  // Optional: reload products list to refresh available_stock from view
                  await productProvider.loadProductsPaginated();
                  // Navigate to success screen, then back to PO list
                  navigator.pushNamed(
                    RouteNames.purchaseOrderReceiveSuccess,
                    arguments: po.poNumber,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(provider.errorMessage.isNotEmpty ? provider.errorMessage : 'Có lỗi xảy ra khi nhận hàng')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(color: Colors.grey[600])), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}
