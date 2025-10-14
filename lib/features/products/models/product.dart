import 'dart:convert';
import 'fertilizer_attributes.dart';
import 'pesticide_attributes.dart';
import 'seed_attributes.dart';

enum ProductCategory {
  FERTILIZER,
  PESTICIDE,
  SEED,
}

extension ProductCategoryExtension on ProductCategory {
  String get displayName {
    switch (this) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }
}

Map<String, dynamic> _parseAttributes(dynamic attributes) {
  if (attributes == null) {
    return {};
  }
  if (attributes is Map<String, dynamic>) {
    return attributes;
  }
  if (attributes is String) {
    try {
      final decoded = jsonDecode(attributes);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      // Ignore if parsing fails
    }
  }
  // Return empty map for any other invalid type (like List)
  return {};
}

class Product {
  final String id;
  final String? sku;
  final String name;
  final ProductCategory category;
  final String? companyId;
  final Map<String, dynamic> attributes;
  final bool isActive;
  final bool isBanned;
  final String? imageUrl;
  final String? description;
  final String storeId;
  final int minStockLevel;
  final int? availableStock;
  final double? currentPrice;
  final double currentSellingPrice;
  final String unit;
  final String? baseUnit; // Base unit for inventory tracking (kg, ml, unit) - nullable for backward compatibility
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? npkRatio;
  final String? activeIngredient;
  final String? seedStrain;

  Product({
    required this.id,
    this.sku,
    required this.name,
    required this.category,
    this.companyId,
    this.attributes = const {},
    this.isActive = true,
    this.isBanned = false,
    this.imageUrl,
    this.description,
    this.minStockLevel = 0,
    required this.storeId,
    this.availableStock,
    this.currentPrice,
    this.currentSellingPrice = 0,
    this.unit = '',
    this.baseUnit,
    required this.createdAt,
    required this.updatedAt,
    this.npkRatio,
    this.activeIngredient,
    this.seedStrain,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      sku: json['sku'],
      name: json['name'],
      category: ProductCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
      ),
      companyId: json['company_id'],
      attributes: _parseAttributes(json['attributes']),
      isActive: json['is_active'] ?? true,
      isBanned: json['is_banned'] ?? false,
      imageUrl: json['image_url'],
      description: json['description'],
      storeId: json['store_id'],
      minStockLevel: json['min_stock_level'] as int? ?? 0,
      availableStock: (json['available_stock'] as num?)?.toInt(),
      currentPrice: (json['current_price'] as num?)?.toDouble(),
      currentSellingPrice: (json['current_selling_price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      baseUnit: json['base_unit'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      npkRatio: json['npk_ratio'],
      activeIngredient: json['active_ingredient'],
      seedStrain: json['seed_strain'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Remove id for insert, but keep for update
      // 'id': id,
      'sku': sku,
      'name': name,
      'category': category.name,
      'company_id': companyId,
      'is_active': isActive,
      'is_banned': isBanned,
      'image_url': imageUrl,
      'description': description,
      'min_stock_level': minStockLevel,
      'current_selling_price': currentSellingPrice,
      'base_unit': baseUnit,
      'store_id': storeId,
      'attributes': attributes,
    };
  }

  // Category display name
  String get categoryDisplayName => category.displayName;

  // Get effective base unit with fallback for backward compatibility
  String get effectiveBaseUnit => baseUnit ?? 'đơn vị';

  // Getter methods cho attributes theo category
  FertilizerAttributes? get fertilizerAttributes {
    if (category != ProductCategory.FERTILIZER) return null;
    try {
      return FertilizerAttributes.fromJson(attributes);
    } catch (e) {
      return null;
    }
  }

  PesticideAttributes? get pesticideAttributes {
    if (category != ProductCategory.PESTICIDE) return null;
    try {
      return PesticideAttributes.fromJson(attributes);
    } catch (e) {
      return null;
    }
  }

  SeedAttributes? get seedAttributes {
    if (category != ProductCategory.SEED) return null;
    try {
      return SeedAttributes.fromJson(attributes);
    } catch (e) {
      return null;
    }
  }

  /// Helper method to convert base stock to default selling unit
  /// Used for display purposes - shows stock in user-friendly units  
  double getStockInDefaultUnit(List<dynamic> units) {
    if (units.isEmpty) {
      // No units configured, return current stock as-is
      return (availableStock ?? 0).toDouble();
    }

    // Find default selling unit - use try/catch to handle not found case
    dynamic defaultUnit;
    try {
      defaultUnit = units.firstWhere(
        (u) => u.isDefaultSellingUnit == true,
      );
    } catch (e) {
      // No default unit found, use first unit as fallback
      defaultUnit = units.isNotEmpty ? units.first : null;
    }

    if (defaultUnit == null) {
      // No units available, return stock as-is
      return (availableStock ?? 0).toDouble();
    }

    final conversionFactor = defaultUnit.conversionFactor ?? 1.0;
    if (conversionFactor <= 0) return (availableStock ?? 0).toDouble();

    // Convert: base stock ÷ conversion factor = display stock
    // Example: 2500 kg ÷ 50 kg/bag = 50 bags
    return (availableStock ?? 0) / conversionFactor;
  }

  /// Helper method to get default selling unit name
  String getDefaultUnitName(List<dynamic> units) {
    if (units.isEmpty) {
      return effectiveBaseUnit; // Fallback to base unit
    }

    // Find default selling unit - use try/catch to handle not found case
    dynamic defaultUnit;
    try {
      defaultUnit = units.firstWhere(
        (u) => u.isDefaultSellingUnit == true,
      );
    } catch (e) {
      // No default unit found, use first unit as fallback
      defaultUnit = units.isNotEmpty ? units.first : null;
    }

    return defaultUnit?.unitName ?? effectiveBaseUnit;
  }

  Product copyWith({
    String? id,
    String? sku,
    String? name,
    ProductCategory? category,
    String? companyId,
    Map<String, dynamic>? attributes,
    bool? isActive,
    bool? isBanned,
    String? imageUrl,
    String? description,
    String? storeId,
    int? minStockLevel,
    int? availableStock,
    double? currentPrice,
    double? currentSellingPrice,
    String? unit,
    String? baseUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? npkRatio,
    String? activeIngredient,
    String? seedStrain,
  }) {
    return Product(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      attributes: attributes ?? this.attributes,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      storeId: storeId ?? this.storeId,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      availableStock: availableStock ?? this.availableStock,
      currentPrice: currentPrice ?? this.currentPrice,
      currentSellingPrice: currentSellingPrice ?? this.currentSellingPrice,
      unit: unit ?? this.unit,
      baseUnit: baseUnit ?? this.baseUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      npkRatio: npkRatio ?? this.npkRatio,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      seedStrain: seedStrain ?? this.seedStrain,
    );
  }
}