import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for Tax Code Information returned from API
class TaxCodeInfo {
  final String taxCode;
  final String businessName;
  final String? taxAuthority;
  final String? address;
  final String? legalRepresentative;
  final String? businessStatus; // 'active' | 'inactive' | 'suspended'
  final DateTime? registrationDate;
  final String source; // API source name

  const TaxCodeInfo({
    required this.taxCode,
    required this.businessName,
    this.taxAuthority,
    this.address,
    this.legalRepresentative,
    this.businessStatus,
    this.registrationDate,
    required this.source,
  });

  factory TaxCodeInfo.fromJson(Map<String, dynamic> json, String source) {
    return TaxCodeInfo(
      taxCode: json['tax_code']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      taxAuthority: json['tax_authority']?.toString(),
      address: json['address']?.toString(),
      legalRepresentative: json['legal_representative']?.toString(),
      businessStatus: json['business_status']?.toString(),
      registrationDate: json['registration_date'] != null
          ? DateTime.tryParse(json['registration_date'])
          : null,
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tax_code': taxCode,
      'business_name': businessName,
      'tax_authority': taxAuthority,
      'address': address,
      'legal_representative': legalRepresentative,
      'business_status': businessStatus,
      'registration_date': registrationDate?.toIso8601String(),
      'source': source,
    };
  }
}

/// API Client for Tax Code lookup
///
/// Supports multiple API providers:
/// 1. masothue.com (unofficial public API)
/// 2. Custom internal API (if available)
class TaxCodeApiClient {
  static const Duration timeout = Duration(seconds: 10);

  /// Lookup tax code information from public APIs
  ///
  /// Returns TaxCodeInfo if found, null if not found
  /// Throws Exception on API errors
  static Future<TaxCodeInfo?> lookup(String taxCode) async {
    // Try masothue.com API first
    try {
      final result = await _lookupFromMasothue(taxCode);
      if (result != null) return result;
    } catch (e) {
      print('Warning: masothue.com API failed: $e');
      // Continue to next provider
    }

    // TODO: Add more API providers here
    // Example:
    // try {
    //   final result = await _lookupFromGDT(taxCode);
    //   if (result != null) return result;
    // } catch (e) {
    //   print('Warning: GDT API failed: $e');
    // }

    return null; // Not found in any provider
  }

  /// Lookup from masothue.com API
  ///
  /// API endpoint: https://api.masothue.com/api/lookup/{taxCode}
  /// Note: This is an unofficial API and may change or require authentication
  static Future<TaxCodeInfo?> _lookupFromMasothue(String taxCode) async {
    final url = Uri.parse('https://api.masothue.com/api/lookup/$taxCode');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Check if data exists
        if (data['success'] == true && data['data'] != null) {
          final businessData = data['data'] as Map<String, dynamic>;

          return TaxCodeInfo(
            taxCode: taxCode,
            businessName: businessData['name']?.toString() ?? '',
            taxAuthority: businessData['tax_department']?.toString(),
            address: businessData['address']?.toString(),
            legalRepresentative: businessData['representative']?.toString(),
            businessStatus: businessData['status']?.toString(),
            registrationDate: businessData['registration_date'] != null
                ? DateTime.tryParse(businessData['registration_date'])
                : null,
            source: 'masothue.com',
          );
        }
      } else if (response.statusCode == 404) {
        return null; // Not found
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException || e.toString().contains('SocketException')) {
        throw Exception('Không thể kết nối đến server tra cứu MST');
      }
      rethrow;
    }

    return null;
  }

  /// Lookup from Tổng cục Thuế Vietnam (GDT) API
  ///
  /// TODO: Research and implement official GDT API if available
  /// Current GDT website: https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp
  static Future<TaxCodeInfo?> _lookupFromGDT(String taxCode) async {
    // TODO: Implement official GDT API lookup
    // This may require web scraping if no official API exists
    throw UnimplementedError('GDT API lookup not yet implemented');
  }

  /// Check if API service is available
  static Future<bool> checkAvailability() async {
    try {
      // Test with a known valid tax code (example)
      final result = await lookup('0100109106');
      return true; // If no exception, service is available
    } catch (e) {
      return false;
    }
  }
}
