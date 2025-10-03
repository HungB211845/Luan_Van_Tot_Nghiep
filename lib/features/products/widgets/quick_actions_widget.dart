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
            _buildActionListTile(
              context,
              'Nhập Lô Nhanh',
              'Thêm lô hàng mới ngay lập tức',
              Icons.add_box,
              () => _showQuickAddBatchSheet(context),
            ),
            const Divider(height: 1),
            _buildActionListTile(
              context,
              'Tạo Đơn Nhập',
              'Tạo đơn nhập hàng cho sản phẩm này',
              Icons.shopping_cart_rounded,
              () => _createPurchaseOrder(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionListTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.grey[700],
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
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