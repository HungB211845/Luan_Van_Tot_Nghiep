import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../notification/models/notification_message.dart';
import '../../notification/providers/notification_provider.dart';
import '../../../core/routing/route_names.dart';

enum _NotificationTab { all, inventory }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  _NotificationTab _selectedTab = _NotificationTab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            onPressed: () {
              Navigator.of(context, rootNavigator: true)
                  .pushNamed(RouteNames.notificationSettings);
            },
          ),
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              if (provider.unreadCount == 0) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: provider.markAllAsRead,
                child: const Text(
                  'Đọc hết',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(theme, provider.refresh, provider.errorMessage!);
          }

          final filtered = _filterNotifications(provider.notifications);
          if (filtered.isEmpty) {
            return _buildEmptyState(theme, provider.refresh, provider.notifications.isEmpty);
          }

          final grouped = _groupNotifications(filtered);

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildHeader(theme, provider.notifications.length, provider.unreadCount),
                const SizedBox(height: 16),
                _buildSegmentedControl(theme),
                const SizedBox(height: 16),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (notification) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NotificationTile(
                        notification: notification,
                        onTap: () => provider.markAsRead(notification.id),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, List<NotificationMessage>> _groupNotifications(
    List<NotificationMessage> notifications,
  ) {
    final Map<String, List<NotificationMessage>> grouped = {};
    for (final notification in notifications) {
      final label = _sectionLabel(notification.createdAt);
      grouped.putIfAbsent(label, () => []).add(notification);
    }
    return grouped;
  }

  List<NotificationMessage> _filterNotifications(
    List<NotificationMessage> notifications,
  ) {
    switch (_selectedTab) {
      case _NotificationTab.inventory:
        return notifications
            .where((n) =>
                n.severity == NotificationSeverity.warning ||
                n.severity == NotificationSeverity.danger)
            .toList();
      case _NotificationTab.all:
      default:
        return notifications;
    }
  }

  Widget _buildHeader(ThemeData theme, int total, int unread) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              CupertinoIcons.bell_solid,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn có $total thông báo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unread > 0
                      ? '$unread thông báo chưa đọc'
                      : 'Tất cả thông báo đã đọc',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(ThemeData theme) {
    return CupertinoSlidingSegmentedControl<_NotificationTab>(
      backgroundColor: Colors.green.withOpacity(0.12),
      thumbColor: Colors.green,
      groupValue: _selectedTab,
      children: {
        _NotificationTab.all: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Tất cả',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _selectedTab == _NotificationTab.all
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        _NotificationTab.inventory: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'Kho hàng',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _selectedTab == _NotificationTab.inventory
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      },
      onValueChanged: (value) {
        if (value != null) {
          setState(() => _selectedTab = value);
        }
      },
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    Future<void> Function() onRefresh,
    bool showRefresh,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.bell_slash,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không có thông báo nào',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Mọi thứ đang ổn. Khi có cảnh báo mới, chúng tôi sẽ hiển thị tại đây.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRefresh) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('Làm mới'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    Future<void> Function() onRetry,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tải được thông báo',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(CupertinoIcons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(dateOnly).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Hôm qua';
    return '${dateOnly.day.toString().padLeft(2, '0')}/${dateOnly.month.toString().padLeft(2, '0')}/${dateOnly.year}';
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationMessage notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData _iconForSeverity() {
    switch (notification.severity) {
      case NotificationSeverity.danger:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case NotificationSeverity.warning:
        return CupertinoIcons.exclamationmark_circle_fill;
      case NotificationSeverity.info:
      default:
        return CupertinoIcons.bell_solid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notification.severityColor(context);

    return Material(
      color: notification.isRead
          ? theme.colorScheme.surfaceVariant.withOpacity(0.2)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForSeverity(), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}
