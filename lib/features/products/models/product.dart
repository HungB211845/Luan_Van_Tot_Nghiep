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
      attributes: json['attributes'] is String
          ? jsonDecode(json['attributes'])
          : json['attributes'] ?? {},
      isActive: json['is_active'] ?? true,
      isBanned: json['is_banned'] ?? false,
      imageUrl: json['image_url'],
      description: json['description'],
      storeId: json['store_id'],
      minStockLevel: json['min_stock_level'] as int? ?? 0,
      availableStock: (json['available_stock'] as num?)?.toInt(),
      currentPrice: (json['current_price'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      npkRatio: json['npk_ratio'],
      activeIngredient: json['active_ingredient'],
      seedStrain: json['seed_strain'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.isEmpty ? null : id,
      'sku': sku?.isEmpty == true ? null : sku,
      'name': name,
      'category': category.toString().split('.').last,
      'company_id': companyId?.isEmpty == true ? null : companyId,
      'attributes': jsonEncode(attributes),
      'is_active': isActive,
      'is_banned': isBanned,
      'image_url': imageUrl,
      'description': description,
      'store_id': storeId.isEmpty ? null : storeId,
      'min_stock_level': minStockLevel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Category display name
  String get categoryDisplayName => category.displayName;

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      npkRatio: npkRatio ?? this.npkRatio,
      activeIngredient: activeIngredient ?? this.activeIngredient,
      seedStrain: seedStrain ?? this.seedStrain,
    );
  }
}