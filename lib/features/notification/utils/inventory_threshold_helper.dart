import '../../products/models/product.dart';
import '../../products/models/product_unit.dart';

class InventoryThresholdHelper {
  static const Map<String, double> defaultThresholds = {
    'FERTILIZER': 50,
    'PESTICIDE': 5,
    'SEED': 20,
  };

  static const double fallbackThreshold = 10;

  static double resolveLowStockThreshold({
    required double minStockLevel,
    required List<ProductUnit> units,
    required Map<String, double> thresholds,
    required ProductCategory? category,
  }) {
    if (minStockLevel > 0) {
      return minStockLevel;
    }

    final String categoryKey = category?.name.toUpperCase() ?? '';
    final double configured =
        thresholds[categoryKey] ?? defaultThresholds[categoryKey] ?? fallbackThreshold;

    final double baseValue = configured <= 0 ? fallbackThreshold : configured;

    if (units.isEmpty) {
      return baseValue;
    }

    final ProductUnit? defaultUnit = _findDefaultUnit(units);
    final ProductUnit? baseUnit = _findBaseUnit(units);
    final double conversionFactor;

    if (defaultUnit != null && defaultUnit.conversionFactor > 0) {
      conversionFactor = defaultUnit.conversionFactor;
    } else if (baseUnit != null && baseUnit.conversionFactor > 0) {
      conversionFactor = baseUnit.conversionFactor;
    } else {
      conversionFactor = 1;
    }

    return baseValue * conversionFactor;
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
      if (unit.conversionFactor == 1) {
        return unit;
      }
    }
    return null;
  }
}
