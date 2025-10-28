import 'package:flutter/material.dart';

/// Severity levels for notifications. Helps mapping to colors/icons.
enum NotificationSeverity { info, warning, danger }

/// Lightweight domain model representing a notification entry.
class NotificationMessage {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationSeverity severity;
  final bool isRead;
  final int? expiryDays;

  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.severity = NotificationSeverity.info,
    this.isRead = false,
    this.expiryDays,
  });

  NotificationMessage copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    NotificationSeverity? severity,
    bool? isRead,
    int? expiryDays,
  }) {
    return NotificationMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      severity: severity ?? this.severity,
      isRead: isRead ?? this.isRead,
      expiryDays: expiryDays ?? this.expiryDays,
    );
  }

  Color severityColor(BuildContext context) {
    switch (severity) {
      case NotificationSeverity.warning:
        return Colors.orange[600] ?? Colors.orange;
      case NotificationSeverity.danger:
        return Colors.red[600] ?? Colors.red;
      case NotificationSeverity.info:
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
