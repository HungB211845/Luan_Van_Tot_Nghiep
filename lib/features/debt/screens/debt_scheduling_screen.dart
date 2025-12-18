import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/utils/formatter.dart';
import '../models/debt.dart';
import '../models/debt_reminder.dart';
import '../services/debt_reminder_service.dart';

/// Screen for managing debt payment reminders and status
class DebtSchedulingScreen extends StatefulWidget {
  final Debt debt;

  const DebtSchedulingScreen({
    super.key,
    required this.debt,
  });

  @override
  State<DebtSchedulingScreen> createState() => _DebtSchedulingScreenState();
}

class _DebtSchedulingScreenState extends State<DebtSchedulingScreen> {
  final DebtReminderService _reminderService = DebtReminderService();
  List<DebtReminder> _reminders = [];
  bool _isLoading = true;
  String _selectedStatus = 'active'; // active, overdue, dueSoon

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await _reminderService.getRemindersForDebt(widget.debt.id);
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String get _currentStatusLabel {
    if (widget.debt.isOverdue) return 'Quá hạn';
    if (widget.debt.isDueSoon) return 'Sắp tới hạn';
    if (widget.debt.remainingAmount > 0) return 'Còn nợ';
    return 'Đã thanh toán';
  }

  Color get _statusColor {
    if (widget.debt.isOverdue) return Colors.red;
    if (widget.debt.isDueSoon) return Colors.orange;
    if (widget.debt.remainingAmount > 0) return Colors.blue;
    return Colors.green;
  }

  IconData get _statusIcon {
    if (widget.debt.isOverdue) return Icons.error;
    if (widget.debt.isDueSoon) return Icons.warning;
    if (widget.debt.remainingAmount > 0) return Icons.schedule;
    return Icons.check_circle;
  }

  List<DebtReminder> get _filteredReminders {
    switch (_selectedStatus) {
      case 'overdue':
        return _reminders.where((r) => r.isOverdue).toList();
      case 'dueSoon':
        final sevenDaysFromNow = DateTime.now().add(const Duration(days: 7));
        return _reminders.where((r) => 
          !r.isCompleted && 
          !r.isOverdue && 
          r.scheduledDate.isBefore(sevenDaysFromNow)
        ).toList();
      default:
        return _reminders.where((r) => !r.isCompleted).toList();
    }
  }

  Future<void> _addReminder() async {
    final result = await showModalBottomSheet<DebtReminder>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddReminderSheet(debtId: widget.debt.id),
    );

    if (result != null) {
      final success = await _reminderService.addReminder(result);
      if (success) {
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã thêm lịch nhắc thanh toán'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _markReminderComplete(String reminderId) async {
    final success = await _reminderService.markReminderComplete(reminderId);
    if (success) {
      await _loadReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu hoàn thành'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa lịch nhắc'),
        content: const Text('Bạn có chắc chắn muốn xóa lịch nhắc này?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Xóa'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _reminderService.deleteReminder(reminderId);
      if (success) {
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa lịch nhắc'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Quản Lý Lịch Trả Nợ',
      showBackButton: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.add_alarm),
          onPressed: _addReminder,
          tooltip: 'Thêm lịch nhắc',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildDebtStatusCard()),
            SliverToBoxAdapter(child: _buildStatusFilter()),
            _buildRemindersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _statusIcon,
                  color: _statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trạng thái khoản nợ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentStatusLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusDetail(
                'Số tiền còn nợ',
                AppFormatter.formatCurrency(widget.debt.remainingAmount),
                Colors.red,
              ),
              if (widget.debt.dueDate != null)
                _buildStatusDetail(
                  'Ngày đáo hạn',
                  AppFormatter.formatDate(widget.debt.dueDate!),
                  widget.debt.isOverdue ? Colors.red : Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDetail(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: _selectedStatus,
        backgroundColor: Colors.green.withOpacity(0.1),
        thumbColor: Colors.green,
        onValueChanged: (String? value) {
          if (value != null) {
            setState(() => _selectedStatus = value);
          }
        },
        children: {
          'active': _buildSegmentItem('Hoạt động', _selectedStatus == 'active'),
          'overdue': _buildSegmentItem('Quá hạn', _selectedStatus == 'overdue'),
          'dueSoon': _buildSegmentItem('Sắp tới hạn', _selectedStatus == 'dueSoon'),
        },
      ),
    );
  }

  Widget _buildSegmentItem(String text, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRemindersList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final filteredReminders = _filteredReminders;
    
    if (filteredReminders.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có lịch nhắc nào',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhấn + để thêm lịch nhắc thanh toán',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final reminder = filteredReminders[index];
          return _buildReminderCard(reminder);
        },
        childCount: filteredReminders.length,
      ),
    );
  }

  Widget _buildReminderCard(DebtReminder reminder) {
    final isOverdue = reminder.isOverdue;
    final isDueToday = reminder.isDueToday;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue 
              ? Colors.red 
              : isDueToday 
                  ? Colors.orange 
                  : Colors.grey[200]!,
          width: isOverdue || isDueToday ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isOverdue 
                ? Colors.red 
                : isDueToday 
                    ? Colors.orange 
                    : Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOverdue 
                ? Icons.error_outline 
                : isDueToday 
                    ? Icons.today 
                    : Icons.schedule,
            color: isOverdue 
                ? Colors.red 
                : isDueToday 
                    ? Colors.orange 
                    : Colors.blue,
          ),
        ),
        title: Text(
          reminder.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Ngày: ${AppFormatter.formatDate(reminder.scheduledDate)}',
              style: TextStyle(
                fontSize: 14,
                color: isOverdue ? Colors.red : Colors.grey[600],
              ),
            ),
            if (reminder.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                reminder.notes!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              color: Colors.green,
              onPressed: () => _markReminderComplete(reminder.id),
              tooltip: 'Đánh dấu hoàn thành',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: () => _deleteReminder(reminder.id),
              tooltip: 'Xóa lịch nhắc',
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding new reminders
class _AddReminderSheet extends StatefulWidget {
  final String debtId;

  const _AddReminderSheet({required this.debtId});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final reminder = DebtReminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        debtId: widget.debtId,
        scheduledDate: _selectedDate,
        title: _titleController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isCompleted: false,
        createdAt: DateTime.now(),
      );

      Navigator.pop(context, reminder);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thêm Lịch Nhắc Thanh Toán',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề nhắc nhở',
                border: OutlineInputBorder(),
                hintText: 'VD: Nhắc trả nợ khách hàng A',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tiêu đề';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày nhắc nhở',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(AppFormatter.formatDate(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
                hintText: 'VD: Khách hàng yêu cầu nhắc trước 2 ngày',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submit,
                child: const Text('Thêm Lịch Nhắc'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}