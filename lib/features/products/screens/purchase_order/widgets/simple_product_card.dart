import 'package:flutter/material.dart';
import '../../../models/product.dart';

class SimpleProductCard extends StatelessWidget {
  final Product product;
  final int currentStock;
  final double? lastPrice;
  final bool isInCart;
  final int cartQuantity;
  final VoidCallback onTap;

  const SimpleProductCard({
    Key? key,
    required this.product,
    required this.currentStock,
    this.lastPrice,
    required this.isInCart,
    required this.cartQuantity,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();
    final isLowStock = currentStock <= 10;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInCart ? Colors.green[200]! : Colors.grey[200]!,
            width: isInCart ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean product header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(),
                      color: categoryColor,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Product info - Essential only
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (product.sku != null) ...[
                          Text(
                            product.sku!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getCategoryLabel(),
                            style: TextStyle(
                              fontSize: 12,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Simple status indicator
                  if (isInCart)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$cartQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Key decision info only
              Row(
                children: [
                  // Reference price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 Giá nhập gần nhất',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastPrice != null
                              ? _formatCurrency(lastPrice!)
                              : 'Chưa có giá',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stock level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📦 Tồn kho',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '$currentStock',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isLowStock
                                    ? Colors.red[600]
                                    : Colors.black87,
                              ),
                            ),
                            if (isLowStock) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.warning_outlined,
                                size: 16,
                                color: Colors.red[600],
                              ),
                            ],
                          ],
                        ),
                        if (isLowStock)
                          Text(
                            'Sắp hết hàng',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Clear call to action
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  isInCart
                      ? '✅ Đã chọn - Chạm để chỉnh sửa'
                      : '👆 Chạm để thêm vào giỏ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isInCart ? Colors.green[700] : Colors.grey[600],
                    fontWeight: isInCart ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (product.category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  IconData _getCategoryIcon() {
    switch (product.category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  String _getCategoryLabel() {
    switch (product.category) {
      case ProductCategory.FERTILIZER:
        return 'Phân bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa giống';
    }
  }

  String _formatCurrency(double amount) {
    if (amount == amount.toInt()) {
      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
    } else {
      String formatted = amount.toStringAsFixed(1);
      formatted = formatted.replaceAll('.', ',');
      List<String> parts = formatted.split(',');
      parts[0] = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '${parts.join(',')}₫';
    }
  }
}
