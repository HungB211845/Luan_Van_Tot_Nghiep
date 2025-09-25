import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          ],
        ),
      ),
    );
  }
}
