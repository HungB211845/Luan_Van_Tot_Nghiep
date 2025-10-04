// =============================================================================
// UNIVERSAL RESPONSIVE SYSTEM - SINGLE SOURCE OF TRUTH
// =============================================================================
// Hệ thống responsive duy nhất cho toàn bộ app.
// Mọi screen chỉ cần gọi context.responsive để tự động adapt.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// =============================================================================
// RESPONSIVE BREAKPOINTS - UNIFIED CONSTANTS
// =============================================================================

class ResponsiveBreakpoints {
  static const double mobile = 600.0;   // < 600px = Mobile
  static const double tablet = 1200.0;  // 600-1200px = Tablet  
  static const double desktop = 1200.0; // >= 1200px = Desktop/Web
  
  // Helper methods
  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  
  // Get device type from width
  static ResponsiveDeviceType getDeviceType(double width) {
    // 🎯 FORCE DESKTOP on Web platform (Chrome, etc.) ALWAYS regardless of width
    if (PlatformInfo.isWeb) {
      return ResponsiveDeviceType.desktop;
    }

    if (width < mobile) return ResponsiveDeviceType.mobile;
    if (width < desktop) return ResponsiveDeviceType.tablet;
    return ResponsiveDeviceType.desktop;
  }
}

// =============================================================================
// PLATFORM DETECTION - SMART PLATFORM AWARENESS
// =============================================================================

class PlatformInfo {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  static bool get isApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  
  // Combined platform + screen size detection
  static bool get isMobileDevice => isMobile;
  static bool get isTabletDevice => !kIsWeb && (Platform.isIOS || Platform.isAndroid); // Could be tablet
  static bool get isDesktopDevice => isDesktop || isWeb;
}

// =============================================================================
// DEVICE TYPE ENUM
// =============================================================================

enum ResponsiveDeviceType {
  mobile,
  tablet, 
  desktop,
}

extension ResponsiveDeviceTypeExtension on ResponsiveDeviceType {
  bool get isMobile => this == ResponsiveDeviceType.mobile;
  bool get isTablet => this == ResponsiveDeviceType.tablet;
  bool get isDesktop => this == ResponsiveDeviceType.desktop;
  
  String get name {
    switch (this) {
      case ResponsiveDeviceType.mobile:
        return 'Mobile';
      case ResponsiveDeviceType.tablet:
        return 'Tablet';
      case ResponsiveDeviceType.desktop:
        return 'Desktop';
    }
  }
}

// =============================================================================
// RESPONSIVE DATA CLASS - CONTAINS ALL RESPONSIVE INFO
// =============================================================================

class ResponsiveData {
  final ResponsiveDeviceType deviceType;
  final double screenWidth;
  final double screenHeight;
  final bool isLandscape;
  final bool isPortrait;
  final bool hasNotch;
  final EdgeInsets safeArea;
  
  const ResponsiveData({
    required this.deviceType,
    required this.screenWidth,
    required this.screenHeight,
    required this.isLandscape,
    required this.isPortrait,
    required this.hasNotch,
    required this.safeArea,
  });
  
  // Convenience getters
  bool get isMobile => deviceType.isMobile;
  bool get isTablet => deviceType.isTablet;
  bool get isDesktop => deviceType.isDesktop;
  
  // Layout helpers
  double get contentWidth {
    if (isMobile) return screenWidth - 32; // 16px padding each side
    if (isTablet) return screenWidth - 48; // 24px padding each side
    return (screenWidth * 0.8).clamp(600, 1200); // Max 1200px on desktop
  }
  
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    return 3;
  }
  
  double get cardSpacing {
    if (isMobile) return 8.0;
    if (isTablet) return 12.0;
    return 16.0;
  }
  
  double get sectionPadding {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }
  
  // Auth screen specific helpers
  bool get shouldShowAppBar => isMobile; // Only show AppBar on mobile
  bool get shouldUseSidebar => isDesktop; // Use sidebar on desktop
  bool get shouldShowBiometric => PlatformInfo.isMobileDevice; // Only on mobile devices
  
  // Navigation helpers
  bool get shouldUseBottomNav => isMobile;
  bool get shouldUseDrawer => isTablet;
  bool get shouldUseSideNav => isDesktop;
  
  // Form helpers
  double get maxFormWidth {
    if (isMobile) return double.infinity;
    if (isTablet) return 500;
    return 400; // Constrained form width on desktop
  }
  
  CrossAxisAlignment get formAlignment {
    if (isMobile) return CrossAxisAlignment.stretch;
    return CrossAxisAlignment.center; // Center forms on larger screens
  }
}

// =============================================================================
// RESPONSIVE MANAGER - THE BRAIN OF THE SYSTEM
// =============================================================================

class ResponsiveManager {
  static ResponsiveData _getResponsiveData(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final deviceType = ResponsiveBreakpoints.getDeviceType(size.width);
    
    return ResponsiveData(
      deviceType: deviceType,
      screenWidth: size.width,
      screenHeight: size.height,
      isLandscape: size.width > size.height,
      isPortrait: size.height >= size.width,
      hasNotch: mediaQuery.padding.top > 24, // Rough notch detection
      safeArea: mediaQuery.padding,
    );
  }
  
  // The magic method - returns appropriate widget based on device type
  static Widget adaptive(
    BuildContext context, {
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final responsive = _getResponsiveData(context);
    
    switch (responsive.deviceType) {
      case ResponsiveDeviceType.mobile:
        return mobile;
      case ResponsiveDeviceType.tablet:
        return tablet ?? mobile; // Fallback to mobile if tablet not provided
      case ResponsiveDeviceType.desktop:
        return desktop ?? tablet ?? mobile; // Fallback chain
    }
  }
  
  // Value-based adaptive method
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final responsive = _getResponsiveData(context);
    
    switch (responsive.deviceType) {
      case ResponsiveDeviceType.mobile:
        return mobile;
      case ResponsiveDeviceType.tablet:
        return tablet ?? mobile;
      case ResponsiveDeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

// =============================================================================
// CONTEXT EXTENSION - THE MAGIC INTERFACE
// =============================================================================

extension ResponsiveContext on BuildContext {
  /// Get responsive data for current context
  ResponsiveData get responsive => ResponsiveManager._getResponsiveData(this);
  
  /// Quick device type checks
  bool get isMobile => responsive.isMobile;
  bool get isTablet => responsive.isTablet;
  bool get isDesktop => responsive.isDesktop;
  
  /// Adaptive widget builder - THE MAIN METHOD SCREENS WILL USE
  Widget adaptiveWidget({
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) => ResponsiveManager.adaptive(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );
  
  /// Adaptive value selector
  T adaptiveValue<T>({
    required T mobile,
    T? tablet, 
    T? desktop,
  }) => ResponsiveManager.value<T>(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );
  
  /// Quick layout helpers
  double get contentWidth => responsive.contentWidth;
  int get gridColumns => responsive.gridColumns;
  double get cardSpacing => responsive.cardSpacing;
  double get sectionPadding => responsive.sectionPadding;
  double get maxFormWidth => responsive.maxFormWidth;
  CrossAxisAlignment get formAlignment => responsive.formAlignment;
  
  /// Navigation helpers
  bool get shouldShowAppBar => responsive.shouldShowAppBar;
  bool get shouldUseSidebar => responsive.shouldUseSidebar;
  bool get shouldShowBiometric => responsive.shouldShowBiometric;
  bool get shouldUseBottomNav => responsive.shouldUseBottomNav;
  bool get shouldUseDrawer => responsive.shouldUseDrawer;
  bool get shouldUseSideNav => responsive.shouldUseSideNav;
}

// =============================================================================
// RESPONSIVE SCAFFOLD - AUTOMATIC SCAFFOLD BUILDER
// =============================================================================

class ResponsiveScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final List<BottomNavigationBarItem>? bottomNavItems;
  final int currentIndex;
  final Function(int)? onBottomNavTap;
  final bool showBackButton;
  
  const ResponsiveScaffold({
    Key? key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.drawer,
    this.bottomNavItems,
    this.currentIndex = 0,
    this.onBottomNavTap,
    this.showBackButton = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return context.adaptiveWidget(
      mobile: _buildMobileScaffold(context),
      tablet: _buildTabletScaffold(context),
      desktop: _buildDesktopScaffold(context),
    );
  }
  
  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: actions,
        automaticallyImplyLeading: showBackButton,
      ),
      body: body,
      drawer: drawer,
      bottomNavigationBar: bottomNavItems != null
          ? BottomNavigationBar(
              items: bottomNavItems!,
              currentIndex: currentIndex,
              onTap: onBottomNavTap,
              type: BottomNavigationBarType.fixed,
            )
          : null,
      floatingActionButton: floatingActionButton,
    );
  }
  
  Widget _buildTabletScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title!) : null,
        actions: actions,
        automaticallyImplyLeading: showBackButton,
      ),
      body: Row(
        children: [
          if (drawer != null) ...[
            Container(
              width: 280,
              child: drawer!,
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
  
  Widget _buildDesktopScaffold(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (drawer != null) ...[
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: drawer!,
            ),
          ],
          Expanded(
            child: Column(
              children: [
                // Desktop header toolbar
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      if (title != null) ...[
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                      ],
                      if (actions != null) ...actions!,
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

// =============================================================================
// RESPONSIVE AUTH WRAPPER - SPECIAL AUTH SCREENS HANDLER
// =============================================================================

class ResponsiveAuthScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? brandingWidget;
  
  const ResponsiveAuthScaffold({
    Key? key,
    required this.child,
    this.title,
    this.brandingWidget,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return context.adaptiveWidget(
      mobile: _buildMobileAuth(context),
      tablet: _buildTabletAuth(context), 
      desktop: _buildDesktopAuth(context),
    );
  }
  
  Widget _buildMobileAuth(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(child: child),
    );
  }
  
  Widget _buildTabletAuth(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Container(
            width: context.maxFormWidth,
            padding: EdgeInsets.all(context.sectionPadding),
            child: child,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDesktopAuth(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Left side - Branding (50%)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green, Color(0xFF4CAF50)],
                ),
              ),
              child: Center(
                child: brandingWidget ?? _buildDefaultBranding(),
              ),
            ),
          ),
          // Right side - Form (50%)
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultBranding() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.store_mall_directory,
          size: 120,
          color: Colors.white,
        ),
        SizedBox(height: 24),
        Text(
          'Agricultural POS',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Hệ thống quản lý cửa hàng nông nghiệp hiện đại',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}