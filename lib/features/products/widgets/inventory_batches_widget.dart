import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/product_batch.dart';
import '../providers/product_provider.dart';
import '../screens/products/edit_batch_screen.dart';
import '../services/inventory_adjustment_service.dart';

class InventoryBatchesWidget extends StatelessWidget {
  final List<ProductBatch> batches;
  final VoidCallback? onBatchUpdated;

  const InventoryBatchesWidget({
    Key? key,
    required this.batches,
    this.onBatchUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Tồn Kho & Lô Hàng',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                Text(
                  '${batches.length} lô',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (batches.isEmpty)
              _buildEmptyState()
            else
              _buildBatchesList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có lô hàng nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sử dụng "Nhập Lô Nhanh" để thêm lô hàng đầu tiên',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: batches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final batch = batches[index];
        return _buildBatchItem(context, batch);
      },
    );
  }

  Widget _buildBatchItem(BuildContext context, ProductBatch batch) {
    final isExpiringSoon = batch.expiryDate != null &&
        batch.expiryDate!.difference(DateTime.now()).inDays <= 30;
    final isLowStock = batch.quantity <= 10;

    return Slidable(
      key: ValueKey(batch.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _editBatch(context, batch),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Sửa',
          ),
          SlidableAction(
            onPressed: (context) => _deleteBatch(context, batch),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Xóa',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showBatchDetails(context, batch),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              _buildBatchIcon(batch, isExpiringSoon, isLowStock),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // FIXED: Use Expanded to prevent overflow
                        Expanded(
                          flex: 3,
                          child: Text(
                            batch.batchNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isExpiringSoon) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Sắp hết hạn',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Số lượng: ${batch.quantity.toInt()} | Giá vốn: ${_formatPrice(batch.costPrice)} VNĐ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (batch.receivedDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Nhập: ${_formatDate(batch.receivedDate)}${batch.expiryDate != null ? ' | HSD: ${_formatDate(batch.expiryDate!)}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStockColor(batch.quantity.toDouble()).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${batch.quantity.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getStockColor(batch.quantity.toDouble()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vuốt để sửa/xóa',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchIcon(ProductBatch batch, bool isExpiringSoon, bool isLowStock) {
    Color iconColor;
    IconData iconData;

    if (batch.quantity <= 0) {
      iconColor = Colors.red[600]!;
      iconData = Icons.error;
    } else if (isExpiringSoon) {
      iconColor = Colors.orange[600]!;
      iconData = Icons.warning;
    } else if (isLowStock) {
      iconColor = Colors.orange[600]!;
      iconData = Icons.inventory_2;
    } else {
      iconColor = Colors.green[600]!;
      iconData = Icons.check_circle;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    } else {
      return price.toStringAsFixed(0);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getStockColor(double stock) {
    if (stock <= 0) {
      return Colors.red[600]!;
    } else if (stock <= 10) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }

  void _showBatchDetails(BuildContext context, ProductBatch batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chi Tiết Lô Hàng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Mã lô:', batch.batchNumber),
              const SizedBox(height: 8),
              _buildDetailRow('Số lượng:', '${batch.quantity.toInt()} đơn vị'),
              const SizedBox(height: 8),
              _buildDetailRow('Giá vốn:', '${_formatPrice(batch.costPrice)} VNĐ'),
              const SizedBox(height: 8),
              if (batch.receivedDate != null) ...[
                _buildDetailRow('Ngày nhập:', _formatDate(batch.receivedDate!)),
                const SizedBox(height: 8),
              ],
              if (batch.expiryDate != null) ...[
                _buildDetailRow('Hạn sử dụng:', _formatDate(batch.expiryDate!)),
                const SizedBox(height: 8),
              ],
              _buildDetailRow('Trạng thái:', _getBatchStatus(batch)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editBatch(context, batch);
            },
            child: const Text('Sửa'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _getBatchStatus(ProductBatch batch) {
    if (batch.quantity <= 0) {
      return 'Hết hàng';
    }

    if (batch.expiryDate != null) {
      final daysUntilExpiry = batch.expiryDate!.difference(DateTime.now()).inDays;
      if (daysUntilExpiry <= 0) {
        return 'Đã hết hạn';
      } else if (daysUntilExpiry <= 30) {
        return 'Sắp hết hạn ($daysUntilExpiry ngày)';
      }
    }

    if (batch.quantity <= 10) {
      return 'Tồn kho thấp';
    }

    return 'Còn hàng';
  }

  Future<void> _editBatch(BuildContext context, ProductBatch batch) async {
    final inventoryService = InventoryAdjustmentService();

    try {
      final canEdit = await inventoryService.canEditBatch(batch.id);

      if (!canEdit) {
        if (context.mounted) {
          _showCannotEditDialog(context, batch);
        }
        return;
      }

      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditBatchScreen(batch: batch),
          ),
        );

        if (result == true) {
          onBatchUpdated?.call();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kiểm tra quyền sửa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBatch(BuildContext context, ProductBatch batch) async {
    final inventoryService = InventoryAdjustmentService();

    try {
      final canDelete = await inventoryService.canDeleteBatch(batch.id);

      if (!canDelete) {
        if (context.mounted) {
          _showCannotDeleteDialog(context, batch);
        }
        return;
      }

      if (context.mounted) {
        await _showDeleteConfirmation(context, batch);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kiểm tra quyền xóa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCannotEditDialog(BuildContext context, ProductBatch batch) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Không thể sửa'),
        content: Text(
          'Lô hàng "${batch.batchNumber}" đã có giao dịch bán. Để đảm bảo tính toàn vẹn dữ liệu, bạn không thể sửa lô hàng này.\n\nNếu cần điều chỉnh, vui lòng tạo điều chỉnh tồn kho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCannotDeleteDialog(BuildContext context, ProductBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy lô hàng'),
        content: Text(
          'Lô hàng "${batch.batchNumber}" đã có giao dịch bán, không thể xóa hoàn toàn.\n\nBạn có muốn hủy lô hàng này không? Hành động này sẽ:\n- Tạo điều chỉnh tồn kho\n- Đánh dấu lô hàng là đã hủy\n- Giữ lại lịch sử giao dịch',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy bỏ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hủy lô hàng'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _voidBatch(context, batch);
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, ProductBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa lô hàng "${batch.batchNumber}"?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _performDelete(context, batch);
    }
  }

  Future<void> _voidBatch(BuildContext context, ProductBatch batch) async {
    try {
      final inventoryService = InventoryAdjustmentService();
      final success = await inventoryService.voidBatch(
        batch.id,
        'Hủy lô hàng đã có giao dịch từ giao diện quản lý',
      );

      if (context.mounted) {
        if (success) {
          onBatchUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hủy lô hàng thành công'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lỗi hủy lô hàng'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performDelete(BuildContext context, ProductBatch batch) async {
    try {
      final provider = context.read<ProductProvider>();
      final success = await provider.deleteProductBatch(batch.id, batch.productId);

      if (context.mounted) {
        if (success) {
          onBatchUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa lô hàng thành công'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}