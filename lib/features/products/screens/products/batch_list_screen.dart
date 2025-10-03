import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/utils/formatter.dart';

class BatchListScreen extends StatefulWidget {
  final String productId;

  const BatchListScreen({Key? key, required this.productId}) : super(key: key);

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProductBatchesPaginated(productId: widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Lô Hàng'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.productBatches.isEmpty) {
            return const Center(child: LoadingWidget());
          }
          if (provider.productBatches.isEmpty) {
            return const Center(child: Text('Không có lô hàng nào.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.productBatches.length,
            itemBuilder: (context, index) {
              final batch = provider.productBatches[index];
              return _buildBatchListItem(batch);
            },
          );
        },
      ),
    );
  }

  Widget _buildBatchListItem(ProductBatch batch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mã lô: ${batch.batchNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Số lượng: ${batch.quantity} ${widget.product.unit}'),
            Text('Giá vốn: ${AppFormatter.formatCurrency(batch.costPrice)}'),
            Text('Ngày nhập: ${AppFormatter.formatDate(batch.receivedDate)}'),
            if (batch.expiryDate != null)
              Text('Hạn sử dụng: ${AppFormatter.formatDate(batch.expiryDate!)}'),
            if (batch.isExpired)
              const Text('ĐÃ HẾT HẠN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            else if (batch.isExpiringSoon)
              const Text('SẮP HẾT HẠN', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
