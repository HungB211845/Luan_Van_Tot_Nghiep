import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/product_unit.dart';
import '../../providers/product_provider.dart';
import '../../providers/purchase_order_provider.dart';
import '../../utils/unit_display_formatter.dart';
import '../purchase_order/po_detail_screen.dart';
import 'edit_batch_screen.dart';
import '../../../../shared/utils/formatter.dart';

class BatchDetailScreen extends StatefulWidget {
  final ProductBatch batch;
  final Product? product;
  final List<ProductUnit>? units;
  final String? baseUnitName;

  const BatchDetailScreen({
    Key? key,
    required this.batch,
    this.product,
    this.units,
    this.baseUnitName,
  }) : super(key: key);

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  ProductBatch? _batchOverride;
  Product? _product;
  List<ProductUnit> _units = [];
  String _baseUnitName = '';
  bool _isLoadingUnits = false;
  bool _isNavigatingToPO = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _units = widget.units != null ? List<ProductUnit>.from(widget.units!) : [];
    _baseUnitName = _resolveBaseUnitName(_units);

    if (_units.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUnits();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batchOverride ?? widget.batch;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          batch.batchNumber,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 24),
            onPressed: () async {
              final updated = await Navigator.of(context).push<ProductBatch>(
                MaterialPageRoute(
                  builder: (context) => EditBatchScreen(batch: batch),
                ),
              );

              if (!mounted || updated == null) return;

              setState(() {
                _batchOverride = updated;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cập nhật lô hàng thành công'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            tooltip: 'Chỉnh sửa lô hàng',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoSection(context, batch),
            const SizedBox(height: 16),
            _buildOriginSection(context, batch),
            const SizedBox(height: 16),
            _buildStatusSection(context, batch),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUnits() async {
    if (!mounted || _isLoadingUnits) return;

    setState(() {
      _isLoadingUnits = true;
    });

    final provider = context.read<ProductProvider>();
    try {
      final fetchedUnits = await provider.getProductUnits(
        (_batchOverride ?? widget.batch).productId,
      );
      final resolvedProduct = _product ?? _findProductById(provider);
      if (!mounted) return;
      setState(() {
        _units = fetchedUnits;
        _product = resolvedProduct;
        _baseUnitName = _resolveBaseUnitName(fetchedUnits);
        _isLoadingUnits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _units = [];
        _baseUnitName = _resolveBaseUnitName(const <ProductUnit>[]);
        _isLoadingUnits = false;
      });
    }
  }

  Product? _findProductById(ProductProvider provider) {
    final selected = provider.selectedProduct;
    final currentBatch = _batchOverride ?? widget.batch;
    if (selected?.id == currentBatch.productId) {
      return selected;
    }

    try {
      for (final product in provider.products) {
        if (product.id == currentBatch.productId) {
          return product;
        }
      }
    } catch (_) {
      // Ignore lookup errors; will fallback to default base unit.
    }
    return null;
  }

  String _resolveBaseUnitName(List<ProductUnit> units) {
    final fallback = _fallbackBaseUnit();
    if (units.isEmpty) {
      return fallback;
    }
    return UnitDisplayFormatter.resolveBaseUnitName(
      units: units,
      fallback: fallback,
    );
  }

  String _fallbackBaseUnit() {
    if (widget.baseUnitName != null && widget.baseUnitName!.trim().isNotEmpty) {
      return widget.baseUnitName!;
    }
    if (_product != null) {
      return _product!.effectiveBaseUnit;
    }
    return 'đơn vị';
  }

  _QuantityDisplay _formatQuantityDisplay(int baseQuantity) {
    if (_isLoadingUnits && _units.isEmpty) {
      final baseValue = AppFormatter.formatNumber(baseQuantity);
      return _QuantityDisplay(
        primary: baseValue,
        secondary: _normalizeUnitLabel(_fallbackBaseUnit()),
      );
    }

    final fallbackBase = _baseUnitName.isNotEmpty ? _baseUnitName : _fallbackBaseUnit();
    if (_units.isEmpty) {
      final baseValue = AppFormatter.formatNumber(baseQuantity);
      return _QuantityDisplay(
        primary: baseValue,
        secondary: _normalizeUnitLabel(fallbackBase),
      );
    }

    final preferred = UnitDisplayFormatter.preferredQuantity(
      baseQuantity: baseQuantity.toDouble(),
      units: _units,
      baseUnitName: fallbackBase,
    );

    if (preferred == null) {
      final baseValue = AppFormatter.formatNumber(baseQuantity);
      return _QuantityDisplay(
        primary: baseValue,
        secondary: _normalizeUnitLabel(fallbackBase),
      );
    }

    final baseUnit = UnitDisplayFormatter.baseUnit(_units);
    final isBaseUnit = baseUnit != null && baseUnit.id == preferred.unit.id;
    final primaryValue = _formatNumeric(preferred.primaryQuantity);
    final primaryLabel = UnitDisplayFormatter.simpleUnitName(preferred.unit);

    if (isBaseUnit) {
      return _QuantityDisplay(
        primary: '$primaryValue ${_normalizeUnitLabel(primaryLabel)}',
      );
    }

    final baseValue = AppFormatter.formatNumber(baseQuantity);
    final baseLabel = _normalizeUnitLabel(fallbackBase);
    final secondary = baseLabel.isEmpty ? baseValue : '≈ $baseValue $baseLabel';

    return _QuantityDisplay(
      primary: '$primaryValue ${_normalizeUnitLabel(primaryLabel)}',
      secondary: secondary,
    );
  }

  String? _formatNotes(ProductBatch batch) {
    final raw = batch.notes;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withConversion = RegExp(
      r'Quick Add:\s*([\d\.]+)\s+units\s*->\s*([\d\.]+)\s+base units',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (withConversion != null) {
      final inputQty = _parseNumber(withConversion.group(1));
      final baseQty = _parseNumber(withConversion.group(2));
      if (inputQty != null && baseQty != null && inputQty > 0) {
        final ratio = baseQty / inputQty;
        final matchedUnit = _matchUnitByRatio(ratio);
        final fromLabel = matchedUnit != null
            ? UnitDisplayFormatter.simpleUnitName(matchedUnit)
            : _normalizeUnitLabel(_fallbackBaseUnit());
        final baseUnitLabel = _normalizeUnitLabel(
          _baseUnitName.isNotEmpty ? _baseUnitName : _fallbackBaseUnit(),
        );
        final fromText = _formatNumeric(inputQty);
        final baseText = _formatNumeric(baseQty);
        final totalCost = batch.costPrice > 0 ? batch.costPrice * inputQty : null;
        final buffer = StringBuffer('$fromText $fromLabel → $baseText $baseUnitLabel');
        if (totalCost != null) {
          buffer.write(' • Tổng giá vốn: ${AppFormatter.formatCurrency(totalCost)}');
          buffer.write(' (${AppFormatter.formatCompactCurrency(batch.costPrice)} mỗi $fromLabel)');
        }
        return buffer.toString();
      }
    }

    final withoutConversion = RegExp(
      r'Quick Add:\s*([\d\.]+)\s+units\s*\(no conversion\)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (withoutConversion != null) {
      final inputQty = _parseNumber(withoutConversion.group(1));
      if (inputQty != null) {
        final baseLabel = _normalizeUnitLabel(
          _baseUnitName.isNotEmpty ? _baseUnitName : _fallbackBaseUnit(),
        );
        final fromLabel = _units.isNotEmpty
            ? UnitDisplayFormatter.simpleUnitName(
                UnitDisplayFormatter.baseUnit(_units) ?? _units.first,
              )
            : baseLabel;
        final fromText = _formatNumeric(inputQty);
        final totalCost = batch.costPrice > 0 ? batch.costPrice * inputQty : null;
        if (totalCost != null) {
          return '$fromText $fromLabel • Tổng giá vốn: ${AppFormatter.formatCurrency(totalCost)} (${AppFormatter.formatCompactCurrency(batch.costPrice)} mỗi $fromLabel)';
        }
        return '$fromText $fromLabel';
      }
    }

    var localized = trimmed;
    final baseLabel = _normalizeUnitLabel(
      _baseUnitName.isNotEmpty ? _baseUnitName : _fallbackBaseUnit(),
    );
    localized = localized.replaceAll(
      RegExp(r'\bbase units\b', caseSensitive: false),
      baseLabel,
    );
    localized = localized.replaceAll(
      RegExp(r'\bunits\b', caseSensitive: false),
      baseLabel,
    );
    localized = localized.replaceFirst(
      RegExp(r'^quick add:\s*', caseSensitive: false),
      '',
    );
    return localized.trim();
  }

  ProductUnit? _matchUnitByRatio(double ratio) {
    ProductUnit? bestMatch;
    double smallestDiff = double.infinity;

    for (final unit in _units) {
      final diff = (unit.conversionFactor - ratio).abs();
      if (diff < smallestDiff) {
        smallestDiff = diff;
        bestMatch = unit;
      }
    }

    if (bestMatch != null && smallestDiff <= 0.001) {
      return bestMatch;
    }
    return null;
  }

  double? _parseNumber(String? raw) {
    if (raw == null) return null;
    final normalized = raw.replaceAll(RegExp(r'[^0-9\.]'), '');
    return double.tryParse(normalized);
  }

  String _formatNumeric(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0001) {
      return AppFormatter.formatNumber(rounded.toInt());
    }
    final text = value.toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  String _normalizeUnitLabel(String unit) {
    return unit.trim().isEmpty ? 'đơn vị' : unit.trim();
  }

  Widget _buildInfoSection(BuildContext context, ProductBatch batch) {
    final quantityDisplay = _formatQuantityDisplay(batch.quantity);
    final formattedNotes = _formatNotes(batch);
    final costDisplay = _formatCostDisplay(batch);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông Tin Lô Hàng',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.inventory_2,
              label: 'Số lượng còn lại',
              value: quantityDisplay.primary,
              unit: quantityDisplay.secondary,
              color: _getStockColor(batch.quantity.toDouble()),
              emphasizePrimary: true,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.attach_money,
              label: 'Giá vốn',
              value: costDisplay,
              color: Colors.orange[600]!,
              isMultiLine: true,
              emphasizePrimary: true,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Ngày nhập',
              value: _formatDate(batch.receivedDate),
              color: Colors.blue[600]!,
              valueHighlight: Colors.blue[600]!,
            ),
            if (batch.expiryDate != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.schedule,
                label: 'Hạn sử dụng',
                value: _formatDate(batch.expiryDate!),
                color: _getExpiryColor(batch.expiryDate!),
                valueHighlight: _getExpiryColor(batch.expiryDate!),
              ),
            ],
            if (batch.supplierBatchId != null && batch.supplierBatchId!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.qr_code,
                label: 'Mã lô nhà cung cấp',
                value: batch.supplierBatchId!,
                color: Colors.purple[600]!,
              ),
            ],
            if (formattedNotes != null && formattedNotes.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.note,
                label: 'Ghi chú',
                value: formattedNotes,
                color: Colors.grey[600]!,
                isMultiLine: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCostDisplay(ProductBatch batch) {
    final buffer = StringBuffer();
    final baseCost =
        AppFormatter.formatCurrencyWithSymbol(batch.costPrice, symbol: 'đ');

    final baseUnit = _units.isNotEmpty
        ? UnitDisplayFormatter.baseUnit(_units)
        : null;
    final baseLabel = baseUnit != null
        ? _normalizeUnitLabel(UnitDisplayFormatter.simpleUnitName(baseUnit))
        : _normalizeUnitLabel(
            _baseUnitName.isNotEmpty ? _baseUnitName : _fallbackBaseUnit(),
          );
    final baseSuffix =
        baseLabel.isNotEmpty ? '/${baseLabel.toLowerCase()}' : '';
    buffer.write('$baseCost$baseSuffix');

    final defaultUnit =
        _units.isNotEmpty ? UnitDisplayFormatter.defaultUnit(_units) : null;
    if (defaultUnit != null && defaultUnit.conversionFactor > 0) {
      final perContainer = batch.costPrice * defaultUnit.conversionFactor;
      final containerCost = AppFormatter.formatCurrencyWithSymbol(
        perContainer,
        symbol: 'đ',
      );
      final containerLabel = _normalizeUnitLabel(
        UnitDisplayFormatter.simpleUnitName(defaultUnit),
      );
      final containerSuffix =
          containerLabel.isNotEmpty ? '/${containerLabel.toLowerCase()}' : '';
      buffer.write(' • $containerCost$containerSuffix');
    }

    return buffer.toString();
  }

  Widget _buildOriginSection(BuildContext context, ProductBatch batch) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nguồn Gốc',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            if (batch.supplierName != null && batch.supplierName!.isNotEmpty)
              _buildInfoRow(
                icon: Icons.business,
                label: 'Nhà cung cấp',
                value: batch.supplierName!,
                color: Colors.indigo[600]!,
              ),
            if (batch.supplierName != null && batch.purchaseOrderId != null)
              const Divider(height: 24),
            if (batch.purchaseOrderId != null)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isNavigatingToPO
                      ? null
                      : () => _openPurchaseOrder(
                            context,
                            batch.purchaseOrderId!,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isNavigatingToPO
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long, size: 20),
                  label: const Text(
                    'Xem đơn nhập hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPurchaseOrder(BuildContext context, String poId) async {
    if (_isNavigatingToPO) return;

    if (mounted) {
      setState(() => _isNavigatingToPO = true);
    }

    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final poProvider = context.read<PurchaseOrderProvider>();
    try {
      await poProvider.loadPODetails(poId);
    } finally {
      if (dialogContext != null) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        setState(() => _isNavigatingToPO = false);
      }
    }

    if (!mounted) return;

    final po = poProvider.selectedPO;
    if (po != null && po.id == poId) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(purchaseOrder: po),
        ),
      );
    } else {
      final message = poProvider.errorMessage.isNotEmpty
          ? poProvider.errorMessage
          : 'Không thể mở đơn nhập hàng.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildStatusSection(BuildContext context, ProductBatch batch) {
    final isExpired = batch.isExpired;
    final isExpiringSoon = batch.isExpiringSoon;
    final isLowStock = batch.quantity <= 10;
    final isOutOfStock = batch.quantity <= 0;

    List<Widget> statusItems = [];

    if (isOutOfStock) {
      statusItems.add(_buildStatusItem(
        icon: Icons.error,
        label: 'Hết hàng',
        color: Colors.red[600]!,
        isWarning: true,
      ));
    } else if (isLowStock) {
      statusItems.add(_buildStatusItem(
        icon: Icons.warning,
        label: 'Sắp hết hàng',
        color: Colors.orange[600]!,
        isWarning: true,
      ));
    } else {
      statusItems.add(_buildStatusItem(
        icon: Icons.check_circle,
        label: 'Còn hàng',
        color: Colors.green[600]!,
      ));
    }

    if (isExpired) {
      statusItems.add(_buildStatusItem(
        icon: Icons.event_busy,
        label: 'Đã hết hạn',
        color: Colors.red[600]!,
        isWarning: true,
      ));
    } else if (isExpiringSoon) {
      statusItems.add(_buildStatusItem(
        icon: Icons.schedule,
        label: 'Sắp hết hạn',
        color: Colors.orange[600]!,
        isWarning: true,
      ));
    } else if (batch.expiryDate != null) {
      final daysLeft = batch.daysUntilExpiry;
      statusItems.add(_buildStatusItem(
        icon: Icons.event_available,
        label: 'Còn $daysLeft ngày',
        color: Colors.green[600]!,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trạng Thái',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 16),
            ...statusItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: item,
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    required Color color,
    bool isMultiLine = false,
    Color? valueHighlight,
    bool emphasizePrimary = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey[700], size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (valueHighlight != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: valueHighlight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: isMultiLine ? null : 1,
                    overflow: isMultiLine ? null : TextOverflow.ellipsis,
                  ),
                )
              else if (emphasizePrimary)
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: isMultiLine ? null : 1,
                  overflow: isMultiLine ? null : TextOverflow.ellipsis,
                )
              else
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: isMultiLine ? null : 1,
                  overflow: isMultiLine ? null : TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required Color color,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isWarning ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Color _getStockColor(double stock) {
    if (stock <= 0) {
      return Colors.red[600]!;
    } else if (stock <= 10) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }

  Color _getExpiryColor(DateTime expiryDate) {
    final now = DateTime.now();
    if (now.isAfter(expiryDate)) {
      return Colors.red[600]!;
    } else if (expiryDate.difference(now).inDays <= 30) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }
}

class _QuantityDisplay {
  final String primary;
  final String? secondary;

  const _QuantityDisplay({
    required this.primary,
    this.secondary,
  });
}
