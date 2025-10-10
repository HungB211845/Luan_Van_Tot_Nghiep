import 'package:flutter/material.dart';
import '../../../../features/reports/services/report_service.dart';
import '../../../../shared/utils/formatter.dart';

class SlowMovingReportScreen extends StatefulWidget {
  const SlowMovingReportScreen({Key? key}) : super(key: key);

  @override
  State<SlowMovingReportScreen> createState() => _SlowMovingReportScreenState();
}

class _SlowMovingReportScreenState extends State<SlowMovingReportScreen> {
  final ReportService _reportService = ReportService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  int _selectedDays = 90;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _reportService.getSlowMovingProducts(days: _selectedDays);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Hàng Bán Chậm'),
        backgroundColor: Colors.grey.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilter(),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_products.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'Tất cả sản phẩm đều bán chạy!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductCard(product);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Không bán trong:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: _selectedDays,
            items: [30, 60, 90, 180].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value ngày'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() => _selectedDays = newValue);
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final currentStock = product['current_stock'] as int? ?? 0;
    final daysSinceLastSale = (product['days_since_last_sale'] as num?)?.toInt() ?? 0;
    final lastSaleDate = product['last_sale_date'] as String?;

    // Calculate severity based on days
    Color severityColor;
    IconData severityIcon;
    String severityLabel;

    if (daysSinceLastSale >= 180) {
      severityColor = Colors.red.shade700;
      severityIcon = Icons.error;
      severityLabel = 'NGHIÊM TRỌNG';
    } else if (daysSinceLastSale >= 90) {
      severityColor = Colors.orange;
      severityIcon = Icons.warning_amber;
      severityLabel = 'CẢNH BÁO';
    } else {
      severityColor = Colors.grey;
      severityIcon = Icons.info;
      severityLabel = 'THEO DÕI';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(severityIcon, color: severityColor),
        ),
        title: Text(
          product['product_name'] ?? 'Không rõ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('SKU: ${product['sku'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Tồn kho: ',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                Text(
                  '$currentStock',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$daysSinceLastSale ngày không bán',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (lastSaleDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'Bán gần nhất: ${AppFormatter.formatDate(DateTime.parse(lastSaleDate))}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: severityColor.withOpacity(0.3)),
              ),
              child: Text(
                severityLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_down, color: severityColor, size: 20),
            Text(
              '$daysSinceLastSale',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: severityColor,
              ),
            ),
            Text(
              'ngày',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
