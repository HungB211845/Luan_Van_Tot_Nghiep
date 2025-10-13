// Debug test for input formatter issue
// Run: flutter test debug_input_test.dart (or just check logic)

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  print('🐛 Debugging Input Formatter Issues...\n');
  
  testCurrencyInputFormatter();
}

void testCurrencyInputFormatter() {
  print('Testing step-by-step input sequence:');
  
  final formatter = CurrencyInputFormatter();
  
  // Simulate typing "25" character by character
  print('\n📱 Simulating user typing "25":');
  
  // Step 1: User types "2"
  var result1 = formatter.formatEditUpdate(
    const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
    const TextEditingValue(text: '2', selection: TextSelection.collapsed(offset: 1)),
  );
  print('  Step 1: Input "2" → Output: "${result1.text}" (cursor at ${result1.selection.baseOffset})');
  
  // Step 2: User types "5" (now "25")
  var result2 = formatter.formatEditUpdate(
    result1, // Previous state
    const TextEditingValue(text: '25', selection: TextSelection.collapsed(offset: 2)),
  );
  print('  Step 2: Input "25" → Output: "${result2.text}" (cursor at ${result2.selection.baseOffset})');
  
  // Test with thousands separator cases
  print('\n📱 Testing thousands separator cases:');
  
  // Test "1000" 
  var result3 = formatter.formatEditUpdate(
    const TextEditingValue.empty,
    const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 4)),
  );
  print('  Input "1000" → Output: "${result3.text}"');
  
  // Test "25000"
  var result4 = formatter.formatEditUpdate(
    const TextEditingValue.empty,
    const TextEditingValue(text: '25000', selection: TextSelection.collapsed(offset: 5)),
  );
  print('  Input "25000" → Output: "${result4.text}"');
}

// Simplified CurrencyInputFormatter for testing
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

    // Remove all non-digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Prevent input if empty after cleaning
    if (digitsOnly.isEmpty) {
      return oldValue;
    }

    // Convert to number and check max value
    double numValue = double.parse(digitsOnly);
    if (maxValue != null && numValue > maxValue!) {
      return oldValue;
    }

    // Format with thousands separator (Vietnamese style)
    final formatter = NumberFormat('#,##0', 'vi_VN');
    String formatted = formatter.format(numValue);

    // FIXED: Simple cursor positioning - always at the end
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Mock classes for testing
class TextEditingValue {
  final String text;
  final TextSelection selection;
  
  const TextEditingValue({
    required this.text,
    required this.selection,
  });
  
  static const empty = TextEditingValue(
    text: '',
    selection: TextSelection.collapsed(offset: 0),
  );
}

class TextSelection {
  final int baseOffset;
  final int extentOffset;
  
  const TextSelection.collapsed({required int offset}) 
    : baseOffset = offset, extentOffset = offset;
}

abstract class TextInputFormatter {
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  );
}