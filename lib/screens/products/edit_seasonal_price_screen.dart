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

  // Controllers cho form fields
  final _sellingPriceController = TextEditingController();
  final _seasonNameController = TextEditingController();
  final _notesController = TextEditingController();

  // Date fields
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));

  @override
  void initState() {
    super.initState();
    // Điền dữ liệu từ price vào các controller
    _sellingPriceController.text = widget.price.sellingPrice.toString();
    _seasonNameController.text = widget.price.seasonName;
    _notesController.text = widget.price.notes ?? '';
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
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        final selectedProduct = provider.selectedProduct;

        if (selectedProduct == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sửa Mức Giá'),
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
              'Sửa Mức Giá',
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
                  _buildPriceForm(),

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
                  Icons.trending_up,
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

  Widget _buildPriceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thông tin mức giá',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Giá bán
        TextFormField(
          controller: _sellingPriceController,
          decoration: _buildInputDecoration(
            label: 'Giá bán *',
            hint: 'Ví dụ: 75000',
            icon: Icons.attach_money,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập giá bán';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Giá bán phải là số dương';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Tên mùa vụ
        TextFormField(
          controller: _seasonNameController,
          decoration: _buildInputDecoration(
            label: 'Tên mùa vụ *',
            hint: 'Ví dụ: Vụ Hè Thu 2025, Giá Tết',
            icon: Icons.wb_sunny,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập tên mùa vụ';
            }
            if (value.trim().length < 3) {
              return 'Tên mùa vụ phải có ít nhất 3 ký tự';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Ngày bắt đầu và Ngày kết thúc
        Row(
          children: [
            // Ngày bắt đầu
            Expanded(
              child: InkWell(
                onTap: () => _selectStartDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Ngày bắt đầu *',
                    icon: Icons.calendar_today,
                  ),
                  child: Text(
                    _formatDate(_startDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Ngày kết thúc
            Expanded(
              child: InkWell(
                onTap: () => _selectEndDate(context),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    label: 'Ngày kết thúc *',
                    icon: Icons.event,
                  ),
                  child: Text(
                    _formatDate(_endDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Hiển thị số ngày áp dụng
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thời gian áp dụng: ${_calculateDuration()} ngày',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Ghi chú
        TextFormField(
          controller: _notesController,
          decoration: _buildInputDecoration(
            label: 'Ghi chú',
            hint: 'Ghi chú thêm về mức giá này (tùy chọn)',
            icon: Icons.note,
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _savePrice,
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
              'Cập Nhật Mức Giá',
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

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Đảm bảo ngày kết thúc không sớm hơn ngày bắt đầu
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate)
          ? _startDate.add(const Duration(days: 1))
          : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _calculateDuration() {
    return _endDate.difference(_startDate).inDays + 1;
  }

  String? _validateDates() {
    if (_endDate.isBefore(_startDate)) {
      return 'Ngày kết thúc không thể sớm hơn ngày bắt đầu';
    }
    if (_startDate.isAtSameMomentAs(_endDate)) {
      return 'Ngày kết thúc phải sau ngày bắt đầu';
    }
    return null;
  }

  Future<void> _savePrice() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate dates
    final dateError = _validateDates();
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dateError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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

      // Tạo object SeasonalPrice với dữ liệu đã cập nhật
      final updatedPrice = widget.price.copyWith(
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        seasonName: _seasonNameController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Gọi Provider để cập nhật
      final success = await provider.updateSeasonalPrice(updatedPrice);

      if (success) {
        // Thành công
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật giá thành công'),
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
                    : 'Có lỗi xảy ra khi cập nhật mức giá',
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