import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';

class EditBatchScreen extends StatefulWidget {
  final ProductBatch batch;
  const EditBatchScreen({Key? key, required this.batch}) : super(key: key);

  @override
  State<EditBatchScreen> createState() => _EditBatchScreenState();
}

class _EditBatchScreenState extends State<EditBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _batchNumberController;
  late TextEditingController _quantityController;
  late TextEditingController _costPriceController;
  late TextEditingController _supplierBatchIdController;
  late TextEditingController _notesController;

  // Date fields
  late DateTime _receivedDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    // Khởi tạo form với dữ liệu từ batch có sẵn
    _batchNumberController = TextEditingController(text: widget.batch.batchNumber);
    _quantityController = TextEditingController(text: widget.batch.quantity.toString());
    _costPriceController = TextEditingController(text: widget.batch.costPrice.toString());
    _supplierBatchIdController = TextEditingController(text: widget.batch.supplierBatchId ?? '');
    _notesController = TextEditingController(text: widget.batch.notes ?? '');
    _receivedDate = widget.batch.receivedDate;
    _expiryDate = widget.batch.expiryDate;
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _supplierBatchIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final selectedProduct = provider.selectedProduct;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh Sửa Lô Hàng'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedProduct != null) _buildProductInfo(selectedProduct),
              const SizedBox(height: 24),
              _buildBatchForm(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(dynamic selectedProduct) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sản phẩm: ${selectedProduct.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('SKU: ${selectedProduct.sku}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchForm() {
    // ... (Giữ nguyên layout form từ AddBatchScreen)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _batchNumberController,
          decoration: const InputDecoration(labelText: 'Mã lô *'),
          validator: (value) => (value?.isEmpty ?? true) ? 'Vui lòng nhập mã lô' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(labelText: 'Số lượng *'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
              return 'Số lượng phải là số dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _costPriceController,
          decoration: const InputDecoration(labelText: 'Giá vốn *'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
              return 'Giá vốn phải là số dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // ... Các trường date và optional fields khác
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updateBatch,
      child: _isLoading ? const CircularProgressIndicator() : const Text('Lưu Thay Đổi'),
    );
  }

  Future<void> _updateBatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final updatedBatch = widget.batch.copyWith(
        batchNumber: _batchNumberController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        costPrice: double.parse(_costPriceController.text.trim()),
        receivedDate: _receivedDate,
        expiryDate: _expiryDate,
        supplierBatchId: _supplierBatchIdController.text.trim(),
        notes: _notesController.text.trim(),
      );

      final success = await provider.updateProductBatch(updatedBatch);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật lô hàng thành công'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
