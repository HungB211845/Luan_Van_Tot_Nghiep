import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_preferences.dart';

class NotificationSettingsService {
  static const String _prefsKey = 'notification_preferences';

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
}
