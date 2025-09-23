// =============================================================================
// MAIN LAYOUT WRAPPER - MASTER CONTAINER QUẢN LÝ TOÀN BỘ UI SHELL
// =============================================================================

import 'package:flutter/material.dart';
import 'models/layout_config.dart';
import 'managers/app_bar_manager.dart';
import 'managers/bottom_nav_manager.dart';
import 'managers/fab_manager.dart';
import 'managers/drawer_manager.dart';

class MainLayoutWrapper extends StatefulWidget {
  final LayoutConfig config;
  final Widget child;
  final TabController? tabController;

  const MainLayoutWrapper({
    super.key,
    required this.config,
    required this.child,
    this.tabController,
  });

  @override
  State<MainLayoutWrapper> createState() => _MainLayoutWrapperState();
}

class _MainLayoutWrapperState extends State<MainLayoutWrapper> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.config.backgroundColor,
      
      // AppBar Management
      appBar: AppBarManager.buildAppBar(
        widget.config, 
        context,
        tabController: widget.tabController,
      ),
      
      // Drawer Management  
      drawer: widget.config.hasDrawer
          ? DrawerManager.buildDrawer(
              widget.config.navigationItems,
              context,
              title: widget.config.title,
            )
          : null,
      
      // End Drawer
      endDrawer: widget.config.hasEndDrawer
          ? DrawerManager.buildDrawer(
              widget.config.navigationItems,
              context,
              title: widget.config.title,
            )
          : null,
      
      // Body với SafeArea để tránh overflow
      body: SafeArea(
        bottom: _shouldUseSafeAreaBottom(),
        child: _buildBody(),
      ),
      
      // Bottom Navigation
      bottomNavigationBar: _buildBottomNavigation(),
      
      // FAB Management
      floatingActionButton: FABManager.buildFAB(widget.config, context),
      floatingActionButtonLocation: FABManager.getFABLocation(widget.config),
    );
  }

  Widget _buildBody() {
    // Nếu có tabs, wrap body trong TabBarView
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

  Widget? _buildBottomNavigation() {
    if (widget.config.navigationItems == null || 
        widget.config.navigationItems!.isEmpty ||
        widget.config.layoutType == LayoutType.simple ||
        widget.config.layoutType == LayoutType.withAppBar) {
      return null;
    }

    return BottomNavManager(
      items: widget.config.navigationItems!,
      currentIndex: _currentNavIndex,
      onTap: _handleNavigation,
    );
  }

  void _handleNavigation(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    final route = widget.config.navigationItems![index].route;
    if (route != ModalRoute.of(context)?.settings.name) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  bool _shouldUseSafeAreaBottom() {
    // Không dùng SafeArea bottom nếu có bottom navigation
    return _buildBottomNavigation() == null;
  }
}

// =============================================================================
// LAYOUT WRAPPER EXTENSIONS - HELPER METHODS
// =============================================================================

extension LayoutWrapperExtensions on LayoutConfig {
  MainLayoutWrapper wrapChild(
    Widget child, {
    TabController? tabController,
  }) {
    return MainLayoutWrapper(
      config: this,
      child: child,
      tabController: tabController,
    );
  }
}

// =============================================================================
// RESPONSIVE LAYOUT WRAPPER - TỰ ĐỘNG ĐIỀU CHỈNH THEO MÀN HÌNH
// =============================================================================

class ResponsiveLayoutWrapper extends StatelessWidget {
  final LayoutConfig mobileConfig;
  final LayoutConfig tabletConfig;
  final LayoutConfig desktopConfig;
  final Widget child;
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const ResponsiveLayoutWrapper({
    super.key,
    required this.mobileConfig,
    required this.tabletConfig,
    required this.desktopConfig,
    required this.child,
    this.tabletBreakpoint = 768,
    this.desktopBreakpoint = 1024,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        LayoutConfig config;
        
        if (constraints.maxWidth >= desktopBreakpoint) {
          config = desktopConfig;
        } else if (constraints.maxWidth >= tabletBreakpoint) {
          config = tabletConfig;
        } else {
          config = mobileConfig;
        }
        
        return MainLayoutWrapper(
          config: config,
          child: child,
        );
      },
    );
  }
}
