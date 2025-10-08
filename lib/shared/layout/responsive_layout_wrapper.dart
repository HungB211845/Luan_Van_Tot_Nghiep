// =============================================================================
// RESPONSIVE LAYOUT WRAPPER - TỰ ĐỘNG ĐIỀU CHỈNH THEO SCREEN SIZE
// =============================================================================

import 'package:flutter/material.dart';
import 'package:agricultural_pos/shared/utils/responsive.dart';
import 'models/layout_config.dart';
import 'models/navigation_item.dart';
import 'managers/app_bar_manager.dart';
import 'managers/bottom_nav_manager.dart';
import 'managers/fab_manager.dart';
import 'managers/drawer_manager.dart';

class ResponsiveLayoutWrapper extends StatefulWidget {
  final LayoutConfig config;
  final Widget child;
  final TabController? tabController;

  const ResponsiveLayoutWrapper({
    super.key,
    required this.config,
    required this.child,
    this.tabController,
  });

  @override
  State<ResponsiveLayoutWrapper> createState() => _ResponsiveLayoutWrapperState();
}

class _ResponsiveLayoutWrapperState extends State<ResponsiveLayoutWrapper> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (ResponsiveBreakpoints.isDesktop(width)) {
          return _buildDesktopLayout(constraints);
        } else if (ResponsiveBreakpoints.isTablet(width)) {
          return _buildTabletLayout(constraints);
        } else {
          return _buildMobileLayout(constraints);
        }
      },
    );
  }

  // ==========================================================================
  // MOBILE LAYOUT (< 600px)
  // ==========================================================================
  Widget _buildMobileLayout(BoxConstraints constraints) {
    return Scaffold(
      backgroundColor: widget.config.backgroundColor,

      // Standard AppBar với back button
      appBar: _buildMobileAppBar(),

      // Drawer cho navigation
      drawer: _shouldShowDrawer() ? _buildMobileDrawer() : null,

      // Body với SafeArea và padding 16px
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBodyContent(),
        ),
      ),

      // Bottom Navigation: Visible và persistent
      bottomNavigationBar: _buildMobileBottomNav(),

      // FAB: Standard floating
      floatingActionButton: _buildMobileFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget? _buildMobileAppBar() {
    return AppBar(
      title: Text(widget.config.title ?? 'Agricultural POS'),
      backgroundColor: widget.config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 2,
      automaticallyImplyLeading: widget.config.showBackButton,
      actions: widget.config.appBarActions,
    );
  }

  Widget? _buildMobileDrawer() {
    return DrawerManager.buildDrawer(
      widget.config.navigationItems,
      context,
      title: widget.config.title,
    );
  }

  Widget? _buildMobileBottomNav() {
    if (widget.config.navigationItems == null ||
        widget.config.navigationItems!.isEmpty) {
      return null;
    }

    return BottomNavManager(
      items: widget.config.navigationItems!,
      currentIndex: _currentNavIndex,
      onTap: _handleNavigation,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey[600],
    );
  }

  Widget? _buildMobileFAB() {
    if (widget.config.fabType == FABType.none) return null;

    return FloatingActionButton(
      onPressed: widget.config.fabAction ?? () {},
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      child: Icon(widget.config.fabIcon ?? Icons.add),
    );
  }

  // ==========================================================================
  // TABLET LAYOUT (ResponsiveBreakpoints.mobile - ResponsiveBreakpoints.desktop)
  // ==========================================================================
  Widget _buildTabletLayout(BoxConstraints constraints) {
    return Scaffold(
      backgroundColor: widget.config.backgroundColor,

      // Expanded AppBar với additional actions
      appBar: _buildTabletAppBar(),

      // Body với optional side panel
      body: SafeArea(
        child: Row(
          children: [
            // Optional side panel cho categories/filters
            if (_shouldShowSidePanel()) ...[
              _buildSidePanel(),
              const VerticalDivider(width: 1),
            ],

            // Main content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildBodyContent(),
              ),
            ),
          ],
        ),
      ),

      // Adaptive rail navigation (optional)
      bottomNavigationBar: _buildTabletBottomNav(),

      // Extended FAB với label
      floatingActionButton: _buildTabletFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget? _buildTabletAppBar() {
    return AppBar(
      title: Text(widget.config.title ?? 'Agricultural POS'),
      backgroundColor: widget.config.appBarColor ?? Colors.green,
      foregroundColor: Colors.white,
      elevation: 2,
      automaticallyImplyLeading: widget.config.showBackButton,
      actions: [
        ...?widget.config.appBarActions,
        // Additional actions cho tablet
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          right: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          // Side panel header
          Container(
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Row(
              children: [
                Icon(Icons.category, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  'Danh mục',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: widget.config.navigationItems
                  ?.map((item) => _buildSidePanelItem(item))
                  .toList() ?? [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanelItem(NavigationItem item) {
    final isSelected = _currentNavIndex ==
        (widget.config.navigationItems?.indexOf(item) ?? -1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.green : Colors.grey[600],
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.green : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          if (item.route == '/') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          } else {
            Navigator.pushNamed(context, item.route);
          }
        },
      ),
    );
  }

  Widget? _buildTabletBottomNav() {
    // Optional rail navigation cho tablet
    if (widget.config.navigationItems == null ||
        widget.config.navigationItems!.isEmpty) {
      return null;
    }

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: widget.config.navigationItems!.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == _currentNavIndex;

          return Expanded(
            child: InkWell(
              onTap: () => _handleNavigation(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected ? Colors.green : Colors.grey[600],
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.green : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget? _buildTabletFAB() {
    if (widget.config.fabType == FABType.none) return null;

    return FloatingActionButton.extended(
      onPressed: widget.config.fabAction ?? () {},
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      icon: Icon(widget.config.fabIcon ?? Icons.add),
      label: Text(widget.config.fabLabel ?? 'Thêm mới'),
    );
  }

  // ==========================================================================
  // DESKTOP LAYOUT (> 1200px)
  // ==========================================================================
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Scaffold(
      backgroundColor: widget.config.backgroundColor,
      body: Row(
        children: [
          // Sidebar navigation
          _buildDesktopSidebar(),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Header toolbar với breadcrumb
                _buildDesktopToolbar(),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildBodyContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // No bottom navigation (replaced by sidebar)
      // FAB: Integrated vào toolbar (or floating if needed)
      floatingActionButton: _buildDesktopFAB(),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sidebar header
          Container(
            height: 100,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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
              padding: const EdgeInsets.all(8),
              children: widget.config.navigationItems
                  ?.map((item) => _buildDesktopSidebarItem(item))
                  .toList() ?? [],
            ),
          ),

          // Settings footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  'Cài đặt hệ thống',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebarItem(NavigationItem item) {
    final isSelected = _currentNavIndex ==
        (widget.config.navigationItems?.indexOf(item) ?? -1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () {
          if (item.route == '/') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          } else {
            Navigator.pushNamed(context, item.route);
          }
        },
      ),
    );
  }

  Widget _buildDesktopToolbar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Breadcrumb navigation
          Expanded(
            child: Row(
              children: [
                Icon(Icons.home, color: Colors.grey[600], size: 16),
                const SizedBox(width: 8),
                Text(
                  '/',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.config.title ?? 'Dashboard',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Toolbar actions
          Row(
            children: [
              // Integrated FAB action
              if (widget.config.fabType != FABType.none) ...[
                ElevatedButton.icon(
                  onPressed: widget.config.fabAction ?? () {},
                  icon: Icon(widget.config.fabIcon ?? Icons.add),
                  label: Text(widget.config.fabLabel ?? 'Thêm mới'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // Additional actions
              ...?widget.config.appBarActions,
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildDesktopFAB() {
    // FAB is integrated into toolbar for desktop
    return null;
  }

  // ==========================================================================
  // SHARED METHODS
  // ==========================================================================
  Widget _buildBodyContent() {
    if (widget.config.appBarType == AppBarType.tabbed &&
        widget.config.tabs != null &&
        widget.tabController != null) {

      return TabBarView(
        controller: widget.tabController,
        children: List.generate(
          widget.config.tabs!.length,
          (index) => widget.child,
        ),
      );
    }

    return widget.child;
  }

  bool _shouldShowDrawer() {
    return widget.config.hasDrawer &&
           widget.config.navigationItems != null &&
           widget.config.navigationItems!.isNotEmpty;
  }

  bool _shouldShowSidePanel() {
    return widget.config.navigationItems != null &&
           widget.config.navigationItems!.length > 3;
  }

  void _handleNavigation(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    if (widget.config.navigationItems != null &&
        index < widget.config.navigationItems!.length) {
      final route = widget.config.navigationItems![index].route;
      final currentRoute = ModalRoute.of(context)?.settings.name;

      // Nếu đã ở route đó rồi thì không navigate
      if (route == currentRoute) return;

      // Nếu bấm vào Home (index 0), luôn về HomeScreen
      if (index == 0 || route == '/') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false, // Remove tất cả routes
        );
      } else {
        // Cho các screens khác, navigate từ HomeScreen
        Navigator.pushNamed(context, route);
      }
    }
  }
}

// =============================================================================
// LAYOUT CONFIG EXTENSION
// =============================================================================
extension ResponsiveLayoutExtension on LayoutConfig {
  ResponsiveLayoutWrapper wrapChildResponsive(
    Widget child, {
    TabController? tabController,
  }) {
    return ResponsiveLayoutWrapper(
      config: this,
      child: child,
      tabController: tabController,
    );
  }
}