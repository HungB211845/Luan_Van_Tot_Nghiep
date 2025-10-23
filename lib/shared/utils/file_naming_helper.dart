import 'package:intl/intl.dart';
import '../../features/auth/screens/invoice_settings_screen.dart';

/// Utility for generating accounting-compliant filenames
/// Following Vietnamese accounting standards and ISO 8601
///
/// Format: <LOẠI>_<ĐỐI_TƯỢNG>_<KHOẢNG_THỜI_GIAN>_<NGÀY_XUẤT>.<ĐỊNH_DẠNG>
/// Example: BaoCaoGiaoDich_CTYLeTrong_2025-10_2025-10-31.xlsx
class FileNamingHelper {
  /// Remove Vietnamese diacritics from text
  ///
  /// Converts: "Công ty TNHH Lê Trọng" → "Cong ty TNHH Le Trong"
  static String removeDiacritics(String text) {
    const vietnamese = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
                       'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const normalized = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyyd'
                       'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYYD';

    String result = text;
    for (int i = 0; i < vietnamese.length; i++) {
      result = result.replaceAll(vietnamese[i], normalized[i]);
    }
    return result;
  }

  /// Convert text to filename-safe string
  ///
  /// Removes diacritics, spaces, and special characters
  /// "Công ty TNHH Lê Trọng" → "CongTyTNHHLeTrong"
  static String toFilenameSafeString(String text) {
    // Remove diacritics
    String result = removeDiacritics(text);

    // Remove spaces and special characters, keep only alphanumeric
    result = result.replaceAll(RegExp(r'[^\w]+'), '');

    return result;
  }

  /// Format date range label for filename
  ///
  /// Examples:
  /// - Month: "2025-10"
  /// - Quarter: "2025-Q4"
  /// - Year: "2025"
  /// - Custom: "2025-10-01_to_2025-10-31"
  static String formatDateRange(
    DateTime startDate,
    DateTime endDate, {
    DateRangePreset? preset,
  }) {
    final dateFormatter = DateFormat('yyyy-MM-dd');

    if (preset != null) {
      switch (preset) {
        case DateRangePreset.thisMonth:
          return DateFormat('yyyy-MM').format(startDate); // "2025-10"

        case DateRangePreset.thisQuarter:
          final quarter = ((startDate.month - 1) ~/ 3) + 1;
          return '${startDate.year}-Q$quarter'; // "2025-Q4"

        case DateRangePreset.thisYear:
          return startDate.year.toString(); // "2025"

        case DateRangePreset.custom:
          return '${dateFormatter.format(startDate)}_to_${dateFormatter.format(endDate)}';
      }
    }

    // Default: custom range format
    return '${dateFormatter.format(startDate)}_to_${dateFormatter.format(endDate)}';
  }

  /// Generate accounting-compliant filename for transaction report
  ///
  /// Format: BaoCaoGiaoDich_<BusinessName>_<DateRange>_<ExportDate>.<Format>
  /// Example: BaoCaoGiaoDich_CTYLeTrong_2025-10_2025-10-31.xlsx
  static String generateTransactionReportFilename({
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    required String format, // 'xlsx' or 'pdf'
    DateRangePreset? preset,
  }) {
    final safeName = toFilenameSafeString(businessName);
    final dateRange = formatDateRange(startDate, endDate, preset: preset);
    final exportDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return 'BaoCaoGiaoDich_${safeName}_${dateRange}_$exportDate.$format';
  }

  /// Generate accounting-compliant filename for transaction invoice
  ///
  /// Format: HoaDonBanHang_BusinessName_InvoiceNumber_ExportDate.Format
  /// Example: HoaDonBanHang_CTYLeTrong_HD001234_2025-10-31.pdf
  static String generateTransactionInvoiceFilename({
    required String businessName,
    required String invoiceNumber,
    required String format, // 'pdf' or 'xlsx'
  }) {
    final safeName = toFilenameSafeString(businessName);
    final safeInvoiceNum = toFilenameSafeString(invoiceNumber);
    final exportDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return 'HoaDonBanHang_${safeName}_${safeInvoiceNum}_$exportDate.$format';
  }

  /// Generate accounting-compliant filename for purchase order invoice
  ///
  /// Format: HoaDonMuaHang_BusinessName_PONumber_ExportDate.Format
  /// Example: HoaDonMuaHang_CTYLeTrong_PO001234_2025-10-31.pdf
  static String generatePOInvoiceFilename({
    required String businessName,
    required String poNumber,
    required String format, // 'pdf' or 'xlsx'
  }) {
    final safeName = toFilenameSafeString(businessName);
    final safePONum = toFilenameSafeString(poNumber);
    final exportDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return 'HoaDonMuaHang_${safeName}_${safePONum}_$exportDate.$format';
  }

  /// Get fallback business name when store info is not available
  ///
  /// Returns: "UnknownBusiness"
  static String getFallbackBusinessName() {
    return 'UnknownBusiness';
  }
}
