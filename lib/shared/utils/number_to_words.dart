/// Utility for converting numbers to Vietnamese words
/// For invoice compliance per NĐ 123/2020, TT 32/2025
///
/// Example: 5350000 → "Năm triệu ba trăm năm mươi nghìn đồng chẵn"

class NumberToVietnameseWords {
  // Vietnamese number words
  static const List<String> _units = [
    '',
    'một',
    'hai',
    'ba',
    'bốn',
    'năm',
    'sáu',
    'bảy',
    'tám',
    'chín',
  ];

  static const List<String> _scales = [
    '',
    'nghìn',
    'triệu',
    'tỷ',
    'nghìn tỷ',
    'triệu tỷ',
  ];

  /// Convert amount to Vietnamese words (for invoices)
  ///
  /// Examples:
  /// - 0 → "Không đồng"
  /// - 5350000 → "Năm triệu ba trăm năm mươi nghìn đồng chẵn"
  /// - 123456 → "Một trăm hai mươi ba nghìn bốn trăm năm mươi sáu đồng"
  /// - 1000000.5 → "Một triệu đồng" (decimals truncated)
  static String convertToVietnameseWords(double amount) {
    // Truncate decimals (invoices use VNĐ, no cents)
    final int intAmount = amount.truncate();

    // Handle zero
    if (intAmount == 0) {
      return 'Không đồng';
    }

    // Handle negative (should not happen in invoices, but handle gracefully)
    if (intAmount < 0) {
      return 'Âm ' + convertToVietnameseWords(intAmount.abs().toDouble());
    }

    // Convert number to words
    final words = _convertNumberToWords(intAmount);

    // Add currency suffix
    // If amount is round (ends with 000s), add "chẵn" (exactly)
    if (intAmount % 1000 == 0 && intAmount >= 1000) {
      return '$words đồng chẵn';
    }

    return '$words đồng';
  }

  /// Internal: Convert integer to Vietnamese words
  static String _convertNumberToWords(int number) {
    if (number == 0) return 'không';
    if (number < 0) return 'âm ${_convertNumberToWords(-number)}';

    // Split number into groups of 3 digits (thousands, millions, billions)
    final groups = <int>[];
    int remaining = number;

    while (remaining > 0) {
      groups.add(remaining % 1000);
      remaining ~/= 1000;
    }

    // Convert each group to words
    final parts = <String>[];
    for (int i = groups.length - 1; i >= 0; i--) {
      final group = groups[i];
      if (group == 0) continue;

      final groupWords = _convertThreeDigits(group, i > 0);
      final scale = i < _scales.length ? _scales[i] : '';

      parts.add('$groupWords ${scale}'.trim());
    }

    String result = parts.join(' ');

    // Capitalize first letter
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result.trim();
  }

  /// Internal: Convert 3-digit group to words
  ///
  /// [number] - number from 0 to 999
  /// [hasHigherGroup] - true if there are higher groups (for handling "linh" and "lẻ")
  static String _convertThreeDigits(int number, bool hasHigherGroup) {
    if (number == 0) return '';
    if (number < 10) return _units[number];

    final hundreds = number ~/ 100;
    final tens = (number % 100) ~/ 10;
    final ones = number % 10;

    final parts = <String>[];

    // Hundreds
    if (hundreds > 0) {
      parts.add('${_units[hundreds]} trăm');
    }

    // Tens
    if (tens == 0 && ones > 0) {
      // 105 → "một trăm linh năm" (not "một trăm năm")
      // But 5 → "năm" (no "linh" when no hundreds)
      if (hundreds > 0) {
        parts.add('linh');
      } else if (hasHigherGroup) {
        parts.add('lẻ');
      }
    } else if (tens == 1) {
      parts.add('mười');
    } else if (tens > 1) {
      parts.add('${_units[tens]} mươi');
    }

    // Ones
    if (ones > 0) {
      if (ones == 1 && tens > 1) {
        // 21 → "hai mươi mốt" (not "hai mươi một")
        parts.add('mốt');
      } else if (ones == 5 && tens > 0) {
        // 15 → "mười lăm", 25 → "hai mươi lăm"
        parts.add('lăm');
      } else {
        parts.add(_units[ones]);
      }
    }

    return parts.join(' ');
  }

  /// Format amount with Vietnamese currency
  ///
  /// Examples:
  /// - 5350000 → "5.350.000 VNĐ"
  /// - 123456 → "123.456 VNĐ"
  static String formatCurrency(double amount) {
    final intAmount = amount.truncate();
    final str = intAmount.toString();

    // Add thousand separators (dot notation in Vietnam)
    final parts = <String>[];
    for (int i = str.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, str.substring(start, i));
    }

    return '${parts.join('.')} VNĐ';
  }
}
