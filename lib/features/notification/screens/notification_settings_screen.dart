import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_settings_provider.dart';
import '../models/notification_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSettingsProvider>().loadPreferences();
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
        title: const Text('Cài đặt thông báo'),
      ),
      body: Consumer<NotificationSettingsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final prefs = provider.preferences;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionHeader(
                label: 'Thông báo đẩy',
                description:
                    'Cho phép ứng dụng gửi cảnh báo tới thiết bị của bạn.',
              ),
              _SwitchTile(
                title: 'Bật thông báo',
                subtitle: 'Áp dụng cho cả iOS và Android',
                value: prefs.enablePushNotifications,
                onChanged: provider.togglePush,
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                label: 'Loại thông báo',
                description: 'Chọn các nguồn thông báo bạn muốn nhận.',
              ),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    title: 'Tồn kho & lô hàng',
                    subtitle: 'Cảnh báo sắp hết hạn, sắp hết hàng',
                    value: prefs.inventoryAlerts,
                    onChanged: provider.toggleInventory,
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Đơn nhập hàng',
                    subtitle: 'Trạng thái đơn nhập & lịch nhận hàng',
                    value: prefs.purchaseOrderAlerts,
                    onChanged: provider.togglePurchaseOrder,
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Công nợ',
                    subtitle: 'Nhắc nhở thu hồi công nợ, đến hạn trả',
                    value: prefs.debtAlerts,
                    onChanged: provider.toggleDebt,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                label: 'Chu kỳ nhắc hết hạn',
                description:
                    'Hệ thống sẽ gửi cảnh báo trước khi lô hàng hết hạn theo các mốc dưới đây.',
              ),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    title: 'Trước 30 ngày',
                    subtitle: 'Mức ưu tiên cao',
                    value: prefs.notify30Days,
                    onChanged: provider.toggle30Days,
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Trước 60 ngày',
                    subtitle: 'Mức ưu tiên trung bình',
                    value: prefs.notify60Days,
                    onChanged: provider.toggle60Days,
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Trước 90 ngày',
                    subtitle: 'Mức ưu tiên thấp',
                    value: prefs.notify90Days,
                    onChanged: provider.toggle90Days,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String description;
  const _SectionHeader({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final ThemeData theme;
  const _Divider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
    );
  }
}
