import 'package:flutter/foundation.dart';
import '../models/quick_access_item.dart';
import '../services/quick_access_service.dart';

class QuickAccessProvider with ChangeNotifier {
  final QuickAccessService _service = QuickAccessService();

  List<QuickAccessItem> _visibleItems = [];
  List<QuickAccessItem> _hiddenItems = [];
  bool _hasChanges = false;
  bool _isLoading = false;

  List<QuickAccessItem> get visibleItems => _visibleItems;
  List<QuickAccessItem> get hiddenItems => _hiddenItems;
  bool get hasChanges => _hasChanges;
  bool get isLoading => _isLoading;

  /// Load configuration from service
  Future<void> loadConfiguration() async {
    _isLoading = true;
    notifyListeners();

    try {
      _visibleItems = await _service.getConfiguration();

      // Hidden items = all available items - visible items
      _hiddenItems = QuickAccessItem.availableItems
          .where((item) => !_visibleItems.contains(item))
          .toList();

      _hasChanges = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading quick access configuration: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add item from hidden to visible (max 6 items)
  void addItem(QuickAccessItem item) {
    if (_visibleItems.length >= 6) return; // Max 6 items
    if (!_hiddenItems.contains(item)) return;

    _hiddenItems.remove(item);
    _visibleItems.add(item);
    _hasChanges = true;
    notifyListeners();
  }

  /// Remove item from visible to hidden
  void removeItem(QuickAccessItem item) {
    if (!_visibleItems.contains(item)) return;

    _visibleItems.remove(item);
    _hiddenItems.add(item);
    _hasChanges = true;
    notifyListeners();
  }

  /// Reorder items in visible list
  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _visibleItems.removeAt(oldIndex);
    _visibleItems.insert(newIndex, item);
    _hasChanges = true;
    notifyListeners();
  }

  /// Save configuration to service
  Future<void> saveConfiguration() async {
    if (!_hasChanges) return;

    try {
      await _service.saveConfiguration(_visibleItems);
      _hasChanges = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving quick access configuration: $e');
      }
      rethrow;
    }
  }

  /// Reset to default configuration
  void resetToDefault() {
    _visibleItems = QuickAccessItem.defaultItems;
    _hiddenItems = QuickAccessItem.availableItems
        .where((item) => !_visibleItems.contains(item))
        .toList();
    _hasChanges = true;
    notifyListeners();
  }
}
