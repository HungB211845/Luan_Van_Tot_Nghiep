import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class QuickAccessItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const QuickAccessItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  Map<String, dynamic> toJson() => {'id': id};

  factory QuickAccessItem.fromJson(Map<String, dynamic> json) {
    // Find item by ID from available items
    return QuickAccessItem.availableItems.firstWhere(
      (item) => item.id == json['id'],
      orElse: () => QuickAccessItem.availableItems.first,
    );
  }

  // All available quick access items
  static final List<QuickAccessItem> availableItems = [
    const QuickAccessItem(
      id: 'purchase_orders',
      label: 'Nhập kho',
      icon: CupertinoIcons.cube_box_fill,
      color: Colors.blue,
      route: '/purchase-orders',
    ),
    const QuickAccessItem(
      id: 'reports',
      label: 'Báo cáo',
      icon: CupertinoIcons.chart_bar_fill,
      color: Colors.orange,
      route: '/reports',
    ),
    const QuickAccessItem(
      id: 'customers',
      label: 'Khách hàng',
      icon: CupertinoIcons.person_2_fill,
      color: Colors.purple,
      route: '/customers',
    ),
    const QuickAccessItem(
      id: 'debts',
      label: 'Công nợ',
      icon: CupertinoIcons.creditcard_fill,
      color: Colors.red,
      route: '/debts',
    ),
    const QuickAccessItem(
      id: 'companies',
      label: 'Nhà cung cấp',
      icon: CupertinoIcons.building_2_fill,
      color: Colors.teal,
      route: '/companies',
    ),
    const QuickAccessItem(
      id: 'inventory',
      label: 'Kiểm kho',
      icon: CupertinoIcons.list_bullet_below_rectangle,
      color: Colors.indigo,
      route: '/inventory',
    ),
  ];

  // Default configuration (first 4 items)
  static List<QuickAccessItem> get defaultItems => availableItems.take(4).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickAccessItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
