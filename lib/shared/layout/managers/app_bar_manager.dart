// =============================================================================
// APP BAR MANAGER - QUẢN LÝ TẤT CẢ LOẠI APPBAR
// =============================================================================

import 'package:flutter/material.dart';
import '../models/layout_config.dart';

class AppBarManager {
  static PreferredSizeWidget? buildAppBar(
    LayoutConfig config,
    BuildContext context, {
    TabController? tabController,
  }) {
    if (config.appBarType == AppBarType.none) return null;

    switch (config.appBarType) {
      case AppBarType.simple:
        return _buildSimpleAppBar(config, context);
      
      case AppBarType.search:
        return _buildSearchAppBar(config, context);
      
      case AppBarType.actions:
        return _buildActionsAppBar(config, context);
      
      case AppBarType.tabbed:
        return _buildTabbedAppBar(config, context, tabController);
      
      case AppBarType.none:
        return null;
    }
  }

  static AppBar _buildSimpleAppBar(LayoutConfig config, BuildContext context) {
    return AppBar(
      title: config.title != null ? Text(config.title!) : null,
      centerTitle: config.centerTitle,
      backgroundColor: config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      automaticallyImplyLeading: config.showBackButton,
      leading: config.showBackButton ? _buildBackButton(context) : null,
      actions: config.appBarActions,
    );
  }

  static AppBar _buildSearchAppBar(LayoutConfig config, BuildContext context) {
    return AppBar(
      title: config.searchWidget ??
        TextField(
          decoration: InputDecoration(
            hintText: 'Tìm kiếm...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      backgroundColor: config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 4,
      automaticallyImplyLeading: config.showBackButton,
      leading: config.showBackButton ? _buildBackButton(context) : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Implement search logic
          },
        ),
        if (config.appBarActions != null) ...config.appBarActions!,
      ],
    );
  }

  static AppBar _buildActionsAppBar(LayoutConfig config, BuildContext context) {
    return AppBar(
      title: config.title != null ? Text(config.title!) : null,
      centerTitle: config.centerTitle,
      backgroundColor: config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 4,
      automaticallyImplyLeading: config.showBackButton,
      leading: config.showBackButton ? _buildBackButton(context) : null,
      actions: config.appBarActions ?? [
        PopupMenuButton<String>(
          onSelected: (value) {
            // Handle menu selection
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Chỉnh sửa'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Xóa'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static AppBar _buildTabbedAppBar(
    LayoutConfig config,
    BuildContext context,
    TabController? tabController,
  ) {
    return AppBar(
      title: config.title != null ? Text(config.title!) : null,
      centerTitle: config.centerTitle,
      backgroundColor: config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 0, // Remove shadow for tabbed design
      automaticallyImplyLeading: config.showBackButton,
      leading: config.showBackButton ? _buildBackButton(context) : null,
      actions: config.appBarActions,
      bottom: config.tabs != null && tabController != null
          ? TabBar(
              controller: tabController,
              tabs: config.tabs!,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
            )
          : null,
    );
  }

  // HELPER METHOD CHO BACK BUTTON
  static Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        // Luôn về HomeScreen khi bấm back
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/', // HomeScreen route
          (route) => false, // Remove tất cả routes
        );
      },
      tooltip: 'Về trang chủ',
    );
  }
}
