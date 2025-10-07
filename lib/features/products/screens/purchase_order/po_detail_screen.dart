import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/purchase_order.dart';
import '../../models/purchase_order_status.dart';
import '../../providers/purchase_order_provider.dart';
import '../../providers/product_provider.dart';

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
    return ResponsiveScaffold(
      title: widget.purchaseOrder.poNumber ?? 'Chi tiết đơn hàng',
      showBackButton: true,
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
            padding: EdgeInsets.all(context.sectionPadding),
            child: Column(
              children: [
                // Prominent Status Section
                _buildStatusSection(po),
                SizedBox(height: context.sectionPadding),
                
                // Grouped List Style
                _buildGroupedContent(po, provider),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Prominent Status Section - HIG Guideline #2
  Widget _buildStatusSection(PurchaseOrder po) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (po.status) {
      case PurchaseOrderStatus.delivered:
        statusColor = Colors.green;
        statusText = 'ĐÃ NHẬN HÀNG';
        statusIcon = Icons.check_circle;
        break;
      case PurchaseOrderStatus.confirmed:
        statusColor = Colors.blue;
        statusText = 'ĐÃ XÁC NHẬN';
        statusIcon = Icons.verified;
        break;
      case PurchaseOrderStatus.draft:
        statusColor = Colors.grey;
        statusText = 'BẢN NHÁP';
        statusIcon = Icons.edit_document;
        break;
      default:
        statusColor = Colors.orange;
        statusText = po.status.name.toUpperCase();
        statusIcon = Icons.info;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.sectionPadding),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 28),
              SizedBox(width: context.cardSpacing),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          SizedBox(height: context.cardSpacing),
          Text(
            'Đơn hàng: ${po.poNumber}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          if (po.status == PurchaseOrderStatus.delivered) ...[
            SizedBox(height: context.cardSpacing / 2),
            Text(
              'Ngày nhận: ${AppFormatter.formatDate(po.orderDate)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Grouped List Content - HIG Guideline #1
  Widget _buildGroupedContent(PurchaseOrder po, PurchaseOrderProvider provider) {
    return Column(
      children: [
        // Group 1: Thông tin chính
        _buildInfoSection(po),
        SizedBox(height: context.sectionPadding),
        
        // Group 2: Danh sách sản phẩm
        _buildProductsSection(provider),
        SizedBox(height: context.sectionPadding),
        
        // Group 3: Các lô hàng (chỉ hiện khi delivered)
        if (po.status == PurchaseOrderStatus.delivered)
          _buildBatchesSection(provider),
      ],
    );
  }

  Widget _buildInfoSection(PurchaseOrder po) {
    return _buildGroupContainer(
      title: 'THÔNG TIN CHÍNH',
      child: Column(
        children: [
          _buildInfoRow('Nhà cung cấp', po.supplierName ?? 'N/A'),
          _buildInfoRow('Ngày đặt hàng', AppFormatter.formatDate(po.orderDate)),
          _buildInfoRow('Tổng giá trị', AppFormatter.formatCurrency(po.totalAmount)),
        ],
      ),
    );
  }

  Widget _buildProductsSection(PurchaseOrderProvider provider) {
    return _buildGroupContainer(
      title: 'DANH SÁCH SẢN PHẨM',
      child: Column(
        children: provider.selectedPOItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == provider.selectedPOItems.length - 1;
          
          return Column(
            children: [
              _buildProductRow(item),
              if (!isLast) Divider(height: 1, color: Colors.grey[300]),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBatchesSection(PurchaseOrderProvider provider) {
    return _buildGroupContainer(
      title: 'CÁC LÔ HÀNG ĐÃ TẠO',
      child: provider.batchesForPO.isEmpty
          ? Padding(
              padding: EdgeInsets.all(context.sectionPadding),
              child: Text(
                'Chưa có lô hàng nào được tạo',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : Column(
              children: provider.batchesForPO.asMap().entries.map((entry) {
                final index = entry.key;
                final batch = entry.value;
                final isLast = index == provider.batchesForPO.length - 1;
                
                return Column(
                  children: [
                    _buildBatchRow(batch),
                    if (!isLast) Divider(height: 1, color: Colors.grey[300]),
                  ],
                );
              }).toList(),
            ),
    );
  }

  // Grouped Container Helper
  Widget _buildGroupContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header - HIG Typography
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.sectionPadding),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Content
          child,
        ],
      ),
    );
  }

  // Invoice-style Product Row - HIG Guideline #3
  Widget _buildProductRow(dynamic item) {
    final titleText = item.productName != null && item.productName!.isNotEmpty
        ? item.productName!
        : 'Sản phẩm: ${item.productId}';
    
    return Padding(
      padding: EdgeInsets.all(context.sectionPadding),
      child: Row(
        children: [
          // Product info (left)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.cardSpacing / 2),
                Text(
                  'SL: ${item.quantity} ${item.unit ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Price info (right)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatter.formatCurrency(item.totalCost),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchRow(dynamic batch) {
    final productTitle = batch.productName ?? 'ID: ${batch.productId}';
    
    return Padding(
      padding: EdgeInsets.all(context.sectionPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lô hàng cho: $productTitle',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: context.cardSpacing / 2),
                Text(
                  'Mã lô: ${batch.batchNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (batch.supplierName != null && batch.supplierName!.isNotEmpty)
                  Text(
                    'NCC: ${batch.supplierName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'SL: ${batch.quantity}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.all(context.sectionPadding),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<PurchaseOrderProvider>(
      builder: (context, provider, child) {
        final po = provider.selectedPO;
        if (po == null || provider.status == POStatus.loading) {
          return const SizedBox.shrink();
        }

        // Case 1: PO has been successfully delivered - NO SUCCESS MESSAGE (HIG #4)
        if (po.status == PurchaseOrderStatus.delivered) {
          return const SizedBox.shrink(); // Clean UI, no permanent success banner
        }

        // Case 2: PO has been sent, waiting for supplier confirmation
        if (po.status == PurchaseOrderStatus.sent) {
          return _buildActionButton(
            title: 'Xác nhận Đơn Hàng',
            icon: Icons.thumb_up_alt_outlined,
            color: Colors.blue.shade600,
            isLoading: provider.isLoading,
            onPressed: () async {
              final success = await provider.updatePOStatus(po.id, PurchaseOrderStatus.confirmed);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xác nhận đơn hàng.'), backgroundColor: Colors.green),
                );
              }
            },
          );
        }

        // Case 3: PO is confirmed, ready to receive goods
        if (po.status == PurchaseOrderStatus.confirmed) {
          return _buildActionButton(
            title: 'Xác Nhận Nhận Hàng',
            icon: Icons.inventory,
            color: Colors.green.shade600,
            isLoading: provider.isLoading,
            onPressed: () => _showGoodsReceiptDialog(context, po, provider),
          );
        }

        // Default: For DRAFT, CANCELLED, or other states, show nothing
        return const SizedBox.shrink();
      },
    );
  }

  // Helper widget to build consistent action buttons
  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : Icon(icon, size: 24),
          label: Text(
            isLoading ? 'Đang xử lý...' : title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          onPressed: isLoading ? null : onPressed,
        ),
      ),
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
            const Expanded(
              child: Text('Xác Nhận Nhận Hàng'),
            ),
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
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Close dialog first
              navigator.pop();

              final success = await provider.receivePO(po.id);

              // Check mounted before using any context-dependent operations
              if (!mounted) return;

              if (success) {
                // Refresh inventory after successful goods receipt
                final productIds = provider.getProductIdsFromPO(po.id);
                await productProvider.refreshInventoryAfterGoodsReceipt(productIds);
                // Force refresh all inventory data to ensure UI reflects new stock across the app
                await productProvider.refreshAllInventoryData();
                // Optional: reload products list to refresh available_stock from view
                await productProvider.loadProductsPaginated();

                // Check mounted again before showing SnackBar
                if (!mounted) return;

                // Show temporary success SnackBar (HIG Guideline #4)
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Đã nhận hàng thành công cho đơn ${po.poNumber}'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3), // 3 seconds as per HIG
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                // Check mounted before showing SnackBar
                if (!mounted) return;

                scaffoldMessenger.showSnackBar(
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
            },
          ),
        ],
      ),
    );
  }
}
