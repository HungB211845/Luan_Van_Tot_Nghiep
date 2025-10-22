/// Model representing the result from tax code lookup APIs
///
/// Supports multiple sources:
/// - VIETQR: https://api.vietqr.io/v2/business/{taxCode}
/// - MASOTHUE: https://masothue.com
class TaxCodeLookupResult {
  final String source;              // 'VIETQR' or 'MASOTHUE'
  final String taxCode;
  final String businessName;
  final String address;
  final String? taxAuthority;       // "Thuế cơ sở 15 thành phố Hà Nội"
  final String? legalRepresentative; // "VŨ TIẾN TỚI"
  final String? phoneNumber;
  final String? email;
  final DateTime validatedAt;

  TaxCodeLookupResult({
    required this.source,
    required this.taxCode,
    required this.businessName,
    required this.address,
    this.taxAuthority,
    this.legalRepresentative,
    this.phoneNumber,
    this.email,
    DateTime? validatedAt,
  }) : validatedAt = validatedAt ?? DateTime.now();

  /// Factory constructor for VietQR API response
  ///
  /// VietQR response structure:
  /// ```json
  /// {
  ///   "code": "00",
  ///   "data": {
  ///     "id": "0111256085",
  ///     "name": "CÔNG TY CỔ PHẦN...",
  ///     "address": "Lô số 2 Bái Sảy...",
  ///     "status": "NNT đang hoạt động"
  ///   }
  /// }
  /// ```
  factory TaxCodeLookupResult.fromVietQR(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    return TaxCodeLookupResult(
      source: 'VIETQR',
      taxCode: data['id']?.toString() ?? '',
      businessName: data['name']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      taxAuthority: null,  // VietQR doesn't provide this field
      legalRepresentative: null,  // VietQR doesn't provide this field
      phoneNumber: null,
      email: null,
    );
  }

  /// Factory constructor for masothue.com API response
  ///
  /// Masothue response structure (to be confirmed):
  /// ```json
  /// {
  ///   "mst": "2500756648",
  ///   "ten": "BẢO HIỂM XÃ HỘI CƠ SỞ VĨNH PHÚC",
  ///   "dia_chi_thue": "Số 8, đường Hai Bà Trưng...",
  ///   "quan_ly_boi": "Thuế cơ sở 8 tỉnh Phú Thọ",
  ///   "nguoi_dai_dien": "...",
  ///   "dien_thoai": "0974881987"
  /// }
  /// ```
  factory TaxCodeLookupResult.fromMasothue(Map<String, dynamic> json) {
    return TaxCodeLookupResult(
      source: 'MASOTHUE',
      taxCode: json['mst']?.toString() ?? json['tax_code']?.toString() ?? '',
      businessName: json['ten']?.toString() ?? json['name']?.toString() ?? '',
      address: json['dia_chi_thue']?.toString() ?? json['address']?.toString() ?? '',
      taxAuthority: json['quan_ly_boi']?.toString() ?? json['tax_authority']?.toString(),
      legalRepresentative: json['nguoi_dai_dien']?.toString() ?? json['legal_representative']?.toString(),
      phoneNumber: json['dien_thoai']?.toString() ?? json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }

  /// Convert to auto-fill data map for form fields
  Map<String, String> toAutoFillData() {
    return {
      'business_name': businessName,
      'tax_authority': taxAuthority ?? '',
      'business_address': address,
      'legal_representative': legalRepresentative ?? '',
      'phone_number': phoneNumber ?? '',
      'email': email ?? '',
    };
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'tax_code': taxCode,
      'business_name': businessName,
      'address': address,
      'tax_authority': taxAuthority,
      'legal_representative': legalRepresentative,
      'phone_number': phoneNumber,
      'email': email,
      'validated_at': validatedAt.toIso8601String(),
    };
  }

  /// Restore from JSON (for caching)
  factory TaxCodeLookupResult.fromJson(Map<String, dynamic> json) {
    return TaxCodeLookupResult(
      source: json['source'] as String,
      taxCode: json['tax_code'] as String,
      businessName: json['business_name'] as String,
      address: json['address'] as String,
      taxAuthority: json['tax_authority'] as String?,
      legalRepresentative: json['legal_representative'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      validatedAt: DateTime.parse(json['validated_at'] as String),
    );
  }
}
