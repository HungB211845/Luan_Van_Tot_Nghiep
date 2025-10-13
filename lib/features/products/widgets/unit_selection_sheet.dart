import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/utils/formatter.dart';
import '../models/product_unit.dart';
import '../models/product.dart';
import '../services/product_unit_service.dart';
import '../utils/unit_display_formatter.dart';
import '../providers/product_provider.dart';

/// Bottom sheet for selecting a unit when adding product to cart
/// Follows Apple HIG principles: Clear, Efficient, Non-disruptive
///
/// Design Philosophy:
/// - Shows unit name prominently (large text)
/// - Displays price and stock for each unit
/// - Highlights default unit
/// - Quick tap to select (2-tap flow: product → unit)
class UnitSelectionSheet extends StatefulWidget {
  final Product product;
  final List<ProductUnit> units;
  final double availableStockInBaseUnit;

  const UnitSelectionSheet({
    Key? key,
    required this.product,
    required this.units,
    required this.availableStockInBaseUnit,
  }) : super(key: key);

  @override
  State<UnitSelectionSheet> createState() => _UnitSelectionSheetState();
}

class _UnitSelectionSheetState extends State<UnitSelectionSheet> {
  final _unitService = ProductUnitService();
  late Future<List<ProductUnit>> _unitsFuture;
  List<ProductUnit> _units = [];

  @override
  void initState() {
    super.initState();
    _units = widget.units;
    _unitsFuture = _fetchUnits();
  }

  Future<List<ProductUnit>> _fetchUnits() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final freshUnits = await provider.getProductUnits(
      widget.product.id,
      forceRefresh: true,
    );
    if (mounted) {
      setState(() {
        _units = freshUnits;
      });
    }
    return freshUnits;
  }

  /// 🔥 HELPER: Calculate unit price on-the-fly if database unit_price is 0
  double _getCalculatedUnitPrice(ProductUnit unit, List<ProductUnit> units) {
    // If unit already has price set in database, use it
    if (unit.unitPrice > 0) {
      return unit.unitPrice;
    }

    // Otherwise, calculate from product's currentSellingPrice
    final productPrice = widget.product.currentSellingPrice;
    if (productPrice <= 0) {
      return 0; // No product price set
    }

    // Find default unit to use as price base
    final defaultUnit = units.firstWhere(
      (u) => u.isDefaultSellingUnit,
      orElse: () => units.first,
    );

    if (unit.id == defaultUnit.id) {
      return productPrice;
    }
    return productPrice / defaultUnit.conversionFactor;
  }

  List<ProductUnit> _visibleUnits(List<ProductUnit> units) {
    if (widget.product.category == ProductCategory.PESTICIDE && units.length > 1) {
      final baseUnit = UnitDisplayFormatter.baseUnit(units);
      if (baseUnit != null) {
        final filtered = units.where((u) => u.id != baseUnit.id).toList();
        if (filtered.isNotEmpty) return filtered;
      }
    }
    return units;
  }

  String _formatStockLabel(List<ProductUnit> units) {
    if (units.isEmpty) {
      final base = widget.product.effectiveBaseUnit;
      final baseLabel = base.toLowerCase() == 'đơn vị' ? '' : ' ${base.toLowerCase()}';
      return '${widget.availableStockInBaseUnit.toInt()}$baseLabel';
    }

    final baseUnitName = UnitDisplayFormatter.resolveBaseUnitName(
      units: units,
      fallback: widget.product.effectiveBaseUnit,
    );

    final preferred = UnitDisplayFormatter.preferredQuantity(
      baseQuantity: widget.availableStockInBaseUnit,
      units: units,
      baseUnitName: baseUnitName,
    );

    if (preferred == null) {
      final baseLabel = baseUnitName.isEmpty || baseUnitName.toLowerCase() == 'đơn vị'
          ? ''
          : ' ${baseUnitName.toLowerCase()}';
      return '${widget.availableStockInBaseUnit.toInt()}$baseLabel';
    }

    final value = UnitDisplayFormatter.formatQuantityValue(preferred.primaryQuantity);
    final label = UnitDisplayFormatter.simpleUnitName(preferred.unit);
    return '$value $label';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductUnit>>(
      future: _unitsFuture,
      builder: (context, snapshot) {
        final units = snapshot.data ?? _units;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 8),
                _buildSubtitle(),
                const SizedBox(height: 16),
                _buildUnitList(units),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.straighten,
            size: 48,
            color: Colors.green[600],
          ),
          const SizedBox(height: 8),
          Text(
            'Chọn đơn vị',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            widget.product.name,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Tồn kho: ${_formatStockLabel(_units)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitList(List<ProductUnit> units) {
    final visibleUnits = _visibleUnits(units);

    if (visibleUnits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Không có đơn vị nào được thiết lập',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: visibleUnits.map((unit) => _buildUnitItem(unit, units)).toList(),
    );
  }

  Widget _buildUnitItem(ProductUnit unit, List<ProductUnit> allUnits) {
    // Calculate stock in this unit
    final stockInThisUnit = _unitService.convertFromBaseUnit(
      baseQuantity: widget.availableStockInBaseUnit,
      conversionFactor: unit.conversionFactor,
    );

    final isLowStock = stockInThisUnit < 10;
    final isOutOfStock = stockInThisUnit <= 0;
    final label = UnitDisplayFormatter.label(
      unit: unit,
      units: allUnits,
      baseUnitName: widget.product.effectiveBaseUnit,
    );
    final conversionHint = UnitDisplayFormatter.conversionHint(
      unit: unit,
      units: allUnits,
      baseUnitName: widget.product.effectiveBaseUnit,
    );

    return InkWell(
      onTap: isOutOfStock
          ? null
          : () {
              Navigator.pop(context, unit);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? Colors.grey[100]
                    : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: isOutOfStock ? Colors.grey[400] : Colors.green[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Unit details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? Colors.grey[400] : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unit.isDefaultSellingUnit)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Mặc định',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        AppFormatter.formatCurrency(_getCalculatedUnitPrice(unit, allUnits)), // 🔥 FIXED: Use calculated price
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock ? Colors.grey[400] : Colors.green[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOutOfStock
                            ? 'Hết hàng'
                            : 'Còn: ${stockInThisUnit.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isOutOfStock
                              ? Colors.red[600]
                              : isLowStock
                                  ? Colors.orange[600]
                                  : Colors.grey[600],
                          fontWeight: isLowStock || isOutOfStock
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (conversionHint != null && conversionHint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      conversionHint,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrow indicator
            if (!isOutOfStock)
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
