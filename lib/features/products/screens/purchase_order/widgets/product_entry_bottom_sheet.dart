import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/product.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters except commas (for decimals)
    String newText = newValue.text.replaceAll(RegExp(r'[^\d,]'), '');

    // Handle decimal part (after comma)
    List<String> parts = newText.split(',');
    if (parts.length > 2) {
      newText = '${parts[0]},${parts.sublist(1).join('')}';
    }

    // Limit decimal places to 2
    if (parts.length == 2 && parts[1].length > 2) {
      newText = '${parts[0]},${parts[1].substring(0, 2)}';
    }

    // Add thousand separators (dots) to integer part
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      String integerPart = parts[0];
      String formattedInteger = integerPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );

      if (parts.length == 2) {
        newText = '$formattedInteger,${parts[1]}';
      } else {
        newText = formattedInteger;
      }
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class ProductEntryBottomSheet extends StatefulWidget {
  final Product product;
  final int? existingQuantity;
  final double? existingPrice;
  final String? existingUnit;
  final Function(int quantity, double price, String unit) onAdd;

  const ProductEntryBottomSheet({
    Key? key,
    required this.product,
    this.existingQuantity,
    this.existingPrice,
    this.existingUnit,
    required this.onAdd,
  }) : super(key: key);

  @override
  State<ProductEntryBottomSheet> createState() =>
      _ProductEntryBottomSheetState();
}

class _ProductEntryBottomSheetState extends State<ProductEntryBottomSheet> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  String _selectedUnit = 'kg';

  @override
  void initState() {
    super.initState();

    // Initialize with existing values or defaults
    _quantityController.text = widget.existingQuantity?.toString() ?? '1';
    if (widget.existingPrice != null && widget.existingPrice! > 0) {
      _priceController.text = _formatInputPrice(widget.existingPrice!);
    }
    _selectedUnit = widget.existingUnit ?? _getDefaultUnit();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  String _getDefaultUnit() {
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        return 'kg';
      case ProductCategory.PESTICIDE:
        return 'chai';
      case ProductCategory.SEED:
        return 'kg';
    }
  }

  List<String> _getUnitOptions() {
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        return ['kg', 'tấn', 'bao'];
      case ProductCategory.PESTICIDE:
        return ['ml', 'lít', 'chai', 'gói', 'lọ'];
      case ProductCategory.SEED:
        return ['kg', 'bao'];
    }
  }

  void _handleAdd() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = _parseCurrency(_priceController.text);

    if (quantity > 0 && price >= 0) {
      widget.onAdd(quantity, price, _selectedUnit);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số lượng và giá hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _parseCurrency(String text) {
    // Remove thousand separators (dots) and replace decimal comma with dot
    String cleanText = text.replaceAll(
      RegExp(r'\.(?=\d{3})'),
      '',
    ); // Remove thousand dots
    cleanText = cleanText.replaceAll(
      ',',
      '.',
    ); // Replace decimal comma with dot
    return double.tryParse(cleanText) ?? 0.0;
  }

  String _formatInputPrice(double price) {
    // Format price with Vietnamese standard: dots for thousands, comma for decimals
    String priceStr = price.toString();
    List<String> parts = priceStr.split('.');

    // Format integer part with thousand separators (dots)
    String integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    // Handle decimal part
    if (parts.length == 2 && parts[1] != '0') {
      return '$integerPart,${parts[1]}';
    } else {
      return integerPart;
    }
  }

  Color _getCategoryColor() {
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        return Colors.green;
      case ProductCategory.PESTICIDE:
        return Colors.orange;
      case ProductCategory.SEED:
        return Colors.brown;
    }
  }

  IconData _getCategoryIcon() {
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        return Icons.eco;
      case ProductCategory.PESTICIDE:
        return Icons.bug_report;
      case ProductCategory.SEED:
        return Icons.grass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with product info
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Product icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    color: categoryColor,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (widget.product.sku != null)
                        Text(
                          widget.product.sku!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),

                // Close button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Entry form
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity input
                  const Text(
                    'Số lượng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: false,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      FilteringTextInputFormatter.deny(RegExp(r'^0+')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Nhập số lượng...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: categoryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    onTap: () {
                      _quantityController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _quantityController.text.length,
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Unit selector
                  const Text(
                    'Đơn vị',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: categoryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: _getUnitOptions().map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text(unit, style: const TextStyle(fontSize: 16)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedUnit = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Price input
                  const Text(
                    'Đơn giá nhập',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: false,
                      decimal: true,
                    ),
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      hintText: 'Nhập giá (ví dụ: 25.000 hoặc 25.000,5)',
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: 'VND',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: categoryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    onTap: () {
                      _priceController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _priceController.text.length,
                      );
                    },
                  ),

                  const Spacer(),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: categoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.existingQuantity != null
                            ? 'Cập nhật giỏ nhập'
                            : 'Thêm vào giỏ nhập',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
