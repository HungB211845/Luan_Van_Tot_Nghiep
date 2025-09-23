class FertilizerAttributes {
  final String npkRatio;
  final String type; // 'vô cơ', 'hữu cơ'
  final int weight;
  final String unit; // 'kg', 'bao'
  final int? nitrogen;
  final int? phosphorus;
  final int? potassium;

  FertilizerAttributes({
    required this.npkRatio,
    required this.type,
    required this.weight,
    required this.unit,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
  });

  factory FertilizerAttributes.fromJson(Map<String, dynamic> json) {
    return FertilizerAttributes(
      npkRatio: json['npk_ratio'] ?? '',
      type: json['type'] ?? '',
      weight: json['weight'] ?? 0,
      unit: json['unit'] ?? 'kg',
      nitrogen: json['nitrogen'],
      phosphorus: json['phosphorus'],
      potassium: json['potassium'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'npk_ratio': npkRatio,
      'type': type,
      'weight': weight,
      'unit': unit,
      if (nitrogen != null) 'nitrogen': nitrogen,
      if (phosphorus != null) 'phosphorus': phosphorus,
      if (potassium != null) 'potassium': potassium,
    };
  }
}