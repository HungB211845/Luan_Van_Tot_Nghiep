class SeasonalPrice {
  final String id;
  final String productId;
  final double sellingPrice;
  final String seasonName;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final double? markupPercentage;
  final String? notes;
  final DateTime createdAt;

  SeasonalPrice({
    required this.id,
    required this.productId,
    required this.sellingPrice,
    required this.seasonName,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.markupPercentage,
    this.notes,
    required this.createdAt,
  });

  factory SeasonalPrice.fromJson(Map<String, dynamic> json) {
    return SeasonalPrice(
      id: json['id'],
      productId: json['product_id'],
      sellingPrice: (json['selling_price']).toDouble(),
      seasonName: json['season_name'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      isActive: json['is_active'] ?? true,
      markupPercentage: json['markup_percentage']?.toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'selling_price': sellingPrice,
      'season_name': seasonName,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_active': isActive,
      'markup_percentage': markupPercentage,
      'notes': notes,
    };
  }

  // Check if price is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive &&
           now.isAfter(startDate.subtract(Duration(days: 1))) &&
           now.isBefore(endDate.add(Duration(days: 1)));
  }

  SeasonalPrice copyWith({
    double? sellingPrice,
    String? seasonName,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    double? markupPercentage,
    String? notes,
  }) {
    return SeasonalPrice(
      id: id,
      productId: productId,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      seasonName: seasonName ?? this.seasonName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      markupPercentage: markupPercentage ?? this.markupPercentage,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}