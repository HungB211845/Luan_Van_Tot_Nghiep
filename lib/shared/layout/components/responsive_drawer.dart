// =============================================================================
// RESPONSIVE DRAWER COMPONENTS - CÁC COMPONENT DRAWER RESPONSIVE
// =============================================================================

import 'package:flutter/material.dart';
import '../models/navigation_item.dart';

class ResponsiveDrawer extends StatelessWidget {
  final List<NavigationItem> items;
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final Widget? header;
  final Widget? footer;
  final String? title;
  final double breakpoint;
  final bool extended;

  const ResponsiveDrawer({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.header,
    this.footer,
    this.title,
    this.breakpoint = 600,
    this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= breakpoint;
        
        if (isWideScreen) {
          return _buildNavigationRail(context);
        } else {
          return _buildDrawer(context);
        }
      },
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: extended,
      labelType: extended 
          ? NavigationRailLabelType.none 
          : NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      elevation: 4,
      leading: _buildRailHeader(),
      trailing: footer,
      destinations: items.map((item) => _buildRailDestination(item)).toList(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          header ?? _buildDefaultDrawerHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildDrawerItem(item, index == selectedIndex, () {
                  Navigator.pop(context);
                  onDestinationSelected(index);
                });
              }).toList(),
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }

  Widget? _buildRailHeader() {
    if (header != null) return header;
    
    return Column(
      children: [
        const SizedBox(height: 20),
        FloatingActionButton(
          mini: true,
          backgroundColor: Colors.green,
          onPressed: () {},
          child: const Icon(Icons.agriculture, color: Colors.white),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDefaultDrawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green, Colors.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.agriculture, size: 35, color: Colors.green),
          ),
          const SizedBox(height: 12),
          Text(
            title ?? 'Agricultural POS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Quản lý cửa hàng nông nghiệp',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(NavigationItem item) {
    return NavigationRailDestination(
      icon: Badge(
        isLabelVisible: item.badgeCount != null && item.badgeCount! > 0,
        label: item.badgeCount != null
            ? Text(
                item.badgeCount! > 99 ? '99+' : item.badgeCount!.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              )
            : null,
        child: Icon(item.icon),
      ),
      selectedIcon: item.activeIcon != null 
          ? Icon(item.activeIcon!) 
          : null,
      label: Text(item.label),
    );
  }

  Widget _buildDrawerItem(NavigationItem item, bool isSelected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: isSelected ? Colors.green : Colors.grey[700],
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: item.enabled ? 
              (isSelected ? Colors.green : Colors.black87) : 
              Colors.grey,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: item.badgeCount != null && item.badgeCount! > 0
          ? Badge(
              label: Text(
                item.badgeCount! > 99 ? '99+' : item.badgeCount!.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              backgroundColor: Colors.red,
            )
          : null,
      enabled: item.enabled,
      selected: isSelected,
      selectedTileColor: Colors.green.withOpacity(0.1),
      onTap: onTap,
    );
  }
}
