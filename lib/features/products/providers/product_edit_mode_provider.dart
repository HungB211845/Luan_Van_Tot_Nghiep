import 'package:flutter/material.dart';

/// Provider to manage product list edit mode state globally
/// Used to hide/show bottom navigation when entering edit mode
class ProductEditModeProvider extends ChangeNotifier {
  bool _isEditMode = false;
  final Set<String> _selectedProductIds = {};

  bool get isEditMode => _isEditMode;
  Set<String> get selectedProductIds => _selectedProductIds;
  int get selectedCount => _selectedProductIds.length;
  bool get hasSelection => _selectedProductIds.isNotEmpty;

  void enterEditMode() {
    _isEditMode = true;
    _selectedProductIds.clear();
    notifyListeners();
  }

  void exitEditMode() {
    _isEditMode = false;
    _selectedProductIds.clear();
    notifyListeners();
  }

  void toggleSelection(String productId) {
    if (_selectedProductIds.contains(productId)) {
      _selectedProductIds.remove(productId);
    } else {
      _selectedProductIds.add(productId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedProductIds.clear();
    notifyListeners();
  }

  bool isSelected(String productId) {
    return _selectedProductIds.contains(productId);
  }
}