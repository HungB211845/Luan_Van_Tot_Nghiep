class PesticideAttributes {
  final String? activeIngredient;
  final String? concentration; // '4SC', '25EC'
  final double? volume;
  final String? unit; // 'lít', 'chai'
  final List<String> targetPests;

  const PesticideAttributes({
    this.activeIngredient,
    this.concentration,
    this.volume,
    this.unit,
    this.targetPests = const [],
  });

  factory PesticideAttributes.fromJson(Map<String, dynamic> json) {
    return PesticideAttributes(
      activeIngredient: _parseOptionalString(json['active_ingredient']),
      concentration: _parseOptionalString(json['concentration']),
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : null,
      unit: _parseOptionalString(json['unit']),
      targetPests: json['target_pests'] != null
          ? List<String>.from(json['target_pests'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (activeIngredient != null && activeIngredient!.trim().isNotEmpty) {
      data['active_ingredient'] = activeIngredient!.trim();
    }
    if (concentration != null && concentration!.trim().isNotEmpty) {
      data['concentration'] = concentration!.trim();
    }
    if (volume != null) {
      data['volume'] = volume;
    }
    if (unit != null && unit!.trim().isNotEmpty) {
      data['unit'] = unit!.trim();
    }
    if (targetPests.isNotEmpty) {
      data['target_pests'] = targetPests;
    }
    return data;
  }

  static String? _parseOptionalString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }
}
