import 'package:flutter/services.dart';

/// Custom TextInputFormatter for VND currency
/// Formats: 1000000 → 1.000.000
class CurrencyInputFormatter extends TextInputFormatter {
  final double? maxValue;

  CurrencyInputFormatter({this.maxValue});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Check max value
    final value = double.tryParse(digitsOnly);
    if (value != null && maxValue != null && value > maxValue!) {
      return oldValue;
    }

    // Format with thousand separators (dot)
    String formatted = _formatWithDots(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithDots(String number) {
    if (number.isEmpty) return '';

    // Reverse the string to add dots from right to left
    String reversed = number.split('').reversed.join();
    String result = '';

    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        result += '.';
      }
      result += reversed[i];
    }

    return result.split('').reversed.join();
  }
}
