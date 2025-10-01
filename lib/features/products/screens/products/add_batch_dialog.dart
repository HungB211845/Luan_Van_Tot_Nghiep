import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';
import '../../providers/company_provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/services/base_service.dart';

class AddBatchManualDialog extends StatefulWidget {
  const AddBatchManualDialog({super.key});

  @override
  State<AddBatchManualDialog> createState() => _AddBatchManualDialogState();
}

class _AddBatchManualDialogState extends State<AddBatchManualDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _receivedDate = DateTime.now();
  DateTime? _expiryDate;
  String? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    context.read<CompanyProvider>().loadCompanies();
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _generateBatchCode() {
    final now = DateTime.now();
    final random = Random();
    final randomNum = random.nextInt(9999).toString().padLeft(4, '0');
    return 'LOT${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$randomNum';
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final product = provider.selectedProduct!;

      final batch = ProductBatch(
        id: '', 
        productId: product.id,
        batchNumber: _batchNumberController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        costPrice: double.parse(_costPriceController.text.trim()),
        receivedDate: _receivedDate,
        expiryDate: _expiryDate,
        supplierId: _selectedSupplierId,
        storeId: BaseService.getDefaultStoreId() ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await provider.addProductBatch(batch);

      if (success && mounted) {
        await provider.loadProductBatches(product.id);
        Navigator.of(context).pop(true); // Pop dialog with success
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nhập Kho Thủ Công'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // All form fields combined
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _batchNumberController,
                        decoration: const InputDecoration(labelText: 'Mã lô *'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mã lô' : null,
                      ),
                    ),
                    IconButton(onPressed: () => _batchNumberController.text = _generateBatchCode(), icon: const Icon(Icons.casino), tooltip: 'Tạo mã tự động'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: 'Số lượng *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0) ? 'Số lượng > 0' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costPriceController,
                        decoration: const InputDecoration(labelText: 'Giá vốn *'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null || double.parse(v) < 0) ? 'Giá >= 0' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _receivedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) setState(() => _receivedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Ngày nhập *', border: OutlineInputBorder()),
                    child: Text(AppFormatter.formatDate(_receivedDate)),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _expiryDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hạn sử dụng', border: OutlineInputBorder()),
                    child: Text(_expiryDate == null ? 'Chọn ngày (tùy chọn)' : AppFormatter.formatDate(_expiryDate!)),
                  ),
                ),
                const SizedBox(height: 16),
                Consumer<CompanyProvider>(
                  builder: (context, provider, _) {
                    return DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(labelText: 'Nhà cung cấp (tùy chọn)', border: OutlineInputBorder()),
                      items: provider.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (value) => setState(() => _selectedSupplierId = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBatch,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Lưu Lô Hàng'),
        ),
      ],
    );
  }
}
