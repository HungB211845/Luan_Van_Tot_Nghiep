import 'package:flutter/foundation.dart';
import '../models/notification_message.dart';
import '../services/notification_service.dart';
import '../services/notification_settings_service.dart';
import '../models/notification_preferences.dart';

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

  List<NotificationMessage> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _error;
  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await _settingsService.loadPreferences();
      final data = await _notificationService.fetchInventoryNotifications();
      final filtered = _applyPreferences(data, prefs);
      _notifications
        ..clear()
        ..addAll(filtered);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      final current = _notifications[i];
      if (!current.isRead) {
        _notifications[i] = current.copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
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

      if (message.severity == NotificationSeverity.info) {
        return prefs.notify60Days || prefs.notify90Days || prefs.notify30Days;
      }

      if (message.severity == NotificationSeverity.warning) {
        return prefs.notify30Days;
      }

      return true;
    }).toList();
  }
}
