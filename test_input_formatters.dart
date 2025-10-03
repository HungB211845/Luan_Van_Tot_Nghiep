// Test file for input formatters
// Run: dart test_input_formatters.dart

import 'lib/shared/utils/input_formatters.dart';

void main() {
  print('🧪 Testing Input Formatters...\n');

  // Test CurrencyInputFormatter
  testCurrencyFormatter();
  
  // Test QuantityInputFormatter  
  testQuantityFormatter();
  
  // Test InputFormatterHelper
  testInputFormatterHelper();
  
  print('\n✅ All tests completed!');
}

void testCurrencyFormatter() {
  print('📱 Testing CurrencyInputFormatter:');
  
  final formatter = CurrencyInputFormatter();
  
  // Test cases
  final testCases = [
    {'input': '1000', 'expected': '1.000'},
    {'input': '25000', 'expected': '25.000'},
    {'input': '1234567', 'expected': '1.234.567'},
    {'input': '0', 'expected': '0'},
    {'input': '', 'expected': ''},
    {'input': 'abc', 'expected': ''}, // Should be cleaned
  ];
  
  for (final testCase in testCases) {
    final input = testCase['input'] as String;
    final expected = testCase['expected'] as String;
    
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: input),
    );
    
    final success = result.text == expected;
    print('  ${success ? "✅" : "❌"} Input: "$input" → Output: "${result.text}" (Expected: "$expected")');
  }
  print('');
}

void testQuantityFormatter() {
  print('🔢 Testing QuantityInputFormatter:');
  
  final formatter = QuantityInputFormatter();
  
  final testCases = [
    {'input': '100', 'expected': '100'},
    {'input': '1000', 'expected': '1.000'},
    {'input': '50000', 'expected': '50.000'},
    {'input': '999999', 'expected': '999.999'},
  ];
  
  for (final testCase in testCases) {
    final input = testCase['input'] as String;
    final expected = testCase['expected'] as String;
    
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: input),
    );
    
    final success = result.text == expected;
    print('  ${success ? "✅" : "❌"} Input: "$input" → Output: "${result.text}" (Expected: "$expected")');
  }
  print('');
}

void testInputFormatterHelper() {
  print('🔧 Testing InputFormatterHelper:');
  
  final testCases = [
    {'input': '1.000', 'expected': 1000.0},
    {'input': '25.000', 'expected': 25000.0},
    {'input': '1.234.567', 'expected': 1234567.0},
    {'input': '2.500,5', 'expected': 2500.5},
    {'input': '100', 'expected': 100.0},
    {'input': '', 'expected': null},
  ];
  
  for (final testCase in testCases) {
    final input = testCase['input'] as String;
    final expected = testCase['expected'] as double?;
    
    final result = InputFormatterHelper.extractNumber(input);
    
    final success = result == expected;
    print('  ${success ? "✅" : "❌"} Extract from: "$input" → $result (Expected: $expected)');
  }
  
  // Test integer extraction
  print('\n  Testing integer extraction:');
  final intTestCases = [
    {'input': '1.000', 'expected': 1000},
    {'input': '25.000', 'expected': 25000},
    {'input': '500', 'expected': 500},
  ];
  
  for (final testCase in intTestCases) {
    final input = testCase['input'] as String;
    final expected = testCase['expected'] as int?;
    
    final result = InputFormatterHelper.extractInteger(input);
    
    final success = result == expected;
    print('  ${success ? "✅" : "❌"} Extract int from: "$input" → $result (Expected: $expected)');
  }
  print('');
}

// Mock TextEditingValue for testing
class TextEditingValue {
  final String text;
  final TextSelection selection;
  
  const TextEditingValue({
    required this.text,
    this.selection = const TextSelection.collapsed(offset: 0),
  });
  
  static const empty = TextEditingValue(text: '');
}

// Mock TextSelection for testing  
class TextSelection {
  final int baseOffset;
  final int extentOffset;
  
  const TextSelection.collapsed({required int offset}) 
    : baseOffset = offset, extentOffset = offset;
}