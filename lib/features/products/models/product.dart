import 'dart:convert';
import 'fertilizer_attributes.dart';
import 'pesticide_attributes.dart';
import 'seed_attributes.dart';

enum ProductCategory {
  FERTILIZER,
  PESTICIDE,
  SEED,
}

// === BẮT ĐẦU PHẦN THÊM MỚI ===
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
// === KẾT THÚC PHẦN THÊM MỚI ===

class Product {
  final String id;
  final String sku;
  final String name;
  final ProductCategory category;
  final String? companyId;
  final Map<String, dynamic> attributes;
  final bool isActive;
  final bool isBanned;
  final String? imageUrl;
  final String? description;

  // === THÊM 2 DÒNG NÀY VÀO ===
  final int? availableStock;
  final double? currentPrice;
  // ============================

  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields from database
  final String? npkRatio;
  final String? activeIngredient;
  final String? seedStrain;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    this.companyId,
    required this.attributes,
    this.isActive = true,
    this.isBanned = false,
    this.imageUrl,
    this.description,

    // === THÊM 2 DÒNG NÀY VÀO ===
    this.availableStock,
    this.currentPrice,
    // ============================

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

      // === THÊM 2 DÒNG NÀY VÀO ===
      // Dùng as num? để an toàn, rồi chuyển đổi sang kiểu đúng
      availableStock: (json['available_stock'] as num?)?.toInt(),
      currentPrice: (json['current_price'] as num?)?.toDouble(),
      // ============================

      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      npkRatio: json['npk_ratio'],
      activeIngredient: json['active_ingredient'],
      seedStrain: json['seed_strain'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'name': name,
      'category': category.toString().split('.').last,
      'company_id': companyId,
      'attributes': jsonEncode(attributes),
      'is_active': isActive,
      'is_banned': isBanned,
      'image_url': imageUrl,
      'description': description,
    };
  }

  // Getter methods cho attributes theo category
  FertilizerAttributes? get fertilizerAttributes {
    if (category != ProductCategory.FERTILIZER) return null;
    return FertilizerAttributes.fromJson(attributes);
  }

  PesticideAttributes? get pesticideAttributes {
    if (category != ProductCategory.PESTICIDE) return null;
    return PesticideAttributes.fromJson(attributes);
  }

  SeedAttributes? get seedAttributes {
    if (category != ProductCategory.SEED) return null;
    return SeedAttributes.fromJson(attributes);
  }

  String get categoryDisplayName {
    switch (category) {
      case ProductCategory.FERTILIZER:
        return 'Phân Bón';
      case ProductCategory.PESTICIDE:
        return 'Thuốc BVTV';
      case ProductCategory.SEED:
        return 'Lúa Giống';
    }
  }

  Product copyWith({
    String? sku,
    String? name,
    ProductCategory? category,
    String? companyId,
    Map<String, dynamic>? attributes,
    bool? isActive,
    bool? isBanned,
    String? imageUrl,
    String? description,
  }) {
    return Product(
      id: id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      companyId: companyId ?? this.companyId,
      attributes: attributes ?? this.attributes,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      npkRatio: npkRatio,
      activeIngredient: activeIngredient,
      seedStrain: seedStrain,
    );
  }
}