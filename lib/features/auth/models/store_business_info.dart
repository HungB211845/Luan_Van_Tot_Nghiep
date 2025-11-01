class StoreBusinessInfo {
  final String id;
  final String storeId;

  // Tax & Business Info
  final String taxCode;
  final String businessName;
  final String? taxAuthority;
  final String? businessAddress;

  // Contact Info
  final String? phoneNumber;
  final String? email;

  // Banking Info (Optional)
  final String? bankAccount;
  final String? bankName;
  final String? bankBranch;

  // Legal Info
  final String? legalRepresentative;

  // Invoice Info (NĐ 123/2020, TT 32/2025)
  final String? invoiceSymbol;           // Ký hiệu HĐDT (VD: 1C25TYY)
  final String? invoiceTemplateCode;     // Mẫu số HĐDT (VD: 01GTKT3/001)
  final double defaultVatRate;           // % VAT mặc định (0-100)
  final double revenueTaxRate;           // % thuế khoán trên doanh thu (0-100)
  final String? website;
  final String? logoUrl;

  // Validation Info
  final DateTime? validatedAt;
  final String? validationSource; // 'API' | 'MANUAL'

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreBusinessInfo({
    required this.id,
    required this.storeId,
    required this.taxCode,
    required this.businessName,
    this.taxAuthority,
    this.businessAddress,
    this.phoneNumber,
    this.email,
    this.bankAccount,
    this.bankName,
    this.bankBranch,
    this.legalRepresentative,
    this.invoiceSymbol,
    this.invoiceTemplateCode,
    this.defaultVatRate = 0.0,
    this.revenueTaxRate = 1.5,
    this.website,
    this.logoUrl,
    this.validatedAt,
    this.validationSource,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreBusinessInfo.fromJson(Map<String, dynamic> json) {
    return StoreBusinessInfo(
      id: json['id']?.toString() ?? '',
      storeId: json['store_id']?.toString() ?? '',
      taxCode: json['tax_code']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      taxAuthority: json['tax_authority']?.toString(),
      businessAddress: json['business_address']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      email: json['email']?.toString(),
      bankAccount: json['bank_account']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankBranch: json['bank_branch']?.toString(),
      legalRepresentative: json['legal_representative']?.toString(),
      invoiceSymbol: json['invoice_symbol']?.toString(),
      invoiceTemplateCode: json['invoice_template_code']?.toString(),
      defaultVatRate: (json['default_vat_rate'] as num?)?.toDouble() ?? 0.0,
      revenueTaxRate: (json['revenue_tax_rate'] as num?)?.toDouble() ?? 1.5,
      website: json['website']?.toString(),
      logoUrl: json['logo_url']?.toString(),
      validatedAt: json['validated_at'] != null
          ? DateTime.parse(json['validated_at'])
          : null,
      validationSource: json['validation_source']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'tax_code': taxCode,
      'business_name': businessName,
      'tax_authority': taxAuthority,
      'business_address': businessAddress,
      'phone_number': phoneNumber,
      'email': email,
      'bank_account': bankAccount,
      'bank_name': bankName,
      'bank_branch': bankBranch,
      'legal_representative': legalRepresentative,
      'invoice_symbol': invoiceSymbol,
      'invoice_template_code': invoiceTemplateCode,
      'default_vat_rate': defaultVatRate,
      'revenue_tax_rate': revenueTaxRate,
      'website': website,
      'logo_url': logoUrl,
      'validated_at': validatedAt?.toIso8601String(),
      'validation_source': validationSource,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StoreBusinessInfo copyWith({
    String? id,
    String? storeId,
    String? taxCode,
    String? businessName,
    String? taxAuthority,
    String? businessAddress,
    String? phoneNumber,
    String? email,
    String? bankAccount,
    String? bankName,
    String? bankBranch,
    String? legalRepresentative,
    String? invoiceSymbol,
    String? invoiceTemplateCode,
    double? defaultVatRate,
    double? revenueTaxRate,
    String? website,
    String? logoUrl,
    DateTime? validatedAt,
    String? validationSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreBusinessInfo(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      taxCode: taxCode ?? this.taxCode,
      businessName: businessName ?? this.businessName,
      taxAuthority: taxAuthority ?? this.taxAuthority,
      businessAddress: businessAddress ?? this.businessAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      bankAccount: bankAccount ?? this.bankAccount,
      bankName: bankName ?? this.bankName,
      bankBranch: bankBranch ?? this.bankBranch,
      legalRepresentative: legalRepresentative ?? this.legalRepresentative,
      invoiceSymbol: invoiceSymbol ?? this.invoiceSymbol,
      invoiceTemplateCode: invoiceTemplateCode ?? this.invoiceTemplateCode,
      defaultVatRate: defaultVatRate ?? this.defaultVatRate,
      revenueTaxRate: revenueTaxRate ?? this.revenueTaxRate,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      validatedAt: validatedAt ?? this.validatedAt,
      validationSource: validationSource ?? this.validationSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper method to check if business info is complete
  bool get isComplete {
    return taxCode.isNotEmpty &&
        businessName.isNotEmpty &&
        (phoneNumber?.isNotEmpty ?? false);
  }

  /// Helper method to check if invoice info is ready (for compliant invoicing)
  bool get isInvoiceReady {
    return isComplete &&
        (invoiceSymbol?.isNotEmpty ?? false) &&
        (invoiceTemplateCode?.isNotEmpty ?? false);
  }

  /// Helper method to check if validated via API
  bool get isApiValidated {
    return (validationSource == 'API' ||
            validationSource == 'VIETQR' ||
            validationSource == 'MASOTHUE') &&
           validatedAt != null;
  }
}
