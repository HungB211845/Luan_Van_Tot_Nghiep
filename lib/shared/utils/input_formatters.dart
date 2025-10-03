import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Currency input formatter for Vietnamese format (1.000, 2.500, etc.)
/// Allows only numbers and automatically formats with thousands separator
class CurrencyInputFormatter extends TextInputFormatter {
  CurrencyInputFormatter({this.maxValue});

  final double? maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty string
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // FIXED: More robust digit extraction
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Prevent input if empty after cleaning
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // FIXED: Prevent leading zeros (except single "0")
    if (digitsOnly.length > 1 && digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      if (digitsOnly.isEmpty) {
        digitsOnly = '0';
      }
    }

    // Convert to number and check max value
    int numValue = int.parse(digitsOnly);
    if (maxValue != null && numValue > maxValue!) {
      return oldValue;
    }

    // Format with thousands separator (Vietnamese style)
    String formatted;
    if (numValue == 0) {
      formatted = '0';
    } else {
      final formatter = NumberFormat('#,##0', 'vi_VN');
      formatted = formatter.format(numValue);
    }

    // FIXED: Always put cursor at the end for predictable behavior
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Quantity input formatter (integer only)
class QuantityInputFormatter extends TextInputFormatter {
  QuantityInputFormatter({this.maxValue = 999999});

  final int maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty string
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // FIXED: More robust digit extraction
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    // FIXED: Prevent leading zeros (except single "0")
    if (digitsOnly.length > 1 && digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      if (digitsOnly.isEmpty) {
        digitsOnly = '0';
      }
    }

    // Convert to int and check max value
    int numValue = int.parse(digitsOnly);
    if (numValue > maxValue) {
      return oldValue;
    }

    // Format with thousands separator for display
    String formatted;
    if (numValue == 0) {
      formatted = '0';
    } else {
      final formatter = NumberFormat('#,##0', 'vi_VN');
      formatted = formatter.format(numValue);
    }

    // FIXED: Always put cursor at the end for predictable behavior
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Decimal number formatter (allows 1 or 2 decimal places)
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.decimalPlaces = 2, this.maxValue});

  final int decimalPlaces;
  final double? maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty string
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only digits, dots, and commas
    String text = newValue.text;
    
    // Replace comma with dot for parsing
    text = text.replaceAll(',', '.');
    
    // Check format: only digits and at most one dot
    RegExp regex = RegExp(r'^\d*\.?\d*$');
    if (!regex.hasMatch(text)) {
      return oldValue;
    }

    // Check decimal places
    if (text.contains('.')) {
      List<String> parts = text.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length > decimalPlaces)) {
        return oldValue;
      }
    }

    // Check max value
    double? numValue = double.tryParse(text);
    if (numValue != null && maxValue != null && numValue > maxValue!) {
      return oldValue;
    }

    // Format for display (Vietnamese style with dots as thousands separator)
    String displayText = text;
    if (numValue != null && !text.endsWith('.')) {
      if (text.contains('.')) {
        // Has decimal part
        List<String> parts = text.split('.');
        String integerPart = NumberFormat('#,##0', 'vi_VN').format(int.parse(parts[0]));
        displayText = '$integerPart,${parts[1]}';
      } else {
        // Integer only
        displayText = NumberFormat('#,##0', 'vi_VN').format(numValue.toInt());
      }
    }

    return TextEditingValue(
      text: displayText,
      selection: TextSelection.collapsed(offset: displayText.length),
    );
  }
}

/// Helper class to extract numeric value from formatted text
class InputFormatterHelper {
  /// Extract numeric value from Vietnamese formatted text
  /// Example: "1.000" -> 1000, "2.500,5" -> 2500.5
  static double? extractNumber(String formattedText) {
    if (formattedText.isEmpty) return null;

    // Remove thousands separators (dots) and replace decimal comma with dot
    String cleaned = formattedText
        .replaceAll(RegExp(r'\.(?=\d{3})'), '') // Remove dots that are thousands separators
        .replaceAll(',', '.'); // Replace decimal comma with dot

    return double.tryParse(cleaned);
  }

  /// Extract integer from formatted text
  static int? extractInteger(String formattedText) {
    if (formattedText.isEmpty) return null;
    
    String cleaned = formattedText.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleaned);
  }

  /// Check if device is mobile (iOS/Android) for keyboard type
  static bool get isMobile {
    // In Flutter, we can use defaultTargetPlatform but for simplicity
    // we'll assume if it's not web, it's mobile
    return true; // This should be refined based on your needs
  }

  /// Get appropriate keyboard type for numeric input on mobile
  static TextInputType getNumericKeyboard({bool allowDecimal = true}) {
    if (allowDecimal) {
      return const TextInputType.numberWithOptions(decimal: true);
    } else {
      return TextInputType.number;
    }
  }
}