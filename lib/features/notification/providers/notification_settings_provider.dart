import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';
import '../services/notification_settings_service.dart';
import '../utils/inventory_threshold_helper.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider({NotificationSettingsService? service})
      : _service = service ?? NotificationSettingsService();

  final NotificationSettingsService _service;

  NotificationPreferences _preferences = const NotificationPreferences();
  bool _isLoading = false;
  Map<String, double> _lowStockThresholds =
      Map<String, double>.from(InventoryThresholdHelper.defaultThresholds);

  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  Map<String, double> get lowStockThresholds =>
      Map.unmodifiable(_lowStockThresholds);

  Future<void> loadPreferences() async {
    _isLoading = true;
    notifyListeners();
    try {
      _preferences = await _service.loadPreferences();
      final storedThresholds = await _service.loadLowStockThresholds();
      _lowStockThresholds = storedThresholds.isEmpty
          ? Map<String, double>.from(InventoryThresholdHelper.defaultThresholds)
          : _normalize(storedThresholds);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    _preferences = prefs;
    notifyListeners();
    await _service.savePreferences(prefs);
  }

  Future<void> togglePush(bool value) async {
    await updatePreferences(_preferences.copyWith(enablePushNotifications: value));
  }

  Future<void> toggleInventory(bool value) async {
    await updatePreferences(_preferences.copyWith(inventoryAlerts: value));
  }

  Future<void> togglePurchaseOrder(bool value) async {
    await updatePreferences(_preferences.copyWith(purchaseOrderAlerts: value));
  }

  Future<void> toggleDebt(bool value) async {
    await updatePreferences(_preferences.copyWith(debtAlerts: value));
  }

  Future<void> toggle30Days(bool value) async {
    await updatePreferences(_preferences.copyWith(notify30Days: value));
  }

  Future<void> toggle60Days(bool value) async {
    await updatePreferences(_preferences.copyWith(notify60Days: value));
  }

  Future<void> toggle90Days(bool value) async {
    await updatePreferences(_preferences.copyWith(notify90Days: value));
  }

  Future<void> updateLowStockThreshold(String category, double value) async {
    final double sanitizedValue = value < 0 ? 0 : value;
    final updated = Map<String, double>.from(_lowStockThresholds)
      ..[category.toUpperCase()] = sanitizedValue;
    _lowStockThresholds = updated;
    notifyListeners();
    await _service.saveLowStockThresholds(updated);
  }

  Map<String, double> _normalize(Map<String, double> source) {
    final result = <String, double>{};
    source.forEach((key, value) {
      result[key.toUpperCase()] = value;
    });
    return result;
  }
}
