import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/product_unit.dart'; // Re-add this import since we need ProductUnit type
import '../providers/product_provider.dart';
import '../utils/unit_display_formatter.dart';
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
  bool _isLoadingUnits = true;

  final _quantityController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _newSellingPriceController = TextEditingController();

  // 🔥 FIX: Proper type declaration for ProductUnit list
  List<ProductUnit> _productUnits = [];
  String? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    // FIXED: Initialize with formatted price
    _newSellingPriceController.text = AppFormatter.formatNumber(widget.product.currentSellingPrice);
    _loadProductUnits();
  }

  Future<void> _loadProductUnits() async {
    try {
      final productProvider = context.read<ProductProvider>();
      final units = await productProvider.getProductUnits(widget.product.id);
      if (mounted) {
        setState(() {
          _productUnits = units; 
          // 🔥 FIXED: More robust unit selection logic
          if (units.isNotEmpty) {
            // Try to find default selling unit first
            final defaultUnit = units.firstWhere(
              (ProductUnit u) => u.isDefaultSellingUnit,
              orElse: () => units.first, // 🔥 FIXED: Always provide fallback
            );
            _selectedUnitId = defaultUnit.id;
            
            print('DEBUG: Loaded ${units.length} units for ${widget.product.name}');
            print('DEBUG: Selected default unit: ${defaultUnit.unitName} (isDefault: ${defaultUnit.isDefaultSellingUnit})');
            for (final unit in units) {
              print('DEBUG: Unit: ${unit.unitName}, isDefault: ${unit.isDefaultSellingUnit}, factor: ${unit.conversionFactor}');
            }
          } else {
            _selectedUnitId = null;
            print('DEBUG: No units found for ${widget.product.name}');
          }
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _productUnits = [];
          _selectedUnitId = null;
          _isLoadingUnits = false;
        });
      }
      print('Failed to load product units: $e');
    }
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
        // Unit Selection (if multiple units available)
        if (_productUnits.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            value: _selectedUnitId,
            decoration: InputDecoration(
              labelText: 'Đơn vị *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.straighten),
              helperText: 'Chọn đơn vị để hệ thống tự chuyển đổi',
            ),
            items: _productUnits.map<DropdownMenuItem<String>>((ProductUnit unit) {
              final label = UnitDisplayFormatter.label(
                unit: unit,
                units: _productUnits,
                baseUnitName: widget.product.effectiveBaseUnit,
              );
              return DropdownMenuItem(
                value: unit.id,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedUnitId = value;
              });
            },
            validator: (value) {
              if (_productUnits.isNotEmpty && (value == null || value.isEmpty)) {
                return 'Vui lòng chọn đơn vị';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
        
        TextFormField(
          controller: _quantityController,
          decoration: InputDecoration(
            labelText: 'Số lượng *',
            border: const OutlineInputBorder(),
            suffixText: _getSelectedUnitName(),
            prefixIcon: const Icon(Icons.inventory_2),
            helperText: _getQuantityHelperText(),
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
                    keyboardType: TextInputType.number,
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

  String _getSelectedUnitName() {
    if (_productUnits.isEmpty || _selectedUnitId == null) {
      return widget.product.unit.isNotEmpty ? widget.product.unit : 'đơn vị';
    }
    
    // 🔥 FIXED: Use orElse to prevent exceptions
    final selectedUnit = _productUnits.firstWhere(
      (ProductUnit u) => u.id == _selectedUnitId,
      orElse: () => _productUnits.first, // 🔥 CRITICAL: Always provide fallback
    );
    return selectedUnit.unitName;
  }

  String _getQuantityHelperText() {
    if (_productUnits.isEmpty || _selectedUnitId == null) {
      return 'Ví dụ: 1.000';
    }
    
    // Use direct reference instead of creating unused variable
    return 'Hệ thống sẽ tự chuyển đổi sang ${widget.product.effectiveBaseUnit}';
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

      // 🔥 CRITICAL FIX: Pass unitId for conversion
      final success = await provider.quickAddBatchWithUnit(
        productId: widget.product.id,
        quantity: quantity,
        costPrice: costPrice,
        newSellingPrice: newSellingPrice,
        unitId: _selectedUnitId, // Pass selected unit for conversion
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onBatchAdded?.call(); // Trigger refresh on ProductDetailScreen
          
          // Show success message with conversion info
          final unitName = _getSelectedUnitName();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_productUnits.isNotEmpty && _selectedUnitId != null
                  ? 'Thêm lô hàng thành công với chuyển đổi đơn vị ($quantity $unitName)'
                  : 'Thêm lô hàng thành công'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
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
