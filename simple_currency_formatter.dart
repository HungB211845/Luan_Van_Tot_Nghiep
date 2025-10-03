import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Simple and reliable currency formatter
/// Use this temporarily to test if issue persists
class SimpleCurrencyInputFormatter extends TextInputFormatter {
  SimpleCurrencyInputFormatter({this.maxValue});

  final double? maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handle empty input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Extract only digits
    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Return empty if no numbers
    if (numbersOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse as integer (no decimals)
    int value;
    try {
      value = int.parse(numbersOnly);
    } catch (e) {
      return oldValue; // Keep old value if parsing fails
    }

    // Check max value constraint
    if (maxValue != null && value > maxValue!) {
      return oldValue;
    }

    // Format with Vietnamese thousands separator
    String formattedText;
    try {
      final formatter = NumberFormat('#,##0', 'vi_VN');
      formattedText = formatter.format(value);
    } catch (e) {
      // Fallback: manual formatting if NumberFormat fails
      formattedText = _manualFormat(value);
    }

    // Return with cursor at end
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  /// Manual fallback formatting function
  String _manualFormat(int value) {
    String valueStr = value.toString();
    String result = '';
    int count = 0;
    
    // Add dots from right to left
    for (int i = valueStr.length - 1; i >= 0; i--) {
      if (count == 3) {
        result = '.' + result;
        count = 0;
      }
      result = valueStr[i] + result;
      count++;
    }
    
    return result;
  }
}

/// Usage example for testing in QuickAddBatchSheet:
/// 
/// TextFormField(
///   controller: _costPriceController,
///   inputFormatters: [
///     SimpleCurrencyInputFormatter(maxValue: 999999999),
///   ],
///   keyboardType: TextInputType.number,
///   // ... rest of configuration
/// )