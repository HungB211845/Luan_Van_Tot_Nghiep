/// Utility class for validating Vietnamese Tax Code (MST - Mã Số Thuế)
///
/// Vietnamese Tax Code formats:
/// - Individual/Household: 10 digits (old format) or 13 digits (new format from 2026)
/// - Enterprise: 10 digits (old format) or 13 digits (new format)
///
/// Format: XXXXXXXXXX or XXXXXXXXXXXXX
class TaxCodeValidator {
  /// Validate tax code format (10 or 13 digits)
  static bool isValidFormat(String taxCode) {
    if (taxCode.isEmpty) return false;

    // Remove spaces and dashes
    final cleaned = taxCode.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it's exactly 10 or 13 digits
    if (cleaned.length != 10 && cleaned.length != 13) {
      return false;
    }

    // Check if all characters are digits
    return RegExp(r'^\d+$').hasMatch(cleaned);
  }

  /// Clean tax code (remove spaces and dashes)
  static String clean(String taxCode) {
    return taxCode.replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Format tax code for display (add dashes)
  /// 10-digit: XXXX-XXX-XXX
  /// 13-digit: XXXX-XXX-XXX-XXX
  static String format(String taxCode) {
    final cleaned = clean(taxCode);

    if (cleaned.length == 10) {
      // Format: XXXX-XXX-XXX
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 7)}-${cleaned.substring(7, 10)}';
    } else if (cleaned.length == 13) {
      // Format: XXXX-XXX-XXX-XXX
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 7)}-${cleaned.substring(7, 10)}-${cleaned.substring(10, 13)}';
    }

    return taxCode; // Return as-is if invalid length
  }

  /// Validate and return error message if invalid
  static String? validateWithMessage(String taxCode) {
    if (taxCode.isEmpty) {
      return 'Mã số thuế không được để trống';
    }

    final cleaned = clean(taxCode);

    if (cleaned.length != 10 && cleaned.length != 13) {
      return 'Mã số thuế phải có 10 hoặc 13 chữ số';
    }

    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Mã số thuế chỉ được chứa chữ số';
    }

    return null; // Valid
  }

  /// Check if tax code is new format (13 digits - from 2026)
  static bool isNewFormat(String taxCode) {
    final cleaned = clean(taxCode);
    return cleaned.length == 13;
  }

  /// Check if tax code is old format (10 digits)
  static bool isOldFormat(String taxCode) {
    final cleaned = clean(taxCode);
    return cleaned.length == 10;
  }
}
