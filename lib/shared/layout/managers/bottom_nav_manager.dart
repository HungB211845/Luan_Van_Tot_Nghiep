// =============================================================================
// BOTTOM NAVIGATION MANAGER - QUẢN LÝ PERSISTENT BOTTOM NAVIGATION
// =============================================================================

import 'package:flutter/material.dart';
import '../models/navigation_item.dart';

class BottomNavManager extends StatefulWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double? elevation;

  const BottomNavManager({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation = 8,
  });

  @override
  State<BottomNavManager> createState() => _BottomNavManagerState();
}

class _BottomNavManagerState extends State<BottomNavManager> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.length <= 3) {
      return _buildStandardBottomNav();
    } else {
      return _buildExtendedBottomNav();
    }
  }

  Widget _buildStandardBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      backgroundColor: widget.backgroundColor ?? Colors.white,
      selectedItemColor: widget.selectedItemColor ?? Colors.green,
      unselectedItemColor: widget.unselectedItemColor ?? Colors.grey,
      elevation: widget.elevation!,
      items: widget.items.map((item) => _buildBottomNavItem(item)).toList(),
    );
  }

  Widget _buildExtendedBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: widget.elevation!,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: widget.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == widget.currentIndex;
              
              return _buildExtendedNavItem(item, isSelected, index);
            }).toList(),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavItem(NavigationItem item) {
    return BottomNavigationBarItem(
      icon: _buildIconWithBadge(item),
      activeIcon: item.activeIcon != null 
          ? _buildIconWithBadge(item, useActiveIcon: true) 
          : null,
      label: item.label,
    );
  }

  Widget _buildExtendedNavItem(NavigationItem item, bool isSelected, int index) {
    final color = isSelected 
        ? (widget.selectedItemColor ?? Colors.green)
        : (widget.unselectedItemColor ?? Colors.grey);

    return Expanded(
      child: InkWell(
        onTap: item.enabled ? () => widget.onTap(index) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconWithBadge(
                item,
                useActiveIcon: isSelected && item.activeIcon != null,
                color: color,
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(
    NavigationItem item, {
    bool useActiveIcon = false,
    Color? color,
  }) {
    final iconData = useActiveIcon && item.activeIcon != null 
        ? item.activeIcon! 
        : item.icon;
    
    final icon = Icon(
      iconData,
      color: color ?? item.color,
      size: 20,
    );

    if (item.badgeCount == null || item.badgeCount! <= 0) {
      return icon;
    }

    return Badge(
      label: Text(
        item.badgeCount! > 99 ? '99+' : item.badgeCount!.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: Colors.red,
      child: icon,
    );
  }
}

// =============================================================================
// BOTTOM NAV CONTROLLER - QUẢN LÝ STATE CỦA NAVIGATION
// =============================================================================

class BottomNavController extends ChangeNotifier {
  int _currentIndex = 0;
  List<NavigationItem> _items = [];

  int get currentIndex => _currentIndex;
  List<NavigationItem> get items => _items;
  NavigationItem? get currentItem => 
      _items.isNotEmpty && _currentIndex < _items.length 
          ? _items[_currentIndex] 
          : null;

  void setItems(List<NavigationItem> items) {
    _items = items;
    if (_currentIndex >= items.length) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _items.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void updateBadgeCount(int itemIndex, int? count) {
    if (itemIndex >= 0 && itemIndex < _items.length) {
      _items[itemIndex] = _items[itemIndex].copyWith(badgeCount: count);
      notifyListeners();
    }
  }

  void enableItem(int itemIndex, bool enabled) {
    if (itemIndex >= 0 && itemIndex < _items.length) {
      _items[itemIndex] = _items[itemIndex].copyWith(enabled: enabled);
      notifyListeners();
    }
  }
}
