import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../../products/models/product.dart';
import '../../products/models/product_unit.dart';
import '../models/notification_message.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../models/notification_preferences.dart';
import '../utils/inventory_threshold_helper.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  final NotificationSettingsService _settingsService;

  NotificationProvider({
    NotificationService? notificationService,
    NotificationSettingsService? settingsService,
  })  : _notificationService =
            notificationService ?? NotificationService(),
        _settingsService = settingsService ?? NotificationSettingsService();

  final List<NotificationMessage> _notifications = [];
  bool _isLoading = false;
  String? _error;
  NotificationPreferences _preferences = const NotificationPreferences();
  Map<String, double> _lowStockThresholds =
      Map<String, double>.from(InventoryThresholdHelper.defaultThresholds);
  final LinkedHashSet<String> _readIds = LinkedHashSet<String>();
  bool _readCacheLoaded = false;

  List<NotificationMessage> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;
  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;
  NotificationPreferences get preferences => _preferences;
  Map<String, double> get lowStockThresholds =>
      Map.unmodifiable(_lowStockThresholds);

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadReadCache();
      final prefs = await _settingsService.loadPreferences();
      final storedThresholds = await _settingsService.loadLowStockThresholds();
      _lowStockThresholds = storedThresholds.isEmpty
          ? Map<String, double>.from(
              InventoryThresholdHelper.defaultThresholds,
            )
          : _normalizeThresholds(storedThresholds);
      _preferences = prefs;
      final data = await _notificationService.fetchInventoryNotifications(
        preferences: prefs,
        thresholds: _lowStockThresholds,
      );
      final filtered = _applyPreferences(data, prefs);

      final merged = <NotificationMessage>[];
      final seen = <String>{};
      for (final message in filtered) {
        if (!seen.add(message.id)) {
          continue;
        }
        final isRead = _readIds.contains(message.id) || message.isRead;
        if (isRead) {
          _readIds.add(message.id);
          merged.add(message.copyWith(isRead: true));
        } else {
          merged.add(message);
        }
      }

      // prune read cache to avoid unbounded growth
      while (_readIds.length > 500) {
        _readIds.remove(_readIds.first);
      }
      await _persistReadCache();

      _notifications
        ..clear()
        ..addAll(merged);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (_notifications.isEmpty) return;
    for (var i = 0; i < _notifications.length; i++) {
      final current = _notifications[i];
      if (!current.isRead) {
        _notifications[i] = current.copyWith(isRead: true);
      }
      _readIds.add(_notifications[i].id);
    }
    unawaited(_persistReadCache());
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: true);
      _readIds.add(id);
      unawaited(_persistReadCache());
      notifyListeners();
    }
  }

  void markAsUnread(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && _notifications[index].isRead) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: false);
      _readIds.remove(id);
      unawaited(_persistReadCache());
      notifyListeners();
    }
  }

  void updateThresholds(Map<String, double> thresholds) {
    _lowStockThresholds = thresholds.isEmpty
        ? Map<String, double>.from(InventoryThresholdHelper.defaultThresholds)
        : _normalizeThresholds(thresholds);
    notifyListeners();
  }

  double resolveLowStockThreshold({
    required Product product,
    required List<ProductUnit> units,
  }) {
    return InventoryThresholdHelper.resolveLowStockThreshold(
      minStockLevel: product.minStockLevel.toDouble(),
      units: units,
      thresholds: _lowStockThresholds,
      category: product.category,
    );
  }

  Map<String, double> _normalizeThresholds(Map<String, double> input) {
    final normalized = <String, double>{};
    input.forEach((key, value) {
      normalized[key.toUpperCase()] = value;
    });
    return normalized;
  }

  Future<void> _loadReadCache() async {
    if (_readCacheLoaded) return;
    final stored = await _settingsService.loadReadNotificationIds();
    _readIds
      ..clear()
      ..addAll(stored);
    _readCacheLoaded = true;
  }

  Future<void> _persistReadCache() async {
    await _settingsService.saveReadNotificationIds(_readIds);
  }

  List<NotificationMessage> _applyPreferences(
    List<NotificationMessage> messages,
    NotificationPreferences prefs,
  ) {
    if (!prefs.inventoryAlerts) {
      return [];
    }

    return messages.where((message) {
      if (message.severity == NotificationSeverity.danger) {
        return true; // luôn cảnh báo nếu đã hết hạn
      }

      if (message.expiryDays != null) {
        final days = message.expiryDays!;
        if (days <= 30) {
          return prefs.notify30Days;
        } else if (days <= 60) {
          return prefs.notify60Days;
        } else if (days <= 90) {
          return prefs.notify90Days;
        }
      }

      return true;
    }).toList();
  }
}
