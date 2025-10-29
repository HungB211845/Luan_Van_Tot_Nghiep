import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';

class NotificationSettingsService {
  static const String _prefsKey = 'notification_preferences';
  static const String _thresholdsKey = 'notification_low_stock_thresholds';
  static const String _readIdsKey = 'notification_read_ids';

  Future<NotificationPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const NotificationPreferences();
    }

    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(map);
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(preferences.toJson()),
    );
  }

  Future<Map<String, double>> loadLowStockThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_thresholdsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }

    try {
      final raw = jsonDecode(jsonString) as Map<String, dynamic>;
      final result = <String, double>{};
      raw.forEach((key, value) {
        final normalizedKey = key.toString().toUpperCase();
        if (value is num) {
          result[normalizedKey] = value.toDouble();
        } else {
          final parsed = double.tryParse(value.toString());
          if (parsed != null) {
            result[normalizedKey] = parsed;
          }
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLowStockThresholds(Map<String, double> thresholds) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = thresholds.map(
      (key, value) => MapEntry(key.toUpperCase(), value),
    );
    await prefs.setString(
      _thresholdsKey,
      jsonEncode(normalized),
    );
  }

  Future<LinkedHashSet<String>> loadReadNotificationIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_readIdsKey);
    if (stored == null) {
      return LinkedHashSet<String>();
    }
    return LinkedHashSet<String>.from(stored);
  }

  Future<void> saveReadNotificationIds(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readIdsKey,
      ids.take(500).toList(growable: false),
    );
  }
}
