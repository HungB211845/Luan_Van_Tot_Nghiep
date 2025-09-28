import 'package:intl/intl.dart';

class AppFormatter {
  // Formatter cho số nguyên, không có số thập phân, ký hiệu VND
  static final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VND',
    decimalDigits: 0, // Không hiển thị phần thập phân cho số nguyên
  );

  // Formatter cho số thập phân, ký hiệu VND
  static final _decimalCurrencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VND',
  );

  /// Định dạng một số (double hoặc int) thành chuỗi tiền tệ VND.
  ///
  /// Tự động chọn định dạng phù hợp (có hoặc không có phần thập phân).
  /// Ví dụ: 
  /// - formatCurrency(1000) => "1.000 VND"
  /// - formatCurrency(1000.5) => "1.000,5 VND"
  static String formatCurrency(num amount) {
    // Nếu số là số nguyên, dùng formatter không có phần thập phân
    if (amount % 1 == 0) {
      return _currencyFormat.format(amount);
    }
    // Nếu là số thập phân, dùng formatter mặc định
    return _decimalCurrencyFormat.format(amount);
  }

  /// Định dạng một số lớn thành chuỗi có dấu phân cách hàng nghìn.
  ///
  /// Ví dụ: formatNumber(1234567) => "1.234.567"
  static String formatNumber(num number) {
    final format = NumberFormat('#,##0', 'vi_VN');
    return format.format(number);
  }

  /// Định dạng DateTime thành chuỗi ngày (dd/MM/yyyy).
  ///
  /// Ví dụ: formatDate(DateTime(2024, 07, 28)) => "28/07/2024"
  /// Nếu date là null, trả về chuỗi rỗng.
  static String formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Định dạng DateTime thành chuỗi ngày và giờ (dd/MM/yyyy HH:mm).
  ///
  /// Ví dụ: formatDateTime(DateTime(2024, 07, 28, 14, 30)) => "28/07/2024 14:30"
  /// Nếu date là null, trả về chuỗi rỗng.
  static String formatDateTime(DateTime? date) {
    if (date == null) {
      return '';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
