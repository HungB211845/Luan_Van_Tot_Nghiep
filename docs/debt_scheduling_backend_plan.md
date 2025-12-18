# Backend Implementation Plan: Debt Scheduling & Reminders System

> **Implementation Phase**: Backend Infrastructure  
> **Estimated Timeline**: 2-3 weeks  
> **Dependencies**: Current Debt Management System (Complete)  
> **Status**: Planning Phase  

## 🎯 OVERVIEW

Kế hoạch này mở rộng hệ thống Debt Management hiện tại để support debt scheduling và payment reminders system với full backend infrastructure. Việc implementation này sẽ chuyển từ client-side storage (SharedPreferences) sang server-side management với Supabase RPC functions.

## 📊 CURRENT STATE vs TARGET STATE

### Current Implementation (Client-side)
- ✅ DebtReminder model với client validation
- ✅ DebtReminderService với SharedPreferences storage  
- ✅ Complete UI implementation
- ✅ Integration với existing debt management

### Target Implementation (Server-side)
- 🎯 Database tables cho reminder persistence
- 🎯 RPC functions cho CRUD operations
- 🎯 Multi-tenant security với RLS policies
- 🎯 Notification system integration
- 🎯 Advanced scheduling logic
- 🎯 Analytics và reporting capabilities

## 🗃️ DATABASE SCHEMA DESIGN

### 1. New Tables Required

#### `debt_reminders` Table
```sql
CREATE TABLE debt_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id),
  debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  
  -- Reminder Details
  title TEXT NOT NULL CHECK (length(title) >= 1 AND length(title) <= 200),
  description TEXT,
  scheduled_date DATE NOT NULL,
  scheduled_time TIME,
  
  -- Status Management
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'overdue')),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Notification Settings
  notification_enabled BOOLEAN NOT NULL DEFAULT true,
  notification_channels TEXT[] DEFAULT ARRAY['in_app'], -- ['in_app', 'email', 'sms']
  reminder_advance_days INTEGER DEFAULT 0 CHECK (reminder_advance_days >= 0),
  
  -- Recurrence Settings (Future Enhancement)
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurrence_pattern JSONB, -- {type: 'weekly', interval: 1, days: [1,3,5]}
  recurrence_end_date DATE,
  
  -- Tracking
  completed_at TIMESTAMP WITH TIME ZONE,
  completed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_completion CHECK (
    (status = 'completed' AND completed_at IS NOT NULL AND completed_by IS NOT NULL) OR
    (status != 'completed' AND completed_at IS NULL AND completed_by IS NULL)
  ),
  CONSTRAINT valid_recurrence CHECK (
    (is_recurring = false AND recurrence_pattern IS NULL) OR
    (is_recurring = true AND recurrence_pattern IS NOT NULL)
  )
);

-- Indexes cho performance
CREATE INDEX idx_debt_reminders_store_id ON debt_reminders(store_id);
CREATE INDEX idx_debt_reminders_debt_id ON debt_reminders(debt_id);
CREATE INDEX idx_debt_reminders_user_id ON debt_reminders(user_id);
CREATE INDEX idx_debt_reminders_scheduled_date ON debt_reminders(scheduled_date);
CREATE INDEX idx_debt_reminders_status ON debt_reminders(status) WHERE status IN ('active', 'overdue');
CREATE INDEX idx_debt_reminders_notification ON debt_reminders(notification_enabled, scheduled_date) WHERE status = 'active';
```

#### `reminder_notifications` Table (Notification Log)
```sql
CREATE TABLE reminder_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reminder_id UUID NOT NULL REFERENCES debt_reminders(id) ON DELETE CASCADE,
  
  -- Notification Details
  notification_type TEXT NOT NULL CHECK (notification_type IN ('advance', 'due_date', 'overdue')),
  channel TEXT NOT NULL CHECK (channel IN ('in_app', 'email', 'sms', 'push')),
  recipient_info JSONB NOT NULL, -- {email: '...', phone: '...', user_id: '...'}
  
  -- Status Tracking
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'read')),
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  read_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reminder_notifications_reminder_id ON reminder_notifications(reminder_id);
CREATE INDEX idx_reminder_notifications_status ON reminder_notifications(status);
CREATE INDEX idx_reminder_notifications_sent_at ON reminder_notifications(sent_at);
```

#### `reminder_templates` Table (Template System)
```sql
CREATE TABLE reminder_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL REFERENCES stores(id),
  
  -- Template Details
  name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 100),
  template_type TEXT NOT NULL CHECK (template_type IN ('payment', 'follow_up', 'final_notice')),
  
  -- Template Content
  title_template TEXT NOT NULL,
  message_template TEXT NOT NULL,
  
  -- Settings
  default_advance_days INTEGER DEFAULT 1 CHECK (default_advance_days >= 0),
  default_priority TEXT DEFAULT 'normal' CHECK (default_priority IN ('low', 'normal', 'high', 'urgent')),
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(store_id, template_type, is_default) DEFERRABLE
);

CREATE INDEX idx_reminder_templates_store_id ON reminder_templates(store_id);
CREATE INDEX idx_reminder_templates_type ON reminder_templates(template_type);
```

### 2. Trigger Functions

#### Auto-update Status Based on Scheduled Date
```sql
CREATE OR REPLACE FUNCTION update_reminder_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Update status to overdue for active reminders past scheduled date
  UPDATE debt_reminders 
  SET status = 'overdue', updated_at = NOW()
  WHERE status = 'active' 
    AND scheduled_date < CURRENT_DATE;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger daily status update
CREATE OR REPLACE FUNCTION schedule_reminder_status_update()
RETURNS void AS $$
BEGIN
  PERFORM cron.schedule('reminder-status-update', '0 1 * * *', 'SELECT update_reminder_status();');
END;
$$ LANGUAGE plpgsql;
```

## 🔐 SECURITY & RLS POLICIES

### Row Level Security Implementation
```sql
-- Enable RLS
ALTER TABLE debt_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminder_templates ENABLE ROW LEVEL SECURITY;

-- Store isolation policies
CREATE POLICY "Store access for debt_reminders" ON debt_reminders
  FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "Store access for reminder_notifications" ON reminder_notifications
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM debt_reminders dr 
      WHERE dr.id = reminder_notifications.reminder_id 
        AND dr.store_id = get_user_store_id()
    )
  );

CREATE POLICY "Store access for reminder_templates" ON reminder_templates
  FOR ALL USING (store_id = get_user_store_id());

-- User-specific policies cho personal reminders
CREATE POLICY "User access for own reminders" ON debt_reminders
  FOR ALL USING (user_id = auth.uid() AND store_id = get_user_store_id());
```

## 🔧 RPC FUNCTIONS IMPLEMENTATION

### 1. Core CRUD Operations

#### Create Reminder
```sql
CREATE OR REPLACE FUNCTION create_debt_reminder(
  p_debt_id UUID,
  p_title TEXT,
  p_description TEXT DEFAULT NULL,
  p_scheduled_date DATE,
  p_scheduled_time TIME DEFAULT NULL,
  p_priority TEXT DEFAULT 'normal',
  p_notification_enabled BOOLEAN DEFAULT true,
  p_notification_channels TEXT[] DEFAULT ARRAY['in_app'],
  p_reminder_advance_days INTEGER DEFAULT 0
) RETURNS UUID
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_reminder_id UUID;
  v_store_id UUID;
  v_debt_exists BOOLEAN;
BEGIN
  -- Get user store
  SELECT get_user_store_id() INTO v_store_id;
  
  -- Validate debt exists and belongs to store
  SELECT EXISTS (
    SELECT 1 FROM debts 
    WHERE id = p_debt_id 
      AND store_id = v_store_id 
      AND remaining_amount > 0
  ) INTO v_debt_exists;
  
  IF NOT v_debt_exists THEN
    RAISE EXCEPTION 'Debt not found or already paid off';
  END IF;
  
  -- Validate inputs
  IF p_scheduled_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'Scheduled date cannot be in the past';
  END IF;
  
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RAISE EXCEPTION 'Title is required';
  END IF;
  
  -- Insert reminder
  INSERT INTO debt_reminders (
    store_id, debt_id, user_id, title, description, 
    scheduled_date, scheduled_time, priority,
    notification_enabled, notification_channels, reminder_advance_days
  ) VALUES (
    v_store_id, p_debt_id, auth.uid(), p_title, p_description,
    p_scheduled_date, p_scheduled_time, p_priority,
    p_notification_enabled, p_notification_channels, p_reminder_advance_days
  ) RETURNING id INTO v_reminder_id;
  
  -- Schedule notifications if enabled
  IF p_notification_enabled THEN
    PERFORM schedule_reminder_notifications(v_reminder_id);
  END IF;
  
  RETURN v_reminder_id;
END;
$$;
```

#### Get Reminders for Debt
```sql
CREATE OR REPLACE FUNCTION get_debt_reminders(
  p_debt_id UUID,
  p_status_filter TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
) RETURNS SETOF debt_reminders
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  RETURN QUERY
  SELECT dr.* 
  FROM debt_reminders dr
  JOIN debts d ON d.id = dr.debt_id
  WHERE d.id = p_debt_id
    AND d.store_id = v_store_id
    AND (p_status_filter IS NULL OR dr.status = p_status_filter)
  ORDER BY dr.scheduled_date DESC, dr.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

#### Update Reminder Status
```sql
CREATE OR REPLACE FUNCTION update_reminder_status(
  p_reminder_id UUID,
  p_new_status TEXT,
  p_completion_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
  v_reminder_exists BOOLEAN;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  -- Validate reminder exists and user has access
  SELECT EXISTS (
    SELECT 1 FROM debt_reminders dr
    JOIN debts d ON d.id = dr.debt_id
    WHERE dr.id = p_reminder_id 
      AND d.store_id = v_store_id
      AND dr.user_id = auth.uid()
  ) INTO v_reminder_exists;
  
  IF NOT v_reminder_exists THEN
    RAISE EXCEPTION 'Reminder not found or access denied';
  END IF;
  
  -- Validate status transition
  IF p_new_status NOT IN ('active', 'completed', 'cancelled', 'overdue') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;
  
  -- Update reminder
  UPDATE debt_reminders 
  SET 
    status = p_new_status,
    completed_at = CASE WHEN p_new_status = 'completed' THEN NOW() ELSE NULL END,
    completed_by = CASE WHEN p_new_status = 'completed' THEN auth.uid() ELSE NULL END,
    description = CASE 
      WHEN p_completion_notes IS NOT NULL THEN 
        COALESCE(description || E'\n\n', '') || 'Completed: ' || p_completion_notes
      ELSE description 
    END,
    updated_at = NOW()
  WHERE id = p_reminder_id;
  
  RETURN FOUND;
END;
$$;
```

### 2. Advanced Query Functions

#### Get Dashboard Summary
```sql
CREATE OR REPLACE FUNCTION get_reminder_dashboard_summary(
  p_date_range_days INTEGER DEFAULT 7
) RETURNS JSONB
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
  v_result JSONB;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  WITH reminder_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE status = 'active' AND scheduled_date = CURRENT_DATE) as due_today,
      COUNT(*) FILTER (WHERE status = 'overdue') as overdue,
      COUNT(*) FILTER (WHERE status = 'active' AND scheduled_date BETWEEN CURRENT_DATE + 1 AND CURRENT_DATE + p_date_range_days) as upcoming,
      COUNT(*) FILTER (WHERE status = 'completed' AND DATE(completed_at) >= CURRENT_DATE - p_date_range_days) as completed_recent,
      COUNT(*) FILTER (WHERE status = 'active') as total_active
    FROM debt_reminders dr
    JOIN debts d ON d.id = dr.debt_id
    WHERE d.store_id = v_store_id
  )
  SELECT jsonb_build_object(
    'due_today', due_today,
    'overdue', overdue, 
    'upcoming', upcoming,
    'completed_recent', completed_recent,
    'total_active', total_active,
    'summary_date', CURRENT_DATE
  ) INTO v_result
  FROM reminder_stats;
  
  RETURN v_result;
END;
$$;
```

#### Search Reminders with Filters
```sql
CREATE OR REPLACE FUNCTION search_debt_reminders(
  p_search_term TEXT DEFAULT NULL,
  p_status_filter TEXT DEFAULT NULL,
  p_priority_filter TEXT DEFAULT NULL,
  p_date_from DATE DEFAULT NULL,
  p_date_to DATE DEFAULT NULL,
  p_customer_id UUID DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
) RETURNS SETOF debt_reminders
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  RETURN QUERY
  SELECT dr.*
  FROM debt_reminders dr
  JOIN debts d ON d.id = dr.debt_id
  JOIN customers c ON c.id = d.customer_id
  WHERE d.store_id = v_store_id
    AND (p_search_term IS NULL OR (
      dr.title ILIKE '%' || p_search_term || '%' OR
      dr.description ILIKE '%' || p_search_term || '%' OR
      c.name ILIKE '%' || p_search_term || '%'
    ))
    AND (p_status_filter IS NULL OR dr.status = p_status_filter)
    AND (p_priority_filter IS NULL OR dr.priority = p_priority_filter)
    AND (p_date_from IS NULL OR dr.scheduled_date >= p_date_from)
    AND (p_date_to IS NULL OR dr.scheduled_date <= p_date_to)
    AND (p_customer_id IS NULL OR d.customer_id = p_customer_id)
  ORDER BY 
    CASE dr.priority
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END,
    dr.scheduled_date ASC,
    dr.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;
```

## 🔔 NOTIFICATION SYSTEM INTEGRATION

### 1. Notification Scheduling Function
```sql
CREATE OR REPLACE FUNCTION schedule_reminder_notifications(
  p_reminder_id UUID
) RETURNS BOOLEAN
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_reminder debt_reminders;
  v_customer customers;
  v_debt debts;
  v_channel TEXT;
BEGIN
  -- Get reminder details với customer info
  SELECT dr.*, c.*, d.* 
  INTO v_reminder, v_customer, v_debt
  FROM debt_reminders dr
  JOIN debts d ON d.id = dr.debt_id
  JOIN customers c ON c.id = d.customer_id
  WHERE dr.id = p_reminder_id;
  
  -- Schedule notifications cho each enabled channel
  FOREACH v_channel IN ARRAY v_reminder.notification_channels
  LOOP
    -- Advance notification (if advance days > 0)
    IF v_reminder.reminder_advance_days > 0 THEN
      INSERT INTO reminder_notifications (
        reminder_id, notification_type, channel, recipient_info, status
      ) VALUES (
        p_reminder_id, 
        'advance', 
        v_channel,
        jsonb_build_object(
          'customer_name', v_customer.name,
          'customer_phone', v_customer.phone,
          'customer_email', v_customer.email,
          'debt_amount', v_debt.remaining_amount,
          'scheduled_date', v_reminder.scheduled_date,
          'advance_days', v_reminder.reminder_advance_days
        ),
        'pending'
      );
    END IF;
    
    -- Due date notification
    INSERT INTO reminder_notifications (
      reminder_id, notification_type, channel, recipient_info, status
    ) VALUES (
      p_reminder_id,
      'due_date',
      v_channel, 
      jsonb_build_object(
        'customer_name', v_customer.name,
        'customer_phone', v_customer.phone,
        'customer_email', v_customer.email,
        'debt_amount', v_debt.remaining_amount,
        'scheduled_date', v_reminder.scheduled_date
      ),
      'pending'
    );
  END LOOP;
  
  RETURN TRUE;
END;
$$;
```

### 2. Notification Processing Function
```sql
CREATE OR REPLACE FUNCTION process_pending_notifications()
RETURNS INTEGER
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_notification_count INTEGER := 0;
  v_notification reminder_notifications;
BEGIN
  -- Process notifications that are due
  FOR v_notification IN 
    SELECT rn.* 
    FROM reminder_notifications rn
    JOIN debt_reminders dr ON dr.id = rn.reminder_id
    WHERE rn.status = 'pending'
      AND (
        (rn.notification_type = 'advance' AND 
         dr.scheduled_date - INTERVAL '1 day' * dr.reminder_advance_days <= CURRENT_DATE) OR
        (rn.notification_type = 'due_date' AND 
         dr.scheduled_date <= CURRENT_DATE) OR
        (rn.notification_type = 'overdue' AND 
         dr.scheduled_date < CURRENT_DATE)
      )
  LOOP
    -- Update notification status
    UPDATE reminder_notifications 
    SET status = 'sent', sent_at = NOW()
    WHERE id = v_notification.id;
    
    -- Here you would integrate với actual notification service
    -- (Firebase, Email service, SMS service, etc.)
    -- PERFORM send_notification(v_notification);
    
    v_notification_count := v_notification_count + 1;
  END LOOP;
  
  RETURN v_notification_count;
END;
$$;
```

## 📱 CLIENT-SIDE INTEGRATION UPDATES

### 1. Updated Service Layer
```dart
// lib/features/debt/services/debt_reminder_service.dart - SERVER VERSION
class DebtReminderService extends BaseService {
  /// Create reminder using RPC
  Future<String> createReminder({
    required String debtId,
    required String title,
    String? description,
    required DateTime scheduledDate,
    TimeOfDay? scheduledTime,
    String priority = 'normal',
    bool notificationEnabled = true,
    List<String> notificationChannels = const ['in_app'],
    int reminderAdvanceDays = 0,
  }) async {
    try {
      final response = await supabaseClient.rpc('create_debt_reminder', {
        'p_debt_id': debtId,
        'p_title': title,
        'p_description': description,
        'p_scheduled_date': scheduledDate.toIso8601String().split('T')[0],
        'p_scheduled_time': scheduledTime?.format(context) ?? '',
        'p_priority': priority,
        'p_notification_enabled': notificationEnabled,
        'p_notification_channels': notificationChannels,
        'p_reminder_advance_days': reminderAdvanceDays,
      });

      return response as String;
    } catch (e) {
      throw Exception('Failed to create reminder: $e');
    }
  }

  /// Get reminders for debt using RPC
  Future<List<DebtReminder>> getRemindersForDebt(
    String debtId, {
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await supabaseClient.rpc('get_debt_reminders', {
        'p_debt_id': debtId,
        'p_status_filter': statusFilter,
        'p_limit': limit,
        'p_offset': offset,
      });

      return (response as List)
          .map((item) => DebtReminder.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to load reminders: $e');
    }
  }

  /// Update reminder status
  Future<bool> updateReminderStatus(
    String reminderId,
    String newStatus, {
    String? completionNotes,
  }) async {
    try {
      final response = await supabaseClient.rpc('update_reminder_status', {
        'p_reminder_id': reminderId,
        'p_new_status': newStatus,
        'p_completion_notes': completionNotes,
      });

      return response as bool;
    } catch (e) {
      throw Exception('Failed to update reminder: $e');
    }
  }

  /// Get dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary({
    int dateRangeDays = 7,
  }) async {
    try {
      final response = await supabaseClient.rpc('get_reminder_dashboard_summary', {
        'p_date_range_days': dateRangeDays,
      });

      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  /// Search reminders với advanced filters
  Future<List<DebtReminder>> searchReminders({
    String? searchTerm,
    String? statusFilter,
    String? priorityFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? customerId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await supabaseClient.rpc('search_debt_reminders', {
        'p_search_term': searchTerm,
        'p_status_filter': statusFilter,
        'p_priority_filter': priorityFilter,
        'p_date_from': dateFrom?.toIso8601String().split('T')[0],
        'p_date_to': dateTo?.toIso8601String().split('T')[0],
        'p_customer_id': customerId,
        'p_limit': limit,
        'p_offset': offset,
      });

      return (response as List)
          .map((item) => DebtReminder.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to search reminders: $e');
    }
  }
}
```

### 2. Enhanced Model với Server Fields
```dart
// Enhanced DebtReminder model
class DebtReminder {
  final String id;
  final String storeId;
  final String debtId;
  final String userId;
  final String title;
  final String? description;
  final DateTime scheduledDate;
  final TimeOfDay? scheduledTime;
  final String status; // active, completed, cancelled, overdue
  final String priority; // low, normal, high, urgent
  final bool notificationEnabled;
  final List<String> notificationChannels;
  final int reminderAdvanceDays;
  final bool isRecurring;
  final Map<String, dynamic>? recurrencePattern;
  final DateTime? recurrenceEndDate;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enhanced computed properties
  bool get isOverdue => status == 'overdue' || 
    (status == 'active' && scheduledDate.isBefore(DateTime.now()));
    
  bool get isDueToday {
    if (status != 'active') return false;
    final today = DateTime.now();
    return scheduledDate.year == today.year &&
           scheduledDate.month == today.month &&
           scheduledDate.day == today.day;
  }

  bool get isDueSoon {
    if (status != 'active' || isOverdue || isDueToday) return false;
    final daysDifference = scheduledDate.difference(DateTime.now()).inDays;
    return daysDifference <= 3; // Due within 3 days
  }

  Color get priorityColor {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'normal': return Colors.blue;
      case 'low': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData get priorityIcon {
    switch (priority) {
      case 'urgent': return Icons.priority_high;
      case 'high': return Icons.keyboard_arrow_up;
      case 'normal': return Icons.remove;
      case 'low': return Icons.keyboard_arrow_down;
      default: return Icons.remove;
    }
  }
}
```

## 📊 ANALYTICS & REPORTING FEATURES

### 1. Reminder Effectiveness Metrics
```sql
CREATE OR REPLACE FUNCTION get_reminder_effectiveness_report(
  p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
  p_date_to DATE DEFAULT CURRENT_DATE
) RETURNS JSONB
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
  v_result JSONB;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  WITH reminder_metrics AS (
    SELECT
      COUNT(*) as total_reminders,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_reminders,
      COUNT(*) FILTER (WHERE status = 'overdue') as overdue_reminders,
      AVG(EXTRACT(DAY FROM (completed_at - scheduled_date))) FILTER (WHERE status = 'completed') as avg_completion_delay,
      COUNT(DISTINCT d.customer_id) as customers_with_reminders,
      SUM(d.remaining_amount) FILTER (WHERE dr.status = 'completed') as debt_resolved_amount,
      COUNT(*) FILTER (WHERE dr.priority = 'urgent') as urgent_reminders,
      COUNT(*) FILTER (WHERE dr.priority = 'high') as high_priority_reminders
    FROM debt_reminders dr
    JOIN debts d ON d.id = dr.debt_id
    WHERE d.store_id = v_store_id
      AND dr.created_at::date BETWEEN p_date_from AND p_date_to
  ),
  notification_metrics AS (
    SELECT
      COUNT(*) as total_notifications,
      COUNT(*) FILTER (WHERE status = 'sent') as sent_notifications,
      COUNT(*) FILTER (WHERE status = 'delivered') as delivered_notifications,
      COUNT(*) FILTER (WHERE status = 'read') as read_notifications,
      COUNT(*) FILTER (WHERE status = 'failed') as failed_notifications
    FROM reminder_notifications rn
    JOIN debt_reminders dr ON dr.id = rn.reminder_id
    JOIN debts d ON d.id = dr.debt_id
    WHERE d.store_id = v_store_id
      AND rn.created_at::date BETWEEN p_date_from AND p_date_to
  )
  SELECT jsonb_build_object(
    'period', jsonb_build_object('from', p_date_from, 'to', p_date_to),
    'reminder_metrics', to_jsonb(rm.*),
    'notification_metrics', to_jsonb(nm.*),
    'effectiveness_percentage', 
      CASE WHEN rm.total_reminders > 0 
        THEN ROUND((rm.completed_reminders::decimal / rm.total_reminders::decimal) * 100, 2)
        ELSE 0 
      END,
    'notification_success_rate',
      CASE WHEN nm.total_notifications > 0
        THEN ROUND((nm.delivered_notifications::decimal / nm.total_notifications::decimal) * 100, 2)
        ELSE 0
      END
  ) INTO v_result
  FROM reminder_metrics rm, notification_metrics nm;
  
  RETURN v_result;
END;
$$;
```

### 2. Customer Payment Behavior Analysis
```sql
CREATE OR REPLACE FUNCTION analyze_customer_reminder_behavior(
  p_customer_id UUID,
  p_months_back INTEGER DEFAULT 6
) RETURNS JSONB
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_store_id UUID;
  v_result JSONB;
BEGIN
  SELECT get_user_store_id() INTO v_store_id;
  
  WITH customer_behavior AS (
    SELECT
      COUNT(*) as total_reminders,
      COUNT(*) FILTER (WHERE status = 'completed') as completed_on_time,
      COUNT(*) FILTER (WHERE status = 'overdue') as missed_reminders,
      AVG(EXTRACT(DAY FROM (completed_at - scheduled_date))) FILTER (WHERE status = 'completed') as avg_response_days,
      MIN(dr.created_at) as first_reminder_date,
      MAX(dr.created_at) as last_reminder_date,
      COUNT(DISTINCT dr.debt_id) as debts_with_reminders,
      SUM(d.remaining_amount) FILTER (WHERE dr.status = 'completed') as total_paid_after_reminder
    FROM debt_reminders dr
    JOIN debts d ON d.id = dr.debt_id
    WHERE d.store_id = v_store_id
      AND d.customer_id = p_customer_id
      AND dr.created_at >= CURRENT_DATE - INTERVAL '1 month' * p_months_back
  ),
  payment_patterns AS (
    SELECT
      COUNT(*) as total_payments,
      AVG(dp.amount) as avg_payment_amount,
      COUNT(*) FILTER (WHERE dp.payment_date <= dr.scheduled_date) as on_time_payments,
      COUNT(*) FILTER (WHERE dp.payment_date > dr.scheduled_date) as late_payments
    FROM debt_payments dp
    JOIN debts d ON d.id = dp.debt_id
    LEFT JOIN debt_reminders dr ON dr.debt_id = d.id
    WHERE d.store_id = v_store_id
      AND d.customer_id = p_customer_id
      AND dp.created_at >= CURRENT_DATE - INTERVAL '1 month' * p_months_back
  )
  SELECT jsonb_build_object(
    'customer_id', p_customer_id,
    'analysis_period_months', p_months_back,
    'reminder_behavior', to_jsonb(cb.*),
    'payment_patterns', to_jsonb(pp.*),
    'reliability_score', 
      CASE WHEN cb.total_reminders > 0
        THEN ROUND(((cb.completed_on_time::decimal / cb.total_reminders::decimal) * 100), 1)
        ELSE NULL
      END,
    'recommended_reminder_frequency',
      CASE 
        WHEN cb.avg_response_days <= 1 THEN 'low_frequency'
        WHEN cb.avg_response_days <= 3 THEN 'normal_frequency'
        WHEN cb.avg_response_days <= 7 THEN 'high_frequency'
        ELSE 'urgent_follow_up'
      END
  ) INTO v_result
  FROM customer_behavior cb, payment_patterns pp;
  
  RETURN v_result;
END;
$$;
```

## 🚀 DEPLOYMENT ROADMAP

### Phase 1: Core Infrastructure (Week 1)
- [ ] Database tables creation và RLS policies
- [ ] Basic CRUD RPC functions implementation
- [ ] Service layer updates cho server integration
- [ ] Unit testing cho RPC functions

### Phase 2: Advanced Features (Week 2)  
- [ ] Notification system implementation
- [ ] Template system cho reminder messages
- [ ] Dashboard analytics RPC functions
- [ ] Search và filtering capabilities
- [ ] Integration testing

### Phase 3: UI Updates & Migration (Week 3)
- [ ] Update existing UI to use server-side data
- [ ] Migration tool from SharedPreferences to server
- [ ] Advanced reminder management screens
- [ ] Analytics dashboard implementation
- [ ] End-to-end testing

### Phase 4: Production Deployment
- [ ] Performance optimization và indexing
- [ ] Security audit và penetration testing
- [ ] Documentation updates  
- [ ] Production deployment với rollback plan
- [ ] User training và adoption tracking

## 🔍 TESTING STRATEGY

### Database Testing
```sql
-- Test RPC function với edge cases
SELECT create_debt_reminder(
  'invalid-debt-id', 
  'Test Reminder', 
  NULL, 
  CURRENT_DATE + 1
); -- Should raise exception

-- Test store isolation
SET LOCAL "request.user_id" = 'other-store-user-id';
SELECT get_debt_reminders('debt-id-from-different-store'); -- Should return empty
```

### Integration Testing
- Test client-side service calls với mock server responses
- Validate RLS policies với multiple store scenarios
- Performance testing với large datasets (1000+ reminders)
- Notification delivery testing với different channels

### Migration Testing
- Test migration từ SharedPreferences data sang server
- Validate data integrity sau migration
- Test rollback scenarios

## 📈 SUCCESS METRICS

### Technical Metrics
- **Response Time**: RPC functions < 200ms average
- **Data Consistency**: 100% data integrity across operations  
- **Security**: Zero RLS policy violations
- **Scalability**: Support 10,000+ reminders per store

### Business Metrics
- **Adoption Rate**: % of users creating reminders
- **Effectiveness**: % of reminders leading to payments
- **User Satisfaction**: User feedback scores
- **Debt Collection**: Improvement trong collection rates

## 🎯 FUTURE ENHANCEMENTS

### Advanced Features
1. **Machine Learning**: Predict optimal reminder timing based on customer behavior
2. **Integration APIs**: Connect với external calendar systems (Google Calendar, Outlook)
3. **Advanced Notifications**: WhatsApp, Telegram integration
4. **Workflow Automation**: Automatic reminder creation based on debt age
5. **Mobile App**: Push notifications cho mobile apps
6. **Voice Reminders**: Text-to-speech phone call reminders
7. **Dashboard Widgets**: Customizable dashboard với reminder metrics

### Scalability Improvements
- **Caching Layer**: Redis caching cho frequent queries
- **Background Jobs**: Queue-based notification processing
- **API Rate Limiting**: Prevent notification spam
- **Multi-Language**: I18n support cho reminder messages

This comprehensive plan ensures that the debt scheduling system scales from a simple client-side feature to a robust, enterprise-grade backend system với full notification capabilities và advanced analytics. The phased approach allows for gradual implementation while maintaining system stability và user experience.