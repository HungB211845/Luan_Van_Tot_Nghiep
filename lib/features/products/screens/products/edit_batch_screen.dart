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
        backgroundColor: Colors.green,
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
              _buildActionButtons(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _batchNumberController,
          decoration: const InputDecoration(
            labelText: 'Mã lô *',
            border: OutlineInputBorder(),
          ),
          validator: (value) => (value?.isEmpty ?? true) ? 'Vui lòng nhập mã lô' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _quantityController,
          decoration: const InputDecoration(
            labelText: 'Số lượng *',
            border: OutlineInputBorder(),
          ),
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
          decoration: const InputDecoration(
            labelText: 'Giá vốn *',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
              return 'Giá vốn phải là số dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Received Date
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _receivedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _receivedDate = picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Ngày nhập *',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text('${_receivedDate.day}/${_receivedDate.month}/${_receivedDate.year}'),
          ),
        ),
        const SizedBox(height: 16),
        // Expiry Date
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _expiryDate = picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Hạn sử dụng (tùy chọn)',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(_expiryDate == null
              ? 'Chọn ngày hết hạn'
              : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _supplierBatchIdController,
          decoration: const InputDecoration(
            labelText: 'Mã lô nhà cung cấp (tùy chọn)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (tùy chọn)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Nút Xóa (50%)
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _deleteBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Xóa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        // Nút Lưu Thay Đổi (50%)
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Lưu Thay Đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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

  Future<void> _deleteBatch() async {
    // Xác nhận xóa với dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa lô hàng "${widget.batch.batchNumber}"?\n\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final success = await provider.deleteProductBatch(widget.batch.id, widget.batch.productId);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xóa lô hàng thành công'), backgroundColor: Colors.green),
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
