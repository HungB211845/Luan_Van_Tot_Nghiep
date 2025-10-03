import 'package:flutter/material.dart';
import '../models/product.dart';

class PriceHistoryItem {
  final String id;
  final double newPrice;
  final double? oldPrice;
  final DateTime changedAt;
  final String? reason;
  final String? userWhoChanged;

  PriceHistoryItem({
    required this.id,
    required this.newPrice,
    this.oldPrice,
    required this.changedAt,
    this.reason,
    this.userWhoChanged,
  });
}

class PriceHistoryWidget extends StatelessWidget {
  final Product product;
  final List<PriceHistoryItem> priceHistory;
  final VoidCallback? onEditPrice;

  const PriceHistoryWidget({
    Key? key,
    required this.product,
    required this.priceHistory,
    this.onEditPrice,
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
                  'Lịch Sử Giá Bán',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onEditPrice,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Sửa giá'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCurrentPrice(),
            const SizedBox(height: 16),
            if (priceHistory.isEmpty)
              _buildEmptyHistory()
            else
              _buildPriceHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPrice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sell,
            color: Colors.green[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Giá bán hiện tại',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatPrice(product.currentSellingPrice)} VNĐ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có lịch sử thay đổi giá',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mọi thay đổi giá sẽ được ghi lại tại đây',
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

  Widget _buildPriceHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch sử thay đổi',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: priceHistory.length > 5 ? 5 : priceHistory.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final historyItem = priceHistory[index];
            return _buildHistoryItem(historyItem);
          },
        ),
        if (priceHistory.length > 5) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _showFullHistory(),
              child: Text(
                'Xem tất cả ${priceHistory.length} thay đổi',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryItem(PriceHistoryItem item) {
    final isIncrease = item.oldPrice != null && item.newPrice > item.oldPrice!;
    final isDecrease = item.oldPrice != null && item.newPrice < item.oldPrice!;

    Color changeColor = Colors.grey[600]!;
    IconData changeIcon = Icons.drag_handle;

    if (isIncrease) {
      changeColor = Colors.green[600]!;
      changeIcon = Icons.trending_up;
    } else if (isDecrease) {
      changeColor = Colors.red[600]!;
      changeIcon = Icons.trending_down;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: changeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              changeIcon,
              color: changeColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_formatPrice(item.newPrice)} VNĐ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.oldPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(từ ${_formatPrice(item.oldPrice!)})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(item.changedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (item.reason != null && item.reason!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.reason!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.oldPrice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: changeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isIncrease
                  ? '+${((item.newPrice - item.oldPrice!) / item.oldPrice! * 100).toStringAsFixed(1)}%'
                  : '${((item.newPrice - item.oldPrice!) / item.oldPrice! * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: changeColor,
                ),
              ),
            ),
        ],
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }

  void _showFullHistory() {
    // TODO: Implement full price history screen
    // This would show all price changes in a separate screen
  }
}