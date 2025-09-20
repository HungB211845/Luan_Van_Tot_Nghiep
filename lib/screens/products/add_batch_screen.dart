import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_batch.dart';
import '../../providers/product_provider.dart';

class AddBatchScreen extends StatefulWidget {
  const AddBatchScreen({Key? key}) : super(key: key);

  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers cho form fields
  final _batchNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _supplierBatchIdController = TextEditingController();
  final _notesController = TextEditingController();

  // Date fields
  DateTime _receivedDate = DateTime.now();
  DateTime? _expiryDate;

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
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final selectedProduct = provider.selectedProduct;

        if (selectedProduct == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Thêm Lô Hàng'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Text(
                'Không tìm thấy sản phẩm được chọn',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Thêm Lô Hàng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hiển thị thông tin sản phẩm
                  _buildProductInfo(selectedProduct),

                  const SizedBox(height: 24),

                  // Form nhập liệu
                  _buildBatchForm(),

                  const SizedBox(height: 32),

                  // Nút lưu
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductInfo(dynamic selectedProduct) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sản phẩm được chọn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              selectedProduct.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SKU: ${selectedProduct.sku}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông tin lô hàng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Mã lô
        TextFormField(
          controller: _batchNumberController,
          decoration: _buildInputDecoration(
            label: 'Mã lô *',
            hint: 'Ví dụ: LOT001, B2024001',
            icon: Icons.qr_code,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập mã lô';
            }
            if (value.trim().length < 2) {
              return 'Mã lô phải có ít nhất 2 ký tự';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Số lượng và Giá vốn
        Row(
          children: [
            // Số lượng
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: _buildInputDecoration(
                  label: 'Số lượng *',
                  hint: '100',
                  icon: Icons.inventory_2,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số lượng';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Số lượng phải là số dương';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(width: 16),

            // Giá vốn
            Expanded(
              child: TextFormField(
                controller: _costPriceController,
                decoration: _buildInputDecoration(
                  label: 'Giá vốn *',
                  hint: '50000',
                  icon: Icons.attach_money,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập giá vốn';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Giá vốn phải là số dương';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Ngày nhập và Hạn sử dụng
        Row(
          children: [
            // Ngày nhập
            Expanded(
              child: InkWell(
                onTap: () => _selectReceivedDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Ngày nhập *',
                    icon: Icons.calendar_today,
                  ),
                  child: Text(
                    _formatDate(_receivedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Hạn sử dụng
            Expanded(
              child: InkWell(
                onTap: () => _selectExpiryDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Hạn sử dụng',
                    icon: Icons.event_busy,
                  ),
                  child: Text(
                    _expiryDate != null
                        ? _formatDate(_expiryDate!)
                        : 'Chọn ngày',
                    style: TextStyle(
                      fontSize: 16,
                      color: _expiryDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Mã lô nhà cung cấp
        TextFormField(
          controller: _supplierBatchIdController,
          decoration: _buildInputDecoration(
            label: 'Mã lô nhà cung cấp',
            hint: 'Mã lô từ nhà cung cấp (tùy chọn)',
            icon: Icons.business,
          ),
        ),

        const SizedBox(height: 16),

        // Ghi chú
        TextFormField(
          controller: _notesController,
          decoration: _buildInputDecoration(
            label: 'Ghi chú',
            hint: 'Ghi chú thêm về lô hàng này (tùy chọn)',
            icon: Icons.note,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveBatch,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Lưu Lô Hàng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).primaryColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }

  Future<void> _selectReceivedDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null && picked != _receivedDate) {
      setState(() {
        _receivedDate = picked;
      });
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? _receivedDate.add(const Duration(days: 365)),
      firstDate: _receivedDate,
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveBatch() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hiển thị loading
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ProductProvider>();
      final selectedProduct = provider.selectedProduct;

      if (selectedProduct == null) {
        throw Exception('Không tìm thấy sản phẩm được chọn');
      }

      // Tạo object ProductBatch hoàn chỉnh
      final newBatch = ProductBatch(
        id: '', // Sẽ được tạo bởi database
        productId: selectedProduct.id,
        batchNumber: _batchNumberController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        costPrice: double.parse(_costPriceController.text.trim()),
        receivedDate: _receivedDate,
        expiryDate: _expiryDate,
        supplierBatchId: _supplierBatchIdController.text.trim().isNotEmpty
            ? _supplierBatchIdController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Gọi Provider để lưu
      final success = await provider.addProductBatch(newBatch);

      if (success) {
        // Thành công
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm lô hàng thành công'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Thất bại
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Có lỗi xảy ra khi thêm lô hàng',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Xử lý exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không mong muốn: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Ẩn loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}