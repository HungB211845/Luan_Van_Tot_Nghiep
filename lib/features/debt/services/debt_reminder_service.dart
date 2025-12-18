import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/debt_reminder.dart';

/// Service for managing debt payment reminders - client-side storage only
class DebtReminderService {
  static const String _reminderKey = 'debt_reminders';

  /// Get all reminders for a specific debt
  Future<List<DebtReminder>> getRemindersForDebt(String debtId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      if (reminderData == null) return [];
      
      final List<dynamic> reminderList = json.decode(reminderData);
      final allReminders = reminderList
          .map((item) => DebtReminder.fromJson(item))
          .toList();
      
      return allReminders.where((reminder) => reminder.debtId == debtId).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a new reminder
  Future<bool> addReminder(DebtReminder reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      List<DebtReminder> allReminders = [];
      if (reminderData != null) {
        final List<dynamic> reminderList = json.decode(reminderData);
        allReminders = reminderList
            .map((item) => DebtReminder.fromJson(item))
            .toList();
      }
      
      allReminders.add(reminder);
      
      final updatedData = json.encode(
        allReminders.map((r) => r.toJson()).toList(),
      );
      
      return await prefs.setString(_reminderKey, updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Update an existing reminder
  Future<bool> updateReminder(DebtReminder updatedReminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      if (reminderData == null) return false;
      
      final List<dynamic> reminderList = json.decode(reminderData);
      final allReminders = reminderList
          .map((item) => DebtReminder.fromJson(item))
          .toList();
      
      final index = allReminders.indexWhere((r) => r.id == updatedReminder.id);
      if (index == -1) return false;
      
      allReminders[index] = updatedReminder;
      
      final updatedData = json.encode(
        allReminders.map((r) => r.toJson()).toList(),
      );
      
      return await prefs.setString(_reminderKey, updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Delete a reminder
  Future<bool> deleteReminder(String reminderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      if (reminderData == null) return false;
      
      final List<dynamic> reminderList = json.decode(reminderData);
      final allReminders = reminderList
          .map((item) => DebtReminder.fromJson(item))
          .toList();
      
      allReminders.removeWhere((r) => r.id == reminderId);
      
      final updatedData = json.encode(
        allReminders.map((r) => r.toJson()).toList(),
      );
      
      return await prefs.setString(_reminderKey, updatedData);
    } catch (e) {
      return false;
    }
  }

  /// Get all reminders across all debts
  Future<List<DebtReminder>> getAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      if (reminderData == null) return [];
      
      final List<dynamic> reminderList = json.decode(reminderData);
      return reminderList
          .map((item) => DebtReminder.fromJson(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get overdue reminders
  Future<List<DebtReminder>> getOverdueReminders() async {
    try {
      final allReminders = await getAllReminders();
      return allReminders.where((r) => r.isOverdue).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get reminders due today
  Future<List<DebtReminder>> getTodayReminders() async {
    try {
      final allReminders = await getAllReminders();
      return allReminders.where((r) => r.isDueToday).toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark reminder as completed
  Future<bool> markReminderComplete(String reminderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderData = prefs.getString(_reminderKey);
      
      if (reminderData == null) return false;
      
      final List<dynamic> reminderList = json.decode(reminderData);
      final allReminders = reminderList
          .map((item) => DebtReminder.fromJson(item))
          .toList();
      
      final index = allReminders.indexWhere((r) => r.id == reminderId);
      if (index == -1) return false;
      
      allReminders[index] = allReminders[index].copyWith(isCompleted: true);
      
      final updatedData = json.encode(
        allReminders.map((r) => r.toJson()).toList(),
      );
      
      return await prefs.setString(_reminderKey, updatedData);
    } catch (e) {
      return false;
    }
  }
}