import 'package:flutter/material.dart';
import '../models/product.dart';
import '../../../shared/utils/formatter.dart';

class KeyMetricsWidget extends StatelessWidget {
  final Product product;
  final double totalStock;
  final double averageCostPrice;
  final double grossProfitPercentage;

  const KeyMetricsWidget({
    Key? key,
    required this.product,
    required this.totalStock,
    required this.averageCostPrice,
    required this.grossProfitPercentage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông Tin Quan Trọng',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Tồn Kho',
                        '${AppFormatter.formatNumber(totalStock.toInt())}',
                        product.unit.isNotEmpty ? product.unit : 'đơn vị',
                        Icons.inventory_2,
                        _getStockColor(totalStock),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Giá Bán Hiện Tại',
                        AppFormatter.formatCompactCurrency(product.currentSellingPrice),
                        '',
                        Icons.attach_money,
                        Colors.blue[600]!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Giá Vốn TB',
                        AppFormatter.formatCompactCurrency(averageCostPrice),
                        '',
                        Icons.receipt,
                        Colors.orange[600]!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Lợi Nhuận Gộp',
                        '${grossProfitPercentage.toStringAsFixed(1)}',
                        '%',
                        Icons.trending_up,
                        _getProfitColor(grossProfitPercentage),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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

  Color _getProfitColor(double percentage) {
    if (percentage <= 0) {
      return Colors.red[600]!;
    } else if (percentage <= 10) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }
}