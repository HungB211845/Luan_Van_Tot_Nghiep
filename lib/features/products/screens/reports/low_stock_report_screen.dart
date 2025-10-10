import 'package:flutter/material.dart';
import '../../../../features/reports/services/report_service.dart';
import '../../../../shared/utils/formatter.dart';

class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({Key? key}) : super(key: key);

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  final ReportService _reportService = ReportService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  int _selectedThreshold = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _reportService.getLowStockProducts(threshold: _selectedThreshold);
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
        title: const Text('Báo Cáo Tồn Kho Thấp'),
        backgroundColor: Colors.orange,
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
                    Icon(Icons.check_circle, size: 64, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'Tất cả sản phẩm đều có tồn kho đầy đủ!',
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
          const Text('Ngưỡng cảnh báo:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: _selectedThreshold,
            items: [5, 10, 20, 50].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('≤ $value sản phẩm'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() => _selectedThreshold = newValue);
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
    final minStockLevel = product['min_stock_level'] as int? ?? 0;

    // Calculate severity: critical (<50%), warning (<100%), info (>=100%)
    final percentage = minStockLevel > 0 ? (currentStock / minStockLevel) * 100 : 100;
    Color severityColor;
    IconData severityIcon;
    String severityLabel;

    if (currentStock == 0) {
      severityColor = Colors.red;
      severityIcon = Icons.error;
      severityLabel = 'HẾT HÀNG';
    } else if (percentage < 50) {
      severityColor = Colors.red.shade700;
      severityIcon = Icons.warning;
      severityLabel = 'NGHIÊM TRỌNG';
    } else if (percentage < 100) {
      severityColor = Colors.orange;
      severityIcon = Icons.warning_amber;
      severityLabel = 'CẢNH BÁO';
    } else {
      severityColor = Colors.blue;
      severityIcon = Icons.info;
      severityLabel = 'THÔNG TIN';
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
                Text(
                  ' / Tối thiểu: $minStockLevel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
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
      ),
    );
  }
}
