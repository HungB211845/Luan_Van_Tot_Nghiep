import '../models/product.dart';

/// Supported packaging types for pesticide products.
enum PesticidePackagingType {
  bottle,
  pack,
  jar,
}

/// Shared configuration describing defaults for each packaging type.
class DefaultPackagingConfig {
  final String displayName;
  final double defaultVolume;
  final List<String> baseUnits;
  final String defaultBaseUnit;
  final int defaultQuantity;

  const DefaultPackagingConfig({
    required this.displayName,
    required this.defaultVolume,
    required this.baseUnits,
    required this.defaultBaseUnit,
    required this.defaultQuantity,
  });
}

/// Default setup reused by Add Product Step 3 and Bulk Add flows.
const Map<PesticidePackagingType, DefaultPackagingConfig>
    kPesticidePackagingDefaults = {
  PesticidePackagingType.bottle: DefaultPackagingConfig(
    displayName: 'Chai',
    defaultVolume: 500,
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
    defaultQuantity: 20,
  ),
  PesticidePackagingType.pack: DefaultPackagingConfig(
    displayName: 'Gói',
    defaultVolume: 50,
    baseUnits: ['g', 'kg'],
    defaultBaseUnit: 'g',
    defaultQuantity: 20,
  ),
  PesticidePackagingType.jar: DefaultPackagingConfig(
    displayName: 'Lọ',
    defaultVolume: 100,
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
    defaultQuantity: 20,
  ),
};

/// Convert between units supported by bulk/packaging configuration.
double convertPackagingValue(double value, String fromUnit, String toUnit) {
  if (fromUnit == toUnit) return value;
  if (fromUnit == 'ml' && toUnit == 'lít') return value / 1000;
  if (fromUnit == 'lít' && toUnit == 'ml') return value * 1000;
  if (fromUnit == 'g' && toUnit == 'kg') return value / 1000;
  if (fromUnit == 'kg' && toUnit == 'g') return value * 1000;
  return value;
}

/// Simple formatter used for preview labels of packaging defaults.
String formatPackagingNumber(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(1)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

/// Returns default base unit for the provided category.
///
/// Fertilizer and seed products default to `bao`.
/// Pesticide products default to `ml` (matching bottled configuration).
String resolveDefaultBaseUnit(ProductCategory category) {
  switch (category) {
    case ProductCategory.FERTILIZER:
    case ProductCategory.SEED:
      return 'bao';
    case ProductCategory.PESTICIDE:
      return kPesticidePackagingDefaults[PesticidePackagingType.bottle]!
          .defaultBaseUnit;
  }
}
