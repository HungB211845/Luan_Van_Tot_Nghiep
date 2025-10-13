import '../models/product_unit.dart';

class UnitDisplayFormatter {
  static const _tolerance = 0.0001;
  static const List<String> _preferredKeywords = ['thùng', 'bao', 'chai', 'lọ'];

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

  static ProductUnit? defaultUnit(List<ProductUnit> units) {
    return _findDefaultUnit(units);
  }

  static ProductUnit? baseUnit(List<ProductUnit> units) {
    return _findBaseUnit(units);
  }

  static bool isPreferredKeywordUnit(ProductUnit unit) {
    final lower = unit.unitName.toLowerCase();
    return _preferredKeywords.any((keyword) => lower.contains(keyword));
  }

  static ProductUnit? preferredDisplayUnit(List<ProductUnit> units) {
    if (units.isEmpty) return null;
    final sorted = List<ProductUnit>.from(units)
      ..sort((a, b) => b.conversionFactor.compareTo(a.conversionFactor));

    for (final keyword in _preferredKeywords) {
      final matches = sorted
          .where((unit) => unit.unitName.toLowerCase().contains(keyword))
          .toList();
      if (matches.isNotEmpty) {
        final match = matches.reduce((curr, next) =>
            next.conversionFactor > curr.conversionFactor ? next : curr);
        if (match.conversionFactor > 0) {
          return match;
        }
      }
    }

    final defaultUnit = _findDefaultUnit(units);
    if (defaultUnit != null && defaultUnit.conversionFactor > 0) {
      return defaultUnit;
    }

    final largest = sorted.firstWhere(
      (unit) => unit.conversionFactor > 0,
      orElse: () => sorted.first,
    );
    return largest;
  }

  static PreferredQuantityDisplay? preferredQuantity({
    required double baseQuantity,
    required List<ProductUnit> units,
    required String baseUnitName,
  }) {
    if (units.isEmpty) return null;
    final displayUnit = preferredDisplayUnit(units) ?? _findDefaultUnit(units) ?? units.first;
    if (displayUnit.conversionFactor <= 0) return null;

    final primary = baseQuantity / displayUnit.conversionFactor;
    final floored = primary.floor();
    final remainder = (baseQuantity - (floored * displayUnit.conversionFactor)).round();

    return PreferredQuantityDisplay(
      primaryQuantity: primary,
      remainder: remainder,
      unit: displayUnit,
      baseUnitName: baseUnitName,
    );
  }

  static String simpleUnitName(ProductUnit unit) {
    final name = unit.unitName.trim();
    final index = name.indexOf('(');
    if (index > 0) {
      return name.substring(0, index).trim();
    }
    return name;
  }

  static String formatQuantityValue(double value) {
    if (_isApproximately(value, value.roundToDouble())) {
      return value.round().toString();
    }
    return _trimTrailingZeros(value.toStringAsFixed(2));
  }

  static String resolveBaseUnitName({
    required List<ProductUnit> units,
    required String fallback,
  }) {
    final baseUnit = _findBaseUnit(units);
    if (baseUnit != null && baseUnit.unitName.isNotEmpty) {
      return baseUnit.unitName;
    }
    return fallback;
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

class PreferredQuantityDisplay {
  final double primaryQuantity;
  final int remainder;
  final ProductUnit unit;
  final String baseUnitName;

  PreferredQuantityDisplay({
    required this.primaryQuantity,
    required this.remainder,
    required this.unit,
    required this.baseUnitName,
  });
}
