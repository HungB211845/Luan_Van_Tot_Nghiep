class BannedSubstance {
  final String id;
  final String activeIngredientName;
  final DateTime bannedDate;
  final String? legalDocument;
  final String? reason;
  final bool isActive;
  final DateTime createdAt;

  BannedSubstance({
    required this.id,
    required this.activeIngredientName,
    required this.bannedDate,
    this.legalDocument,
    this.reason,
    this.isActive = true,
    required this.createdAt,
  });

  factory BannedSubstance.fromJson(Map<String, dynamic> json) {
    return BannedSubstance(
      id: json['id'],
      activeIngredientName: json['active_ingredient_name'],
      bannedDate: DateTime.parse(json['banned_date']),
      legalDocument: json['legal_document'],
      reason: json['reason'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_ingredient_name': activeIngredientName,
      'banned_date': bannedDate.toIso8601String().split('T')[0],
      'legal_document': legalDocument,
      'reason': reason,
      'is_active': isActive,
    };
  }
}