import '../models/product_unit.dart';

class UnitDisplayFormatter {
  static const _tolerance = 0.0001;

  static String label({
    required ProductUnit unit,
    required List<ProductUnit> units,
    required String baseUnitName,
  }) {
    final baseUnit = _findBaseUnit(units);
    final defaultUnit = _findDefaultUnit(units) ?? baseUnit;
    final lowerName = unit.unitName.toLowerCase();
    final lowerBase = baseUnitName.toLowerCase();

    if (_isBaseUnit(unit, baseUnit)) {
      return unit.unitName;
    }

    if (unit.isDefaultSellingUnit) {
      return unit.unitName;
    }

    if (lowerBase.isNotEmpty && lowerName.contains(lowerBase)) {
      return unit.unitName;
    }

    if (defaultUnit != null && defaultUnit.id != unit.id) {
      final ratio = unit.conversionFactor / defaultUnit.conversionFactor;
      if (ratio > 1.0) {
        final ratioText = _formatMultiplier(ratio);
        return '${unit.unitName} (×$ratioText ${defaultUnit.unitName})';
      }
    }

    if (baseUnit != null && !_isBaseUnit(unit, baseUnit)) {
      final ratio = unit.conversionFactor / baseUnit.conversionFactor;
      final ratioText = _formatMultiplier(ratio);
      final baseLabel = baseUnit.unitName.isNotEmpty ? baseUnit.unitName : baseUnitName;

      if (ratioText == '1') {
        return unit.unitName;
      }

      return '${unit.unitName} (×$ratioText $baseLabel)';
    }

    if (baseUnitName.isNotEmpty) {
      final ratioText = _formatMultiplier(unit.conversionFactor);
      if (ratioText == '1') {
        return unit.unitName;
      }
      return '${unit.unitName} (×$ratioText $baseUnitName)';
    }

    return unit.unitName;
  }

  static String? conversionHint({
    required ProductUnit unit,
    required List<ProductUnit> units,
    required String baseUnitName,
  }) {
    final baseUnit = _findBaseUnit(units);
    final defaultUnit = _findDefaultUnit(units) ?? baseUnit;

    if (unit.isDefaultSellingUnit || _isBaseUnit(unit, baseUnit)) {
      return null;
    }

    if (defaultUnit != null && defaultUnit.id != unit.id) {
      final ratio = unit.conversionFactor / defaultUnit.conversionFactor;
      if (ratio > 1.0) {
        final ratioText = _formatMultiplier(ratio);
        return '1 ${unit.unitName} = $ratioText ${defaultUnit.unitName}';
      }
    }

    if (baseUnit != null) {
      final ratio = unit.conversionFactor / baseUnit.conversionFactor;
      final ratioText = _formatMultiplier(ratio);
      if (ratioText == '1') {
        return null;
      }
      final baseLabel = baseUnit.unitName.isNotEmpty ? baseUnit.unitName : baseUnitName;
      return '1 ${unit.unitName} = $ratioText $baseLabel';
    }

    if (baseUnitName.isNotEmpty) {
      final ratioText = _formatMultiplier(unit.conversionFactor);
      if (ratioText == '1') {
        return null;
      }
      return '1 ${unit.unitName} = $ratioText $baseUnitName';
    }

    return null;
  }

  static ProductUnit? _findDefaultUnit(List<ProductUnit> units) {
    for (final unit in units) {
      if (unit.isDefaultSellingUnit) {
        return unit;
      }
    }
    return null;
  }

  static ProductUnit? _findBaseUnit(List<ProductUnit> units) {
    for (final unit in units) {
      if (_isApproximately(unit.conversionFactor, 1.0)) {
        return unit;
      }
    }
    return null;
  }

  static bool _isBaseUnit(ProductUnit unit, ProductUnit? baseUnit) {
    if (baseUnit == null) {
      return _isApproximately(unit.conversionFactor, 1.0);
    }
    return _isApproximately(unit.conversionFactor, baseUnit.conversionFactor);
  }

  static bool _isApproximately(double value, double target) {
    return (value - target).abs() < _tolerance;
  }

  static String _formatMultiplier(double value) {
    if (_isApproximately(value, value.roundToDouble())) {
      return value.round().toString();
    }

    final oneDecimal = double.parse(value.toStringAsFixed(1));
    if (_isApproximately(value, oneDecimal)) {
      return _trimTrailingZeros(oneDecimal.toStringAsFixed(1));
    }

    final twoDecimals = value.toStringAsFixed(2);
    return _trimTrailingZeros(twoDecimals);
  }

  static String _trimTrailingZeros(String value) {
    return value.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}
