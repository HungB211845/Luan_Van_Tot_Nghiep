/// Export file for AgriPOS transitions system
/// Provides easy access to all transition-related classes and utilities

import 'package:flutter/material.dart';

// Core Cupertino components với AgriPOS theming
export 'cupertino_page_scaffold.dart';
export 'cupertino_page_route.dart';

// Legacy iOS transition (kept for backward compatibility)
export 'ios_page_route.dart';

/// Quick access to common AgriPOS theme colors
class AgriColors {
  static const primaryGreen = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFF4CAF50);
  static const darkGreen = Color(0xFF1B5E20);
  static const backgroundGray = Color(0xFFF5F5F5);

  // Accent colors cho categories
  static const fertilizer = Color(0xFF4CAF50);
  static const pesticide = Color(0xFFFF9800);
  static const seed = Color(0xFF8D6E63);
}