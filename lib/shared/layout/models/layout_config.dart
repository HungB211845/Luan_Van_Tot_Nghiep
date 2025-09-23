// =============================================================================
// LAYOUT CONFIGURATION - ĐỊNH NGHĨA CẤU HÌNH LAYOUT CHO CÁC MÀN HÌNH
// =============================================================================

import 'package:flutter/material.dart';
import 'navigation_item.dart';

enum LayoutType {
  simple,        // Chỉ body content
  withAppBar,    // AppBar + body  
  withBottomNav, // AppBar + body + bottom navigation
  withDrawer,    // AppBar + drawer + body
  fullLayout,    // AppBar + drawer + body + bottom nav + FAB
}

enum AppBarType {
  none,
  simple,
  search,
  actions,
  tabbed,
}

enum FABType {
  none,
  standard,
  extended,
  mini,
}

class LayoutConfig {
  final LayoutType layoutType;
  final AppBarType appBarType;
  final String? title;
  final List<NavigationItem>? navigationItems;
  final FABType fabType;
  final VoidCallback? fabAction;
  final String? fabLabel;
  final IconData? fabIcon;
  final bool hasDrawer;
  final bool hasEndDrawer;
  final List<Widget>? appBarActions;
  final Widget? searchWidget;
  final List<Tab>? tabs;
  final bool showBackButton;
  final bool centerTitle;
  final Color? appBarColor;
  final Color? backgroundColor;

  const LayoutConfig({
    this.layoutType = LayoutType.simple,
    this.appBarType = AppBarType.simple,
    this.title,
    this.navigationItems,
    this.fabType = FABType.none,
    this.fabAction,
    this.fabLabel,
    this.fabIcon,
    this.hasDrawer = false,
    this.hasEndDrawer = false,
    this.appBarActions,
    this.searchWidget,
    this.tabs,
    this.showBackButton = false,
    this.centerTitle = true,
    this.appBarColor,
    this.backgroundColor,
  });

  LayoutConfig copyWith({
    LayoutType? layoutType,
    AppBarType? appBarType,
    String? title,
    List<NavigationItem>? navigationItems,
    FABType? fabType,
    VoidCallback? fabAction,
    String? fabLabel,
    IconData? fabIcon,
    bool? hasDrawer,
    bool? hasEndDrawer,
    List<Widget>? appBarActions,
    Widget? searchWidget,
    List<Tab>? tabs,
    bool? showBackButton,
    bool? centerTitle,
    Color? appBarColor,
    Color? backgroundColor,
  }) {
    return LayoutConfig(
      layoutType: layoutType ?? this.layoutType,
      appBarType: appBarType ?? this.appBarType,
      title: title ?? this.title,
      navigationItems: navigationItems ?? this.navigationItems,
      fabType: fabType ?? this.fabType,
      fabAction: fabAction ?? this.fabAction,
      fabLabel: fabLabel ?? this.fabLabel,
      fabIcon: fabIcon ?? this.fabIcon,
      hasDrawer: hasDrawer ?? this.hasDrawer,
      hasEndDrawer: hasEndDrawer ?? this.hasEndDrawer,
      appBarActions: appBarActions ?? this.appBarActions,
      searchWidget: searchWidget ?? this.searchWidget,
      tabs: tabs ?? this.tabs,
      showBackButton: showBackButton ?? this.showBackButton,
      centerTitle: centerTitle ?? this.centerTitle,
      appBarColor: appBarColor ?? this.appBarColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

// =============================================================================
// PREDEFINED LAYOUTS - CÁC LAYOUT ĐỊNH SẴN CHO CÁC MÀN HÌNH PHỔ BIẾN
// =============================================================================

class AppLayouts {
  // Layout cho màn hình chính (Home)
  static const LayoutConfig home = LayoutConfig(
    layoutType: LayoutType.withBottomNav,
    appBarType: AppBarType.simple,
    title: 'Agricultural POS',
    appBarColor: Colors.green,
    navigationItems: [
      NavigationItem(icon: Icons.home, label: 'Trang chủ', route: '/'),
      NavigationItem(icon: Icons.point_of_sale, label: 'Bán hàng', route: '/pos'),
      NavigationItem(icon: Icons.people, label: 'Khách hàng', route: '/customers'),
      NavigationItem(icon: Icons.inventory, label: 'Sản phẩm', route: '/products'),
    ],
  );

  // Layout cho danh sách khách hàng
  static const LayoutConfig customerList = LayoutConfig(
    layoutType: LayoutType.fullLayout,
    appBarType: AppBarType.search,
    title: 'Quản lý khách hàng',
    fabType: FABType.standard,
    fabIcon: Icons.add,
    hasDrawer: false,
    showBackButton: true,
  );

  // Layout cho chi tiết khách hàng
  static const LayoutConfig customerDetail = LayoutConfig(
    layoutType: LayoutType.withAppBar,
    appBarType: AppBarType.actions,
    showBackButton: true,
  );

  // Layout cho danh sách sản phẩm với tabs
  static const LayoutConfig productList = LayoutConfig(
    layoutType: LayoutType.fullLayout,
    appBarType: AppBarType.tabbed,
    title: 'Quản lý sản phẩm',
    fabType: FABType.extended,
    fabLabel: 'Thêm sản phẩm',
    fabIcon: Icons.add_shopping_cart,
    showBackButton: true,
    tabs: [
      Tab(text: 'Phân bón', icon: Icon(Icons.eco)),
      Tab(text: 'Thuốc BVTV', icon: Icon(Icons.bug_report)),
      Tab(text: 'Lúa giống', icon: Icon(Icons.grass)),
    ],
  );

  // Layout cho POS
  static const LayoutConfig pos = LayoutConfig(
    layoutType: LayoutType.withAppBar,
    appBarType: AppBarType.actions,
    title: 'Bán hàng',
    showBackButton: true,
    backgroundColor: Color(0xFFF5F5F5),
  );
}
