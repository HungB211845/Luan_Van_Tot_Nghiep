import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../../../shared/utils/input_formatters.dart';
import '../../../shared/utils/formatter.dart';

/// Temporary simple formatter to fix input issues
class SimpleCurrencyInputFormatter extends TextInputFormatter {
  SimpleCurrencyInputFormatter({this.maxValue});

  final double? maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handle empty input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Extract only digits
    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Return empty if no numbers
    if (numbersOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse as integer
    int value;
    try {
      value = int.parse(numbersOnly);
    } catch (e) {
      return oldValue;
    }

    // Check max value constraint
    if (maxValue != null && value > maxValue!) {
      return oldValue;
    }

    // Simple manual formatting to avoid NumberFormat issues
    String formattedText = _formatManually(value);

    // Return with cursor at end
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String _formatManually(int value) {
    if (value == 0) return '0';
    
    String valueStr = value.toString();
    String result = '';
    int count = 0;
    
    // Add dots from right to left every 3 digits
    for (int i = valueStr.length - 1; i >= 0; i--) {
      if (count == 3) {
        result = '.' + result;
        count = 0;
      }
      result = valueStr[i] + result;
      count++;
    }
    
    return result;
  }
}

class QuickAddBatchSheet extends StatefulWidget {
  final Product product;
  final VoidCallback? onBatchAdded;

  const QuickAddBatchSheet({
    Key? key,
    required this.product,
    this.onBatchAdded,
  }) : super(key: key);

  @override
  State<QuickAddBatchSheet> createState() => _QuickAddBatchSheetState();
}

class _QuickAddBatchSheetState extends State<QuickAddBatchSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _newSellingPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // FIXED: Initialize with formatted price
    _newSellingPriceController.text = AppFormatter.formatNumber(widget.product.currentSellingPrice);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _costPriceController.dispose();
    _newSellingPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildForm(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.add_box,
          size: 48,
          color: Colors.blue[600],
        ),
        const SizedBox(height: 8),
        Text(
          'Nhập Lô Nhanh',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.product.name,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            labelText: 'Số lượng *',
            border: const OutlineInputBorder(),
            suffixText: widget.product.unit.isNotEmpty ? widget.product.unit : 'đơn vị',
            prefixIcon: const Icon(Icons.inventory_2),
            helperText: 'Ví dụ: 1.000',
          ),
          // FIXED: Use simple formatter for quantity field
          keyboardType: TextInputType.number,
          inputFormatters: [
            SimpleCurrencyInputFormatter(maxValue: 999999),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập số lượng';
            }
            // FIXED: Use simple extraction method
            final quantity = _extractSimpleNumber(value)?.toInt();
            if (quantity == null || quantity <= 0) {
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
            suffixText: 'VNĐ',
            prefixIcon: Icon(Icons.receipt),
            helperText: 'Ví dụ: 15.000',
          ),
          // FIXED: Use numeric keyboard and currency formatter
          keyboardType: InputFormatterHelper.getNumericKeyboard(allowDecimal: false),
          inputFormatters: [
            CurrencyInputFormatter(maxValue: 999999999), // Max 999M VND
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Vui lòng nhập giá vốn';
            }
            // FIXED: Use simple extraction method
            final price = _extractSimpleNumber(value);
            if (price == null || price <= 0) {
              return 'Giá vốn phải là số dương';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _newSellingPriceController,
          decoration: const InputDecoration(
            labelText: 'Giá bán mới (tùy chọn)',
            border: OutlineInputBorder(),
            suffixText: 'VNĐ',
            prefixIcon: Icon(Icons.sell),
            helperText: 'Ví dụ: 25.000 (để trống nếu không đổi)',
          ),
          // FIXED: Use simple formatter for selling price field  
          keyboardType: TextInputType.number,
          inputFormatters: [
            SimpleCurrencyInputFormatter(maxValue: 999999999),
          ],
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              // FIXED: Use simple extraction for now
              final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
              final price = int.tryParse(cleanValue);
              if (price == null || price <= 0) {
                return 'Giá bán phải là số dương';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        _buildProfitIndicator(),
      ],
    );
  }

  Widget _buildProfitIndicator() {
    final costText = _costPriceController.text;
    final sellingText = _newSellingPriceController.text;

    if (costText.isEmpty || sellingText.isEmpty) {
      return const SizedBox.shrink();
    }

    // FIXED: Extract numbers from formatted text using simple method
    final cost = _extractSimpleNumber(costText);
    final selling = _extractSimpleNumber(sellingText);

    if (cost == null || selling == null || cost <= 0) {
      return const SizedBox.shrink();
    }

    final profitPercentage = ((selling - cost) / cost) * 100;
    final profitColor = profitPercentage > 0 ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: profitColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: profitColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            profitPercentage > 0 ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: profitColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Lợi nhuận: ${profitPercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: profitColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitQuickAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Thêm Lô Hàng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _submitQuickAdd() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      
      // FIXED: Extract numbers from formatted text using simple method
      final quantity = _extractSimpleNumber(_quantityController.text.trim())?.toInt() ?? 0;
      final costPrice = _extractSimpleNumber(_costPriceController.text.trim()) ?? 0;
      final newSellingPriceText = _newSellingPriceController.text.trim();
      final newSellingPrice = newSellingPriceText.isNotEmpty
          ? _extractSimpleNumber(newSellingPriceText) ?? 0
          : widget.product.currentSellingPrice; // Use current price if not provided

      final success = await provider.quickAddBatch(
        productId: widget.product.id,
        quantity: quantity,
        costPrice: costPrice,
        newSellingPrice: newSellingPrice,
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onBatchAdded?.call(); // Trigger refresh on ProductDetailScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thêm lô hàng thành công'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Simple helper to extract number from formatted text
  double? _extractSimpleNumber(String formattedText) {
    if (formattedText.isEmpty) return null;
    
    // Remove all non-digits  
    String digitsOnly = formattedText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return null;
    
    return double.tryParse(digitsOnly);
  }
}