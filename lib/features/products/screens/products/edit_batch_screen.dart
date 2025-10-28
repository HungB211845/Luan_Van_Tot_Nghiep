import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../shared/utils/formatter.dart';
import '../../../../shared/utils/input_formatters.dart';
import '../../../../shared/utils/responsive.dart';
import '../../models/product.dart';
import '../../models/product_batch.dart';
import '../../models/product_unit.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_unit_provider.dart';
import '../../utils/unit_display_formatter.dart';

enum _UnitMode { base, container }

class EditBatchScreen extends StatefulWidget {
  final ProductBatch batch;
  const EditBatchScreen({Key? key, required this.batch}) : super(key: key);

  @override
  State<EditBatchScreen> createState() => _EditBatchScreenState();
}

class _EditBatchScreenState extends State<EditBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _batchNumberController;
  late TextEditingController _quantityController;
  late TextEditingController _costPriceController;
  late TextEditingController _supplierBatchIdController;
  late TextEditingController _notesController;

  late FocusNode _quantityFocusNode;
  late FocusNode _costFocusNode;

  late DateTime _receivedDate;
  DateTime? _expiryDate;

  double _baseQuantity = 0;
  double _baseCostPrice = 0;

  ProductUnit? _baseUnit;
  ProductUnit? _defaultUnit;
  double _conversionFactor = 1.0;
  bool _unitsLoading = true;
  _UnitMode _mode = _UnitMode.base;

  static const double _epsilon = 0.0001;

  @override
  void initState() {
    super.initState();
    _batchNumberController =
        TextEditingController(text: widget.batch.batchNumber);
    _quantityController = TextEditingController();
    _costPriceController = TextEditingController();
    _supplierBatchIdController =
        TextEditingController(text: widget.batch.supplierBatchId ?? '');
    _notesController = TextEditingController(text: widget.batch.notes ?? '');

    _receivedDate = widget.batch.receivedDate;
    _expiryDate = widget.batch.expiryDate;

    _baseQuantity = widget.batch.quantity.toDouble();
    _baseCostPrice = widget.batch.costPrice;

    _quantityFocusNode = FocusNode();
    _costFocusNode = FocusNode();

    _quantityFocusNode.addListener(_handleQuantityFocusChange);
    _costFocusNode.addListener(_handleCostFocusChange);

    _applyFormatting();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUnits());
  }

  @override
  void dispose() {
    _batchNumberController.dispose();
    _quantityController.dispose();
    _costPriceController.dispose();
    _supplierBatchIdController.dispose();
    _notesController.dispose();
    _quantityFocusNode.removeListener(_handleQuantityFocusChange);
    _quantityFocusNode.dispose();
    _costFocusNode.removeListener(_handleCostFocusChange);
    _costFocusNode.dispose();
    super.dispose();
  }

  void _handleQuantityFocusChange() {
    if (_quantityFocusNode.hasFocus) {
      final editable = _prepareQuantityForEditing();
      _quantityController.value = TextEditingValue(
        text: editable,
        selection: TextSelection.collapsed(offset: editable.length),
      );
    } else {
      _commitQuantity();
    }
  }

  void _handleCostFocusChange() {
    if (_costFocusNode.hasFocus) {
      final editable = _prepareCostForEditing();
      _costPriceController.value = TextEditingValue(
        text: editable,
        selection: TextSelection.collapsed(offset: editable.length),
      );
    } else {
      _commitCost();
    }
  }

  Future<void> _loadUnits() async {
    final unitProvider = context.read<ProductUnitProvider>();
    try {
      final units =
          await unitProvider.getUnitsForProduct(widget.batch.productId);
      if (!mounted) return;

      ProductUnit? resolvedBase = UnitDisplayFormatter.baseUnit(units);
      if (resolvedBase == null && units.isNotEmpty) {
        final positives = List<ProductUnit>.from(
          units.where((unit) => unit.conversionFactor > 0),
        )..sort((a, b) => a.conversionFactor.compareTo(b.conversionFactor));
        resolvedBase = positives.isNotEmpty ? positives.first : units.first;
      }

      ProductUnit? defaultUnit = UnitDisplayFormatter.defaultUnit(units);
      final double baseFactor =
          resolvedBase != null && resolvedBase.conversionFactor > 0
              ? resolvedBase.conversionFactor
              : 1.0;
      final double defaultFactor =
          defaultUnit != null && defaultUnit.conversionFactor > 0
              ? defaultUnit.conversionFactor
              : baseFactor;

      double ratio = defaultUnit != null ? defaultFactor / baseFactor : 1.0;
      if (ratio <= 0) {
        ratio = 1.0;
        defaultUnit = null;
      }

      final bool hasSwitch =
          defaultUnit != null && (ratio - 1.0).abs() > _epsilon;

      setState(() {
        _baseUnit = resolvedBase;
        _defaultUnit = defaultUnit;
        _conversionFactor = ratio;
        _unitsLoading = false;
        _mode = hasSwitch ? _UnitMode.container : _UnitMode.base;
      });

      _applyFormatting();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _baseUnit = null;
        _defaultUnit = null;
        _conversionFactor = 1.0;
        _unitsLoading = false;
        _mode = _UnitMode.base;
      });
      _applyFormatting();
    }
  }

  bool get _hasContainerOption =>
      _defaultUnit != null && (_conversionFactor - 1.0).abs() > _epsilon;

  double get _factor => _hasContainerOption ? _conversionFactor : 1.0;

  String get _baseUnitLabel => _baseUnit != null
      ? UnitDisplayFormatter.simpleUnitName(_baseUnit!)
      : 'đơn vị cơ sở';

  String get _containerUnitLabel => _defaultUnit != null
      ? UnitDisplayFormatter.simpleUnitName(_defaultUnit!)
      : _baseUnitLabel;

  String get _quantityLabel => _mode == _UnitMode.container
      ? 'Số lượng (${_containerUnitLabel})'
      : 'Số lượng (${_baseUnitLabel})';

  String get _costLabel => _mode == _UnitMode.container
      ? 'Giá vốn (${_containerUnitLabel})'
      : 'Giá vốn (${_baseUnitLabel})';

  double get _displayQuantity {
    if (_baseQuantity <= 0) return 0;
    if (_mode == _UnitMode.container && _hasContainerOption) {
      return _baseQuantity / _factor;
    }
    return _baseQuantity;
  }

  double get _displayCost {
    if (_baseCostPrice <= 0) return 0;
    if (_mode == _UnitMode.container && _hasContainerOption) {
      return _baseCostPrice * _factor;
    }
    return _baseCostPrice;
  }

  String? get _conversionHint {
    if (!_hasContainerOption) return null;
    final factorText = _formatFactor(_factor);
    final fromLabel = _containerUnitLabel;
    final toLabel = _baseUnitLabel;
    return '1 $fromLabel = $factorText $toLabel';
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.read<ProductProvider>();
    final Product? selectedProduct = productProvider.selectedProduct;
    final theme = Theme.of(context);

    return ResponsiveScaffold(
      title: 'Chỉnh sửa lô hàng',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.sectionPadding,
            vertical: context.sectionPadding * 1.5,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selectedProduct != null) ...[
                      _buildProductInfo(selectedProduct, theme),
                      const SizedBox(height: 24),
                    ],
                    _buildBatchNumberField(),
                    const SizedBox(height: 24),
                    if (_unitsLoading) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                    ],
                    if (_hasContainerOption) ...[
                      _buildUnitSwitch(theme),
                      const SizedBox(height: 16),
                    ],
                    _buildQuantityCostGroup(context),
                    const SizedBox(height: 24),
                    _buildDatesSection(context),
                    const SizedBox(height: 24),
                    _buildOptionalFields(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(Product product, ThemeData theme) {
    final background = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.6,
    );

    final sku = product.sku?.trim();

    return Card(
      elevation: 0,
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sku != null && sku.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'SKU: $sku',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatchNumberField() {
    return TextFormField(
      controller: _batchNumberController,
      decoration: InputDecoration(
        labelText: 'Mã lô *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Vui lòng nhập mã lô';
        }
        return null;
      },
    );
  }

  Widget _buildUnitSwitch(ThemeData theme) {
    final trackColor = Colors.green.withOpacity(0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đơn vị nhập liệu',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: CupertinoSlidingSegmentedControl<_UnitMode>(
            groupValue: _mode,
            padding: const EdgeInsets.all(4),
            backgroundColor: trackColor,
            thumbColor: Colors.green,
            children: {
              _UnitMode.container: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text(
                  'Đơn vị bán',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        _mode == _UnitMode.container ? Colors.white : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _UnitMode.base: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Text(
                  'Đơn vị cơ sở',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _mode == _UnitMode.base ? Colors.white : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            },
            onValueChanged: _handleModeChange,
          ),
        ),
        if (_conversionHint != null) ...[
          const SizedBox(height: 8),
          Text(
            _conversionHint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityCostGroup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuantityField(),
        const SizedBox(height: 12),
        _buildCostField(),
      ],
    );
  }

  Widget _buildQuantityField() {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.6),
    );
    final unitStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
    );
    final unitLabel =
        _mode == _UnitMode.container ? _containerUnitLabel : _baseUnitLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_quantityLabel, style: labelStyle),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.16),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          focusNode: _quantityFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d\.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.titleMedium,
                          validator: (value) {
                            final baseValue = _parseQuantityToBase(value);
                            if (baseValue == null || baseValue <= 0) {
                              return 'Số lượng phải lớn hơn 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(unitLabel, style: unitStyle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostField() {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.6),
    );
    final unitStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_costLabel, style: labelStyle),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.16),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceController,
                          focusNode: _costFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            CurrencyInputFormatter(),
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: theme.textTheme.titleMedium,
                          validator: (value) {
                            final baseValue = _parseCostToBase(value);
                            if (baseValue == null || baseValue <= 0) {
                              return 'Giá vốn phải lớn hơn 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('đ', style: unitStyle),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _receivedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _receivedDate = picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Ngày nhập *',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(AppFormatter.formatDate(_receivedDate)),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _expiryDate = picked);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Hạn sử dụng (tùy chọn)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _expiryDate == null
                  ? 'Chọn ngày hết hạn'
                  : AppFormatter.formatDate(_expiryDate),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _supplierBatchIdController,
          decoration: InputDecoration(
            labelText: 'Mã lô nhà cung cấp (tùy chọn)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Ghi chú (tùy chọn)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _deleteBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Xóa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateBatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Lưu Thay Đổi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _handleModeChange(_UnitMode? newMode) {
    if (newMode == null || newMode == _mode) return;

    final baseQty = _parseQuantityToBase(_quantityController.text);
    final baseCost = _parseCostToBase(_costPriceController.text);

    setState(() {
      if (baseQty != null) {
        _baseQuantity = baseQty;
      }
      if (baseCost != null) {
        _baseCostPrice = baseCost;
      }
      _mode = newMode;
    });

    _applyFormatting();
  }

  void _applyFormatting() {
    final quantityValue = _displayQuantity;
    if (quantityValue <= 0) {
      _quantityController.text = '';
    } else {
      _quantityController.text = _formatQuantity(quantityValue);
    }

    final costValue = _displayCost;
    if (costValue <= 0) {
      _costPriceController.text = '';
    } else {
      _costPriceController.text = _formatCurrency(costValue);
    }
  }

  void _commitQuantity() {
    final base = _parseQuantityToBase(_quantityController.text);
    if (base == null) return;
    _baseQuantity = base;
    _applyFormatting();
  }

  void _commitCost() {
    final base = _parseCostToBase(_costPriceController.text);
    if (base == null) return;
    _baseCostPrice = base;
    _applyFormatting();
  }

  String _prepareQuantityForEditing() {
    final value = _displayQuantity;
    if (value <= 0) return '';
    if ((value - value.roundToDouble()).abs() < _epsilon) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _prepareCostForEditing() {
    final value = _displayCost;
    if (value <= 0) return '';
    if ((value - value.roundToDouble()).abs() < _epsilon) {
      return value.round().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < _epsilon) {
      return AppFormatter.formatNumber(value.round());
    }
    final parts = value.toStringAsFixed(3).split('.');
    final integerPart = int.tryParse(parts.first) ?? 0;
    final decimals = parts.length > 1
        ? parts[1].replaceAll(RegExp(r'0+$'), '')
        : '';
    final formattedInt = AppFormatter.formatNumber(integerPart);
    if (decimals.isEmpty) {
      return formattedInt;
    }
    return '$formattedInt,$decimals';
  }

  String _formatCurrency(double value) {
    return AppFormatter.formatCurrencyWithSymbol(value, symbol: 'đ');
  }

  String _formatFactor(double value) {
    if ((value - value.roundToDouble()).abs() < _epsilon) {
      return AppFormatter.formatNumber(value.round());
    }
    final text = value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  double? _parseQuantityToBase(String? raw) {
    final value = _parseDecimal(raw);
    if (value == null) return null;
    if (_mode == _UnitMode.container && _hasContainerOption) {
      return value * _factor;
    }
    return value;
  }

  double? _parseCostToBase(String? raw) {
    final value = _parseDecimal(raw);
    if (value == null) return null;
    if (_mode == _UnitMode.container && _hasContainerOption) {
      if (_factor <= 0) return null;
      return value / _factor;
    }
    return value;
  }

  double? _parseDecimal(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final sanitized =
        trimmed.replaceAll(RegExp(r'[đ₫\s]', caseSensitive: false), '');
    if (sanitized.isEmpty) return null;

    if (sanitized.contains(',')) {
      final normalized = sanitized.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    final dotMatches = RegExp(r'\.').allMatches(sanitized).length;
    if (dotMatches == 1) {
      final dotIndex = sanitized.indexOf('.');
      final decimalsCount = sanitized.length - dotIndex - 1;
      if (decimalsCount > 0 && decimalsCount <= 2) {
        final parsed = double.tryParse(sanitized);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    if (dotMatches > 0) {
      final normalized = sanitized.replaceAll('.', '');
      return double.tryParse(normalized);
    }

    return double.tryParse(sanitized);
  }

  Future<void> _updateBatch() async {
    FocusScope.of(context).unfocus();
    _commitQuantity();
    _commitCost();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final quantityInput =
          _parseDecimal(_quantityController.text.trim()) ?? 0;
      final costInput = _parseDecimal(_costPriceController.text.trim()) ?? 0;

      final double baseQuantity =
          (_mode == _UnitMode.container && _hasContainerOption)
              ? quantityInput * _factor
              : quantityInput;
      final double baseCost =
          (_mode == _UnitMode.container && _hasContainerOption)
              ? (costInput / (_factor == 0 ? 1 : _factor))
              : costInput;

      final provider = context.read<ProductProvider>();
      final updatedBatch = widget.batch.copyWith(
        batchNumber: _batchNumberController.text.trim(),
        quantity: baseQuantity.round(),
        costPrice: baseCost,
        receivedDate: _receivedDate,
        expiryDate: _expiryDate,
        supplierBatchId: _supplierBatchIdController.text.trim(),
        notes: _notesController.text.trim(),
      );

      final result = await provider.updateProductBatch(updatedBatch);

      if (!mounted) return;

      if (result != null) {
        _baseQuantity = baseQuantity;
        _baseCostPrice = baseCost;
        Navigator.pop(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa lô hàng "${widget.batch.batchNumber}"?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ProductProvider>();
      final success = await provider.deleteProductBatch(
        widget.batch.id,
        widget.batch.productId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa lô hàng thành công'),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }
}
