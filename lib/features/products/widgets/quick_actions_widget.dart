import 'package:flutter/material.dart';
import '../../../core/routing/route_names.dart';
import '../models/product.dart';
import 'quick_add_batch_sheet.dart';

class QuickActionsWidget extends StatelessWidget {
  final Product product;
  final VoidCallback? onBatchAdded;

  const QuickActionsWidget({
    Key? key,
    required this.product,
    this.onBatchAdded,
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
            Text(
              'Thao Tác Nhanh',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Nhập Lô Nhanh',
                    'Thêm lô hàng mới ngay lập tức',
                    Icons.add_box,
                    Colors.blue,
                    () => _showQuickAddBatchSheet(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Tạo Đơn Nhập',
                    'Tạo đơn nhập hàng cho sản phẩm này',
                    Icons.shopping_cart_rounded,
                    Colors.green,
                    () => _createPurchaseOrder(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddBatchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddBatchSheet(
        product: product,
        onBatchAdded: onBatchAdded,
      ),
    );
  }

  void _createPurchaseOrder(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pushNamed(
      RouteNames.createPurchaseOrder,
      arguments: {
        'preselectedProductId': product.id,
      },
    );
  }
}