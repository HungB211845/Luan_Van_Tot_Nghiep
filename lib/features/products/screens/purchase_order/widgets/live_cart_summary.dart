import 'package:flutter/material.dart';
import '../../../providers/purchase_order_provider.dart';

class LiveCartSummary extends StatelessWidget {
  final List<POCartItem> cartItems;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onFinish;
  final Function(String) onRemoveItem;
  final Function(String, int, String) onUpdateQuantity;

  const LiveCartSummary({
    Key? key,
    required this.cartItems,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.onFinish,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalItems = cartItems.length;
    final totalAmount = cartItems.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitCost),
    );

    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        children: [
          // Cart summary header
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: Colors.green[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giỏ nhập: $totalItems sản phẩm',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatCurrency(totalAmount),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Finish button when items exist
                  if (onFinish != null && totalItems > 0) ...[
                    ElevatedButton(
                      onPressed: onFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Xong',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.green[700],
                  ),
                ],
              ),
            ),
          ),

          // Expanded cart details
          if (isExpanded) ...[
            const Divider(height: 1, color: Colors.green),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return _buildCartItem(item);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(POCartItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.quantity} ${item.unit ?? 'cái'} × ${_formatCurrency(item.unitCost)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Quantity controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrease button
              IconButton(
                onPressed: item.quantity > 1
                    ? () => onUpdateQuantity(
                        item.product.id,
                        item.quantity - 1,
                        item.unit ?? 'cái',
                      )
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 20,
                color: item.quantity > 1 ? Colors.green[600] : Colors.grey[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 8),

              // Quantity display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Increase button
              IconButton(
                onPressed: () => onUpdateQuantity(
                  item.product.id,
                  item.quantity + 1,
                  item.unit ?? 'cái',
                ),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 20,
                color: Colors.green[600],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Remove button
          IconButton(
            onPressed: () => onRemoveItem(item.product.id),
            icon: const Icon(Icons.delete_outline),
            iconSize: 20,
            color: Colors.red[400],
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    // Format with thousand separators and decimal places
    if (amount == amount.toInt()) {
      // No decimal places needed
      return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
    } else {
      // Show decimal places
      String formatted = amount.toStringAsFixed(1);
      // Replace . with , for decimal separator (Vietnamese format)
      formatted = formatted.replaceAll('.', ',');
      // Add thousand separators
      List<String> parts = formatted.split(',');
      parts[0] = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '${parts.join(',')}₫';
    }
  }
}
