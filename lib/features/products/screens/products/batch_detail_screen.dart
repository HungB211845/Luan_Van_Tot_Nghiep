import 'package:flutter/material.dart';
import '../../models/product_batch.dart';
import 'edit_batch_screen.dart';
import '../../../../shared/utils/formatter.dart';

class BatchDetailScreen extends StatelessWidget {
  final ProductBatch batch;

  const BatchDetailScreen({
    Key? key,
    required this.batch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          batch.batchNumber,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditBatchScreen(batch: batch),
                ),
              );
            },
            tooltip: 'Chỉnh sửa lô hàng',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoSection(context),
            const SizedBox(height: 16),
            _buildOriginSection(context),
            const SizedBox(height: 16),
            _buildStatusSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông Tin Lô Hàng',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.inventory_2,
              label: 'Số lượng còn lại',
              value: '${batch.quantity.toInt()}',
              unit: 'đơn vị',
              color: _getStockColor(batch.quantity.toDouble()),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.attach_money,
              label: 'Giá vốn',
              value: AppFormatter.formatCompactCurrency(batch.costPrice),
              color: Colors.orange[600]!,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Ngày nhập',
              value: _formatDate(batch.receivedDate),
              color: Colors.blue[600]!,
            ),
            if (batch.expiryDate != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'Hạn sử dụng',
                value: _formatDate(batch.expiryDate!),
                color: _getExpiryColor(batch.expiryDate!),
              ),
            ],
            if (batch.supplierBatchId != null && batch.supplierBatchId!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.qr_code,
                label: 'Mã lô nhà cung cấp',
                value: batch.supplierBatchId!,
                color: Colors.purple[600]!,
              ),
            ],
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.note,
                label: 'Ghi chú',
                value: batch.notes!,
                color: Colors.grey[600]!,
                isMultiLine: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOriginSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nguồn Gốc',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            if (batch.supplierName != null && batch.supplierName!.isNotEmpty)
              _buildInfoRow(
                icon: Icons.business,
                label: 'Nhà cung cấp',
                value: batch.supplierName!,
                color: Colors.indigo[600]!,
              ),
            if (batch.supplierName != null && batch.purchaseOrderId != null)
              const Divider(height: 24),
            if (batch.purchaseOrderId != null)
              InkWell(
                onTap: () {
                  // TODO: Navigate to Purchase Order Detail Screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tính năng xem đơn nhập hàng đang phát triển'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green[600]!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.green[600]!,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đơn nhập hàng gốc',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              batch.purchaseOrderId!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final isExpired = batch.isExpired;
    final isExpiringSoon = batch.isExpiringSoon;
    final isLowStock = batch.quantity <= 10;
    final isOutOfStock = batch.quantity <= 0;

    List<Widget> statusItems = [];

    if (isOutOfStock) {
      statusItems.add(_buildStatusItem(
        icon: Icons.error,
        label: 'Hết hàng',
        color: Colors.red[600]!,
        isWarning: true,
      ));
    } else if (isLowStock) {
      statusItems.add(_buildStatusItem(
        icon: Icons.warning,
        label: 'Sắp hết hàng',
        color: Colors.orange[600]!,
        isWarning: true,
      ));
    } else {
      statusItems.add(_buildStatusItem(
        icon: Icons.check_circle,
        label: 'Còn hàng',
        color: Colors.green[600]!,
      ));
    }

    if (isExpired) {
      statusItems.add(_buildStatusItem(
        icon: Icons.event_busy,
        label: 'Đã hết hạn',
        color: Colors.red[600]!,
        isWarning: true,
      ));
    } else if (isExpiringSoon) {
      statusItems.add(_buildStatusItem(
        icon: Icons.schedule,
        label: 'Sắp hết hạn',
        color: Colors.orange[600]!,
        isWarning: true,
      ));
    } else if (batch.expiryDate != null) {
      final daysLeft = batch.daysUntilExpiry;
      statusItems.add(_buildStatusItem(
        icon: Icons.event_available,
        label: 'Còn $daysLeft ngày',
        color: Colors.green[600]!,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trạng Thái',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            ...statusItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: item,
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    required Color color,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      maxLines: isMultiLine ? null : 1,
                      overflow: isMultiLine ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (unit != null && unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required Color color,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isWarning ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
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

  Color _getExpiryColor(DateTime expiryDate) {
    final now = DateTime.now();
    if (now.isAfter(expiryDate)) {
      return Colors.red[600]!;
    } else if (expiryDate.difference(now).inDays <= 30) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }
}