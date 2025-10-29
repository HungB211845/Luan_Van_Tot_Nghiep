import 'package:flutter/material.dart';

/// Severity levels for notifications. Helps mapping to colors/icons.
enum NotificationSeverity { info, warning, danger }

/// Domain-specific topic to help UI decide navigation or grouping.
enum NotificationTopic {
  general,
  productLowStock,
  batchLowStock,
  batchExpiry,
}

/// Lightweight domain model representing a notification entry.
class NotificationMessage {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationSeverity severity;
  final NotificationTopic topic;
  final bool isRead;
  final int? expiryDays;
  final String? batchId;
  final String? productId;
  final String? batchNumber;

  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.severity = NotificationSeverity.info,
    this.topic = NotificationTopic.general,
    this.isRead = false,
    this.expiryDays,
    this.batchId,
    this.productId,
    this.batchNumber,
  });

  NotificationMessage copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    NotificationSeverity? severity,
    NotificationTopic? topic,
    bool? isRead,
    int? expiryDays,
    String? batchId,
    String? productId,
    String? batchNumber,
  }) {
    return NotificationMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      severity: severity ?? this.severity,
      topic: topic ?? this.topic,
      isRead: isRead ?? this.isRead,
      expiryDays: expiryDays ?? this.expiryDays,
      batchId: batchId ?? this.batchId,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
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
