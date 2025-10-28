import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';
import '../services/notification_settings_service.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider({NotificationSettingsService? service})
      : _service = service ?? NotificationSettingsService();

  final NotificationSettingsService _service;

  NotificationPreferences _preferences = const NotificationPreferences();
  bool _isLoading = false;

  NotificationPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;

  Future<void> loadPreferences() async {
    _isLoading = true;
    notifyListeners();
    try {
      _preferences = await _service.loadPreferences();
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
}
