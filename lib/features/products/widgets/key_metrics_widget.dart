import 'package:flutter/material.dart';
import '../models/product.dart';
import '../../../shared/utils/formatter.dart';
import '../../../shared/utils/input_formatters.dart';

class KeyMetricsWidget extends StatelessWidget {
  final Product product;
  final double totalStock;
  final double averageCostPrice;
  final double grossProfitPercentage;
  final bool isEditMode;
  final bool isMetricsLoading; // 🚀 NEW: Loading state for metrics
  final TextEditingController? priceController;
  final VoidCallback? onPriceTap;
  final VoidCallback? onEnterEditMode;
  final VoidCallback? onExitEditMode;
  final VoidCallback? onSavePrice;

  const KeyMetricsWidget({
    Key? key,
    required this.product,
    required this.totalStock,
    required this.averageCostPrice,
    required this.grossProfitPercentage,
    this.isEditMode = false,
    this.isMetricsLoading = false, // 🚀 NEW: Default to not loading
    this.priceController,
    this.onPriceTap,
    this.onEnterEditMode,
    this.onExitEditMode,
    this.onSavePrice,
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
                        Colors.grey[300]!, // Neutral background
                        Colors.grey[800]!, // Dark text
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPriceCard(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Giá Vốn TB',
                        isMetricsLoading ? '...' : AppFormatter.formatCompactCurrency(averageCostPrice),
                        isMetricsLoading ? '' : '',
                        Icons.receipt,
                        Colors.grey[300]!, // Neutral background
                        Colors.grey[800]!, // Dark text
                        isLoading: isMetricsLoading,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Lợi Nhuận Gộp',
                        isMetricsLoading ? '...' : '${grossProfitPercentage.toStringAsFixed(1)}',
                        isMetricsLoading ? '' : '%',
                        Icons.trending_up,
                        _getProfitColor(grossProfitPercentage).withOpacity(0.1), // Colored background based on value
                        _getProfitColor(grossProfitPercentage), // Colored text based on value
                        isLoading: isMetricsLoading,
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
    Color backgroundColor,
    Color textColor, {
    bool isLoading = false, // 🚀 ADD: Named parameter for loading state
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
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
          if (isLoading)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
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

  Widget _buildPriceCard() {
    if (isEditMode && priceController != null) {
      // Edit mode: show TextField
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue[50]!, // Light blue background to indicate edit mode
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[300]!),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.blue[600], size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Giá Bán Hiện Tại',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyInputFormatter(maxValue: 999999999), // Max 999M
              ],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                suffix: Text(
                  'VNĐ',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Normal mode: show read-only metric card with tap gesture
      return GestureDetector(
        onTap: onPriceTap,
        child: _buildMetricCard(
          'Giá Bán Hiện Tại',
          AppFormatter.formatCompactCurrency(product.currentSellingPrice),
          '',
          Icons.attach_money,
          Colors.grey[300]!, // Neutral background
          Colors.grey[800]!, // Dark text
        ),
      );
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