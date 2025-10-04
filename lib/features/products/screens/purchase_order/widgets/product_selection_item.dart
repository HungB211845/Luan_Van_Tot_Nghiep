import 'package:flutter/material.dart';
import '../../../models/product.dart';

class ProductSelectionItem extends StatelessWidget {
  final Product product;
  final int currentStock;
  final double? lastPrice;
  final bool isInCart;
  final int cartQuantity;
  final VoidCallback onTap;

  const ProductSelectionItem({
    super.key,
    required this.product,
    required this.currentStock,
    this.lastPrice,
    required this.isInCart,
    required this.cartQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory, color: Colors.grey),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tồn kho: $currentStock'),
            if (lastPrice != null)
              Text('Giá gần nhất: ${lastPrice!.toStringAsFixed(0)}đ'),
          ],
        ),
        trailing: isInCart
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$cartQuantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.add_circle_outline, color: Colors.green),
      ),
    );
  }
}