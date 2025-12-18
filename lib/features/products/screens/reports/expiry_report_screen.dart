import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routing/route_names.dart';
import '../../providers/product_provider.dart';
import '../../models/product_batch.dart';
import '../../../../shared/utils/formatter.dart';

class ExpiryReportScreen extends StatefulWidget {
  const ExpiryReportScreen({Key? key}) : super(key: key);

  @override
  State<ExpiryReportScreen> createState() => _ExpiryReportScreenState();
}

class _ExpiryReportScreenState extends State<ExpiryReportScreen> {
  int _selectedMonth = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadExpiringBatchesReport(months: _selectedMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo hàng sắp hết hạn'),
      ),
      body: Column(
        children: [
          _buildFilter(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.expiringBatches.isEmpty) {
                  return const Center(
                    child: Text('Không có lô hàng nào sắp hết hạn trong thời gian đã chọn.'),
                  );
                }

                return ListView.builder(
                  itemCount: provider.expiringBatches.length,
                  itemBuilder: (context, index) {
                    final batch = provider.expiringBatches[index];
                    return _buildBatchCard(batch);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Hết hạn trong:'),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: _selectedMonth,
            items: [1, 3, 6].map((int value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value tháng'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedMonth = newValue;
                });
                context.read<ProductProvider>().loadExpiringBatchesReport(months: newValue);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(batch['product_name'] ?? 'Không rõ sản phẩm'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lô: ${batch['batch_number']}'),
            Text('Tồn kho: ${batch['remaining_quantity']}'),
            Text('Ngày hết hạn: ${AppFormatter.formatDate(DateTime.parse(batch['expiry_date']))}'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                'SẮP HẾT HẠN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // Show batch detail in a dialog/bottom sheet since we don't have full ProductBatch object
          _showBatchDetailDialog(context, batch);
        },
        trailing: Icon(
          Icons.info_outline,
          color: Colors.orange,
        ),
      ),
    );
  }

  void _showBatchDetailDialog(BuildContext context, Map<String, dynamic> batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết lô hàng',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sắp hết hạn',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Batch Details
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('Sản phẩm', batch['product_name'] ?? 'N/A'),
                    _buildDetailRow('Mã lô', batch['batch_number'] ?? 'N/A'),
                    _buildDetailRow('Tồn kho hiện tại', '${batch['remaining_quantity'] ?? 'N/A'}'),
                    _buildDetailRow('Ngày hết hạn', AppFormatter.formatDate(DateTime.parse(batch['expiry_date']))),
                    if (batch['cost_price'] != null)
                      _buildDetailRow('Giá nhập', AppFormatter.formatCurrency(batch['cost_price'])),
                    
                    const SizedBox(height: 20),
                    
                    // Warning section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cảnh báo hết hạn',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lô hàng này sẽ hết hạn trong thời gian tới. Cân nhắc khuyến mãi hoặc xử lý nhanh chóng.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
