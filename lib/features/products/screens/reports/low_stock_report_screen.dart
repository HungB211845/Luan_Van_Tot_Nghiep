import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/product_service.dart';
import '../../providers/product_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/utils/formatter.dart';

class LowStockReportScreen extends StatefulWidget {
  const LowStockReportScreen({Key? key}) : super(key: key);

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  final ProductService _productService = ProductService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Use same data source as ProductProvider for consistency
      final products = await _productService.getLowStockProducts();
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
          // Info header explaining the logic
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.orange.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hiển thị sản phẩm có tồn kho hiện tại ≤ mức tồn kho tối thiểu',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildProductCard(Map<String, dynamic> product) {
    final currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0.0;
    final minStockLevel = (product['min_stock_level'] as num?)?.toDouble() ?? 0.0;

    // Calculate severity: critical (<50%), warning (<100%), info (>=100%)
    final percentage = minStockLevel > 0 ? (currentStock / minStockLevel) * 100 : 100;
    Color severityColor;
    IconData severityIcon;
    String severityLabel;

    if (currentStock <= 0) {
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
          product['name'] ?? 'Không rõ',
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
                  _formatStockValue(currentStock),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
                Text(
                  ' / Tối thiểu: ${_formatStockValue(minStockLevel)}',
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
        onTap: () => _navigateToProductDetail(product),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _navigateToProductDetail(Map<String, dynamic> productData) async {
    if (productData['id'] == null) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final productProvider = context.read<ProductProvider>();
      
      // Fetch full product by ID
      final product = await productProvider.fetchProductById(productData['id']);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (product != null) {
        // Select the product in provider
        productProvider.selectProduct(product);
        
        // Navigate to product detail screen
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushNamed(RouteNames.productDetail);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy thông tin sản phẩm'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải chi tiết sản phẩm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatStockValue(double value) {
    // Format as integer if it's a whole number, otherwise show 1 decimal place
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(1);
    }
  }
}
