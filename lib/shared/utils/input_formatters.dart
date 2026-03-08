import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

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

    // 🔥 WEB FIX: Handle text selection safely for web platform
    int cursorPosition;
    if (kIsWeb) {
      // Web: Always place cursor at end to prevent TextInput assertions
      cursorPosition = formatted.length;
    } else {
      // Mobile: Calculate proper cursor position
      final oldLength = oldValue.text.replaceAll(RegExp(r'[^\d]'), '').length;
      final newLength = digitsOnly.length;
      final lengthDiff = newLength - oldLength;
      
      if (lengthDiff > 0) {
        cursorPosition = formatted.length;
      } else {
        cursorPosition = (oldValue.selection.baseOffset + lengthDiff).clamp(0, formatted.length);
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
      composing: kIsWeb ? TextRange.empty : newValue.composing, // 🔥 WEB FIX: Clear composing on web
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

/// Web-safe digits-only input formatter
/// Prevents TextInput assertion errors on Flutter Web
class WebSafeDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow only digits
    final filteredText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // 🔥 WEB FIX: Always return safe TextEditingValue with cleared composing
    return TextEditingValue(
      text: filteredText,
      selection: kIsWeb 
        ? TextSelection.collapsed(offset: filteredText.length.clamp(0, filteredText.length))
        : TextSelection.collapsed(
            offset: (newValue.selection.baseOffset).clamp(0, filteredText.length)
          ),
      composing: TextRange.empty, // ← Always clear composing on web to prevent assertion
    );
  }
}
