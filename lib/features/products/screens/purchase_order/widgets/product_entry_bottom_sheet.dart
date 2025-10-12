import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../models/product_unit.dart';
import '../../../utils/unit_display_formatter.dart';
import '../../../providers/product_provider.dart';
import '../../../../../shared/utils/formatter.dart';
import '../../../../../shared/utils/input_formatters.dart';

class ProductEntryBottomSheet extends StatefulWidget {
  final Product product;
  final int? existingQuantity;
  final double? existingPrice;
  final String? existingUnit;
  final Function(int quantity, double price, String unit, String? unitId) onAdd; // 🔥 ADD: unitId parameter

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
  String? _selectedUnitId; // 🔥 NEW: Track selected unit ID
  List<ProductUnit> _productUnits = []; // 🔥 NEW: Product units from database
  bool _isLoadingUnits = true; // 🔥 NEW: Loading state

  @override
  void initState() {
    super.initState();

    // Initialize with existing values or defaults
    _quantityController.text = widget.existingQuantity?.toString() ?? '1';
    if (widget.existingPrice != null && widget.existingPrice! > 0) {
      _priceController.text = AppFormatter.formatNumber(widget.existingPrice!);
    }
    
    // 🔥 NEW: Load product units and set default selection
    _loadProductUnits();
  }

  /// 🔥 NEW: Load product units from database
  Future<void> _loadProductUnits() async {
    try {
      final productProvider = context.read<ProductProvider>();
      final units = await productProvider.getProductUnits(widget.product.id);
      if (mounted) {
        setState(() {
          _productUnits = units;
          _isLoadingUnits = false;
          
          // Set initial unit selection
          if (units.isNotEmpty) {
            // Try to match existing unit first
            if (widget.existingUnit != null) {
              final existingUnit = units.firstWhere(
                (u) => u.unitName.toLowerCase() == widget.existingUnit!.toLowerCase(),
                orElse: () => units.firstWhere((u) => u.isDefaultSellingUnit, orElse: () => units.first),
              );
              _selectedUnit = existingUnit.unitName;
              _selectedUnitId = existingUnit.id;
            } else {
              // No existing unit, use default selling unit
              final defaultUnit = units.firstWhere(
                (u) => u.isDefaultSellingUnit,
                orElse: () => units.first,
              );
              _selectedUnit = defaultUnit.unitName;
              _selectedUnitId = defaultUnit.id;
            }
          } else {
            // No units configured, fallback to category-based default
            _selectedUnit = _getDefaultUnit();
            _selectedUnitId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _productUnits = [];
          _isLoadingUnits = false;
          _selectedUnit = widget.existingUnit ?? _getDefaultUnit();
          _selectedUnitId = null;
        });
      }
      print('Failed to load product units: $e');
    }
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
    // 🔥 NEW: Use actual product units if available
    if (_productUnits.isNotEmpty) {
      return _productUnits.map((unit) => unit.unitName).toList();
    }
    
    // Fallback to category-based units
    switch (widget.product.category) {
      case ProductCategory.FERTILIZER:
        return ['kg', 'tấn', 'bao'];
      case ProductCategory.PESTICIDE:
        return ['ml', 'lít', 'chai', 'gói', 'lọ'];
      case ProductCategory.SEED:
        return ['kg', 'bao'];
    }
  }

  String? _getConversionHint() {
    if (_productUnits.isEmpty || _selectedUnitId == null) {
      return null;
    }

    final selectedUnit = _productUnits.firstWhere(
      (u) => u.id == _selectedUnitId,
      orElse: () => _productUnits.first,
    );

    return UnitDisplayFormatter.conversionHint(
      unit: selectedUnit,
      units: _productUnits,
      baseUnitName: widget.product.effectiveBaseUnit,
    );
  }

  Widget _buildUnitLabelRow() {
    final conversionHint = _getConversionHint();
    return Row(
      children: [
        const Text(
          'Đơn vị',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (conversionHint != null && conversionHint.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            conversionHint,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  void _handleAdd() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text.replaceAll('.', '')) ?? 0.0;

    if (quantity > 0 && price >= 0) {
      // 🔥 NEW: Pass unitId for conversion tracking
      widget.onAdd(quantity, price, _selectedUnit, _selectedUnitId);
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
                  _buildUnitLabelRow(),
                  const SizedBox(height: 8),
                  if (_isLoadingUnits)
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Đang tải đơn vị...'),
                          ],
                        ),
                      ),
                    )
                  else
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
                        String displayText = unit;
                        if (_productUnits.isNotEmpty) {
                          final unitObj = _productUnits.firstWhere(
                            (u) => u.unitName == unit,
                            orElse: () => _productUnits.first,
                          );
                          displayText = UnitDisplayFormatter.label(
                            unit: unitObj,
                            units: _productUnits,
                            baseUnitName: widget.product.effectiveBaseUnit,
                          );
                        }

                        return DropdownMenuItem(
                          value: unit,
                          child: Text(displayText, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedUnit = value;
                            // Update selected unit ID
                            if (_productUnits.isNotEmpty) {
                              final unitObj = _productUnits.firstWhere(
                                (u) => u.unitName == value,
                                orElse: () => _productUnits.first,
                              );
                              _selectedUnitId = unitObj.id;
                            }
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
