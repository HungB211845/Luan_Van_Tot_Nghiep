import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tax_code_lookup_result.dart';

/// API Client for Tax Code lookup with cascade fallback
///
/// Supports multiple sources in priority order:
/// 1. VietQR (https://api.vietqr.io) - Primary source, official GDT data
/// 2. masothue.com - Fallback source
///
/// Returns TaxCodeLookupResult with source information
class TaxCodeApiClient {
  static const Duration timeout = Duration(seconds: 10);

  // Primary source: VietQR
  static const String vietQRBaseUrl = 'https://api.vietqr.io/v2/business';

  // Fallback source: masothue.com
  static const String masothueBaseUrl = 'https://api.masothue.com/api/lookup';

  /// Cascade lookup: VietQR → masothue → null
  ///
  /// Returns TaxCodeLookupResult if found, null if not found
  /// Silently catches errors and falls back to next provider
  static Future<TaxCodeLookupResult?> lookup(String taxCode) async {
    // Try VietQR first (official GDT data)
    try {
      final result = await _lookupVietQR(taxCode);
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('VietQR lookup failed: $e');
      // Continue to fallback
    }

    // Fallback to masothue.com
    try {
      final result = await _lookupMasothue(taxCode);
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('Masothue lookup failed: $e');
    }

    // All sources failed
    return null;
  }

  /// Lookup from VietQR API (Primary source)
  ///
  /// API: GET https://api.vietqr.io/v2/business/{taxCode}
  ///
  /// Response structure:
  /// ```json
  /// {
  ///   "code": "00",
  ///   "desc": "Success",
  ///   "data": {
  ///     "id": "0111256085",
  ///     "name": "CÔNG TY CỔ PHẦN TRUYỀN THÔNG SHINEUP MEDIA",
  ///     "address": "Lô số 2 Bái Sảy, Ngõ 195 Quang Trung, Phường Hà Đông, TP Hà Nội",
  ///     "status": "NNT đang hoạt động"
  ///   },
  ///   "metadata": {
  ///     "source": "gdt.gov.vn",
  ///     "updatedAt": "2025-10-01T07:23:13.000Z"
  ///   }
  /// }
  /// ```
  static Future<TaxCodeLookupResult?> _lookupVietQR(String taxCode) async {
    final url = Uri.parse('$vietQRBaseUrl/$taxCode');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Check success code
        if (json['code'] == '00' && json['data'] != null) {
          return TaxCodeLookupResult.fromVietQR(json);
        }
      } else if (response.statusCode == 404) {
        // Not found in VietQR
        return null;
      }

      // Other error codes - let fallback handle it
      return null;
    } on http.ClientException {
      // Network error - let fallback handle it
      return null;
    }
  }

  /// Lookup from masothue.com API (Fallback source)
  ///
  /// API: GET https://api.masothue.com/api/lookup/{taxCode}
  ///
  /// Expected response structure:
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "mst": "2500756648",
  ///     "ten": "BẢO HIỂM XÃ HỘI CƠ SỞ VĨNH PHÚC",
  ///     "dia_chi_thue": "Số 8, đường Hai Bà Trưng, Phường Vĩnh Phúc, Tỉnh Phú Thọ",
  ///     "quan_ly_boi": "Thuế cơ sở 8 tỉnh Phú Thọ",
  ///     "nguoi_dai_dien": "...",
  ///     "dien_thoai": "0974881987"
  ///   }
  /// }
  /// ```
  static Future<TaxCodeLookupResult?> _lookupMasothue(String taxCode) async {
    final url = Uri.parse('$masothueBaseUrl/$taxCode');

    try {
      final response = await http.get(url).timeout(timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Check if data exists
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'] as Map<String, dynamic>;
          return TaxCodeLookupResult.fromMasothue(data);
        }
      } else if (response.statusCode == 404) {
        // Not found
        return null;
      }

      return null;
    } on http.ClientException {
      // Network error
      return null;
    }
  }

  /// Check if API services are available
  ///
  /// Tests with a known valid tax code
  static Future<bool> checkAvailability() async {
    try {
      // Test with known valid MST
      final result = await lookup('0111256085');
      return result != null;
    } catch (e) {
      return false;
    }
  }
}
