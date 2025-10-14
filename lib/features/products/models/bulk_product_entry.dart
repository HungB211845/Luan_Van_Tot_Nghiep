import './product.dart'; // For ProductCategory

// Enums and configs for Pesticide UOM, used by UI and Provider
enum PesticidePackagingType { bottle, pack, jar }

class DefaultPackagingConfig {
  final String displayName;
  final List<String> baseUnits;
  final String defaultBaseUnit;

  const DefaultPackagingConfig({
    required this.displayName,
    required this.baseUnits,
    required this.defaultBaseUnit,
  });
}

const Map<PesticidePackagingType, DefaultPackagingConfig> packagingDefaults = {
  PesticidePackagingType.bottle: DefaultPackagingConfig(
    displayName: 'Chai',
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
  ),
  PesticidePackagingType.pack: DefaultPackagingConfig(
    displayName: 'Gói',
    baseUnits: ['g', 'kg'],
    defaultBaseUnit: 'g',
  ),
  PesticidePackagingType.jar: DefaultPackagingConfig(
    displayName: 'Lọ',
    baseUnits: ['ml', 'lít'],
    defaultBaseUnit: 'ml',
  ),
};

/// DTO for passing data from bulk add UI to provider
class ProductEntryData {
  final String name;
  final ProductCategory category;

  // Pesticide specific
  final PesticidePackagingType pesticidePackagingType;
  final String pesticideBaseUnit;
  final double? pesticideVolume;
  final int? pesticideQuantityPerBox;

  final double? price;

  ProductEntryData({
    required this.name,
    required this.category,
    this.pesticidePackagingType = PesticidePackagingType.bottle,
    this.pesticideBaseUnit = 'ml',
    this.pesticideVolume,
    this.pesticideQuantityPerBox,
    this.price,
  });
}
