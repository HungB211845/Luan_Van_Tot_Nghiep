// =============================================================================
// NAVIGATION ITEM MODEL - ĐỊNH NGHĨA CÁC MỤC NAVIGATION
// =============================================================================

import 'package:flutter/material.dart';

class NavigationItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final int? badgeCount;
  final Color? color;
  final bool enabled;

  const NavigationItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    this.badgeCount,
    this.color,
    this.enabled = true,
  });

  NavigationItem copyWith({
    IconData? icon,
    IconData? activeIcon,
    String? label,
    String? route,
    int? badgeCount,
    Color? color,
    bool? enabled,
  }) {
    return NavigationItem(
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      label: label ?? this.label,
      route: route ?? this.route,
      badgeCount: badgeCount ?? this.badgeCount,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationItem &&
        other.icon == icon &&
        other.activeIcon == activeIcon &&
        other.label == label &&
        other.route == route &&
        other.badgeCount == badgeCount &&
        other.color == color &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      icon,
      activeIcon,
      label,
      route,
      badgeCount,
      color,
      enabled,
    );
  }

  // CONVERSION METHODS FOR DIFFERENT WIDGETS
  NavigationDestination toBottomNavDestination({bool isSelected = false}) {
    return NavigationDestination(
      icon: _buildIcon(isSelected: false),
      selectedIcon: _buildIcon(isSelected: true),
      label: label,
    );
  }

  ListTile toDrawerTile(BuildContext context, {
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: _buildIcon(isSelected: isSelected),
      title: Text(label),
      enabled: enabled,
      selected: isSelected,
      onTap: onTap ?? () => Navigator.pushNamed(context, route),
    );
  }

  Widget _buildIcon({bool isSelected = false}) {
    final IconData iconToUse = isSelected && activeIcon != null ? activeIcon! : icon;
    Widget iconWidget = Icon(iconToUse, color: color);

    if (badgeCount != null && badgeCount! > 0) {
      return Badge(
        label: Text(badgeCount.toString()),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
