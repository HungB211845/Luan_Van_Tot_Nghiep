class PesticideAttributes {
  final String activeIngredient;
  final String concentration; // '4SC', '25EC'
  final double volume;
  final String unit; // 'lít', 'chai'
  final List<String> targetPests;

  PesticideAttributes({
    required this.activeIngredient,
    required this.concentration,
    required this.volume,
    required this.unit,
    this.targetPests = const [],
  });

  factory PesticideAttributes.fromJson(Map<String, dynamic> json) {
    return PesticideAttributes(
      activeIngredient: json['active_ingredient'] ?? '',
      concentration: json['concentration'] ?? '',
      volume: (json['volume'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'lít',
      targetPests: json['target_pests'] != null
          ? List<String>.from(json['target_pests'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_ingredient': activeIngredient,
      'concentration': concentration,
      'volume': volume,
      'unit': unit,
      'target_pests': targetPests,
    };
  }
}