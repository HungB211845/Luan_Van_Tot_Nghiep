/// Model for debt payment reminders - client-side only
class DebtReminder {
  final String id;
  final String debtId;
  final DateTime scheduledDate;
  final String title;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;

  const DebtReminder({
    required this.id,
    required this.debtId,
    required this.scheduledDate,
    required this.title,
    this.notes,
    required this.isCompleted,
    required this.createdAt,
  });

  factory DebtReminder.fromJson(Map<String, dynamic> json) {
    return DebtReminder(
      id: json['id'] as String,
      debtId: json['debt_id'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      title: json['title'] as String,
      notes: json['notes'] as String?,
      isCompleted: json['is_completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debt_id': debtId,
      'scheduled_date': scheduledDate.toIso8601String(),
      'title': title,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DebtReminder copyWith({
    String? id,
    String? debtId,
    DateTime? scheduledDate,
    String? title,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return DebtReminder(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isOverdue {
    if (isCompleted) return false;
    return scheduledDate.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (isCompleted) return false;
    final today = DateTime.now();
    final scheduleDate = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
    );
    final currentDate = DateTime(today.year, today.month, today.day);
    return scheduleDate.isAtSameMomentAs(currentDate);
  }
}