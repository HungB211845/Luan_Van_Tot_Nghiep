class SeedAttributes {
  final String strain;
  final String origin;
  final String germinationRate;
  final String purity;
  final String? growthPeriod;
  final String? yield;

  SeedAttributes({
    required this.strain,
    required this.origin,
    required this.germinationRate,
    required this.purity,
    this.growthPeriod,
    this.yield,
  });

  factory SeedAttributes.fromJson(Map<String, dynamic> json) {
    return SeedAttributes(
      strain: json['strain'] ?? '',
      origin: json['origin'] ?? '',
      germinationRate: json['germination_rate'] ?? '',
      purity: json['purity'] ?? '',
      growthPeriod: json['growth_period'],
      yield: json['yield'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strain': strain,
      'origin': origin,
      'germination_rate': germinationRate,
      'purity': purity,
      if (growthPeriod != null) 'growth_period': growthPeriod,
      if (yield != null) 'yield': yield,
    };
  }
}