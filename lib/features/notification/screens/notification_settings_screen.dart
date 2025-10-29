import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_settings_provider.dart';
import '../models/notification_preferences.dart';
import '../providers/notification_provider.dart';
import '../utils/inventory_threshold_helper.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, TextEditingController> _thresholdControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSettingsProvider>().loadPreferences();
    });
  }

  @override
  void dispose() {
    for (final controller in _thresholdControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
          _syncThresholdControllers(provider);

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
                    onChanged: (val) async {
                      await provider.togglePush(val);
                      await context.read<NotificationProvider>().refresh();
                    },
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
                    onChanged: (val) async {
                      await provider.toggleInventory(val);
                      await context.read<NotificationProvider>().refresh();
                    },
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Đơn nhập hàng',
                    subtitle: 'Trạng thái đơn nhập & lịch nhận hàng',
                    value: prefs.purchaseOrderAlerts,
                    onChanged: (val) async {
                      await provider.togglePurchaseOrder(val);
                      // future: hook into PO notifications
                    },
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Công nợ',
                    subtitle: 'Nhắc nhở thu hồi công nợ, đến hạn trả',
                    value: prefs.debtAlerts,
                    onChanged: (val) async {
                      await provider.toggleDebt(val);
                      // placeholder for debt notifications
                    },
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
                    onChanged: (val) async {
                      await provider.toggle30Days(val);
                      await context.read<NotificationProvider>().refresh();
                    },
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Trước 60 ngày',
                    subtitle: 'Mức ưu tiên trung bình',
                    value: prefs.notify60Days,
                    onChanged: (val) async {
                      await provider.toggle60Days(val);
                      await context.read<NotificationProvider>().refresh();
                    },
                  ),
                  _Divider(theme: theme),
                  _SwitchTile(
                    title: 'Trước 90 ngày',
                    subtitle: 'Mức ưu tiên thấp',
                    value: prefs.notify90Days,
                    onChanged: (val) async {
                      await provider.toggle90Days(val);
                      await context.read<NotificationProvider>().refresh();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLowStockThresholdSection(theme, provider),
            ],
          );
        },
      ),
    );
  }

  void _syncThresholdControllers(NotificationSettingsProvider provider) {
    final thresholds = provider.lowStockThresholds;
    final allKeys = {
      ...InventoryThresholdHelper.defaultThresholds.keys,
      ...thresholds.keys,
    };

    for (final key in allKeys) {
      final normalizedKey = key.toUpperCase();
      final controller = _thresholdControllers.putIfAbsent(
        normalizedKey,
        () => TextEditingController(),
      );
      final value = thresholds[normalizedKey] ??
          InventoryThresholdHelper.defaultThresholds[normalizedKey] ??
          InventoryThresholdHelper.fallbackThreshold;
      final formatted = _formatThreshold(value);
      if (controller.text != formatted) {
        controller.text = formatted;
      }
    }
  }

  String _formatThreshold(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _handleThresholdSubmit(
    NotificationSettingsProvider provider,
    String categoryKey,
    String rawValue,
  ) async {
    final sanitized = rawValue.trim();
    if (sanitized.isEmpty) {
      return;
    }
    final parsed = double.tryParse(sanitized.replaceAll(',', '.'));
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giá trị không hợp lệ. Vui lòng nhập số hợp lệ.'),
          backgroundColor: Colors.red,
        ),
      );
      final controller = _thresholdControllers[categoryKey.toUpperCase()];
      if (controller != null) {
        controller.text = _formatThreshold(
          provider.lowStockThresholds[categoryKey.toUpperCase()] ??
              InventoryThresholdHelper.defaultThresholds[categoryKey.toUpperCase()] ??
              InventoryThresholdHelper.fallbackThreshold,
        );
      }
      return;
    }

    final notificationProvider = context.read<NotificationProvider>();
    await provider.updateLowStockThreshold(categoryKey, parsed);
    notificationProvider.updateThresholds(
      Map<String, double>.from(provider.lowStockThresholds),
    );
    await notificationProvider.refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã cập nhật ngưỡng cảnh báo cho ${_thresholdLabel(categoryKey)}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildLowStockThresholdSection(
    ThemeData theme,
    NotificationSettingsProvider provider,
  ) {
    final entries = <_ThresholdConfigItem>[
      _ThresholdConfigItem(
        key: 'FERTILIZER',
        title: 'Phân bón',
        subtitle: 'Số bao tối thiểu để cảnh báo sắp hết',
        unitLabel: 'Bao',
      ),
      _ThresholdConfigItem(
        key: 'PESTICIDE',
        title: 'Thuốc BVTV',
        subtitle: 'Số thùng tối thiểu để cảnh báo',
        unitLabel: 'Thùng',
      ),
      _ThresholdConfigItem(
        key: 'SEED',
        title: 'Giống cây',
        subtitle: 'Số bao/tấn tối thiểu để cảnh báo',
        unitLabel: 'Đơn vị',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          label: 'Ngưỡng tồn kho',
          description:
              'Thiết lập số lượng tối thiểu cho từng nhóm sản phẩm trước khi hệ thống cảnh báo “Sắp hết”.',
        ),
        _SettingsCard(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _buildThresholdField(entries[i], provider),
              if (i != entries.length - 1) _Divider(theme: theme),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildThresholdField(
    _ThresholdConfigItem item,
    NotificationSettingsProvider provider,
  ) {
    final controller = _thresholdControllers[item.key.toUpperCase()]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: item.unitLabel.isEmpty ? null : item.unitLabel,
            ),
            onSubmitted: (value) =>
                _handleThresholdSubmit(provider, item.key, value),
          ),
        ],
      ),
    );
  }

  String _thresholdLabel(String categoryKey) {
    switch (categoryKey.toUpperCase()) {
      case 'FERTILIZER':
        return 'Phân bón';
      case 'PESTICIDE':
        return 'Thuốc BVTV';
      case 'SEED':
        return 'Giống cây';
      default:
        return 'Sản phẩm';
    }
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

class _ThresholdConfigItem {
  final String key;
  final String title;
  final String subtitle;
  final String unitLabel;

  const _ThresholdConfigItem({
    required this.key,
    required this.title,
    required this.subtitle,
    this.unitLabel = '',
  });
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
  final Future<void> Function(bool) onChanged;

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
        onChanged: (val) {
          onChanged(val);
        },
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
