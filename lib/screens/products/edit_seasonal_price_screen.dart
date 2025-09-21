import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/seasonal_price.dart';
import '../../providers/product_provider.dart';

class EditSeasonalPriceScreen extends StatefulWidget {
  final SeasonalPrice price;
  const EditSeasonalPriceScreen({Key? key, required this.price}) : super(key: key);

  @override
  State<EditSeasonalPriceScreen> createState() => _EditSeasonalPriceScreenState();
}

class _EditSeasonalPriceScreenState extends State<EditSeasonalPriceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _sellingPriceController;
  late TextEditingController _seasonNameController;
  late TextEditingController _notesController;

  // Date fields
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    // Khởi tạo form với dữ liệu từ price có sẵn
    _sellingPriceController = TextEditingController(text: widget.price.sellingPrice.toString());
    _seasonNameController = TextEditingController(text: widget.price.seasonName);
    _notesController = TextEditingController(text: widget.price.notes ?? '');
    _startDate = widget.price.startDate;
    _endDate = widget.price.endDate;
  }

  @override
  void dispose() {
    _sellingPriceController.dispose();
    _seasonNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final selectedProduct = provider.selectedProduct;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh Sửa Mức Giá'),
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
              _buildPriceForm(),
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

  Widget _buildPriceForm() {
    // ... (Giữ nguyên layout form từ AddSeasonalPriceScreen)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _sellingPriceController,
          decoration: const InputDecoration(labelText: 'Giá bán *'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
              return 'Giá bán phải là số dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _seasonNameController,
          decoration: const InputDecoration(labelText: 'Tên mùa vụ *'),
          validator: (value) => (value?.isEmpty ?? true) ? 'Vui lòng nhập tên mùa vụ' : null,
        ),
        const SizedBox(height: 16),
        // ... Các trường date và optional fields khác
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updatePrice,
      child: _isLoading ? const CircularProgressIndicator() : const Text('Lưu Thay Đổi'),
    );
  }

  Future<void> _updatePrice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final updatedPrice = widget.price.copyWith(
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        seasonName: _seasonNameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.trim(),
      );

      final success = await provider.updateSeasonalPrice(updatedPrice);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật giá thành công'), backgroundColor: Colors.green),
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
