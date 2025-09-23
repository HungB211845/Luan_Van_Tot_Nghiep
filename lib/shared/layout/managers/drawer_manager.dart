// =============================================================================
// DRAWER MANAGER - QUẢN LÝ RESPONSIVE NAVIGATION DRAWER
// =============================================================================

import 'package:flutter/material.dart';
import '../models/navigation_item.dart';

class DrawerManager {
  static Widget buildDrawer(
    List<NavigationItem>? items,
    BuildContext context, {
    Widget? header,
    Widget? footer,
    String? currentRoute,
    String? title,
  }) {
    return Drawer(
      child: Column(
        children: [
          // Header
          header ?? _buildDefaultHeader(),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: items
                  ?.map((item) => _buildDrawerItem(
                        context,
                        item,
                        isSelected: currentRoute == item.route,
                      ))
                  .toList() ?? [],
            ),
          ),

          // Footer
          if (footer != null) footer,

          // Default footer
          if (footer == null) _buildDefaultFooter(context),
        ],
      ),
    );
  }

  static Widget buildSidePanel(
    BuildContext context,
    List<NavigationItem> items, {
    String? currentRoute,
    double width = 300,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.menu, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: items
                  .map((item) => _buildSidePanelItem(
                        context,
                        item,
                        isSelected: currentRoute == item.route,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildDesktopSidebar(
    BuildContext context,
    List<NavigationItem> items, {
    String? currentRoute,
    double width = 250,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar header
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.store, color: Colors.green),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Agricultural POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cửa hàng nông nghiệp',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items
                  .map((item) => _buildDesktopSidebarItem(
                        context,
                        item,
                        isSelected: currentRoute == item.route,
                      ))
                  .toList(),
            ),
          ),

          // Settings section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  'Cài đặt',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PRIVATE HELPER METHODS

  static Widget _buildDefaultHeader() {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(color: Colors.green),
      accountName: const Text(
        'Cửa Hàng Nông Nghiệp',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      accountEmail: const Text('admin@agripos.com'),
      currentAccountPicture: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.store, color: Colors.green, size: 40),
      ),
    );
  }

  static Widget _buildDefaultFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
          const SizedBox(width: 8),
          Text(
            'v1.0.0',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Đăng xuất',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDrawerItem(
    BuildContext context,
    NavigationItem item, {
    bool isSelected = false,
  }) {
    return item.toDrawerTile(
      context,
      isSelected: isSelected,
      onTap: item.enabled
          ? () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, item.route);
            }
          : null,
    );
  }

  static Widget _buildSidePanelItem(
    BuildContext context,
    NavigationItem item, {
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.green : Colors.grey[600],
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.green : Colors.grey[700],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        enabled: item.enabled,
        onTap: item.enabled
            ? () => Navigator.pushNamed(context, item.route)
            : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  static Widget _buildDesktopSidebarItem(
    BuildContext context,
    NavigationItem item, {
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.white : Colors.grey[600],
          size: 20,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: item.badgeCount != null && item.badgeCount! > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badgeCount!.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        enabled: item.enabled,
        onTap: item.enabled
            ? () => Navigator.pushNamed(context, item.route)
            : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}