class BannedSubstance {
  final String id;
  final String storeId; // ADD: Store isolation
  final String activeIngredientName;
  final DateTime bannedDate;
  final String? legalDocument;
  final String? reason;
  final bool isActive;
  final DateTime createdAt;

  BannedSubstance({
    required this.id,
    required this.storeId, // ADD: Required storeId
    required this.activeIngredientName,
    required this.bannedDate,
    this.legalDocument,
    this.reason,
    this.isActive = true,
    required this.createdAt,
  });

  factory BannedSubstance.fromJson(Map<String, dynamic> json) {
    return BannedSubstance(
      id: json['id']?.toString() ?? '',
      storeId: json['store_id']?.toString() ?? '', // ADD: Safe parsing
      activeIngredientName: json['active_ingredient_name']?.toString() ?? '',
      bannedDate: json['banned_date'] != null ? DateTime.parse(json['banned_date']) : DateTime.now(),
      legalDocument: json['legal_document']?.toString(),
      reason: json['reason']?.toString(),
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId, // ADD: Include storeId in JSON
      'active_ingredient_name': activeIngredientName,
      'banned_date': bannedDate.toIso8601String().split('T')[0],
      'legal_document': legalDocument,
      'reason': reason,
      'is_active': isActive,
    };
  }
}