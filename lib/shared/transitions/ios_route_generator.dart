import 'package:flutter/material.dart';
import 'ios_page_route.dart';

/// Custom route generator với iOS-style transitions
class IOSRouteGenerator {
  /// Tạo route với iOS-style transition
  static Route<T> generateRoute<T>(
    RouteSettings settings,
    WidgetBuilder builder, {
    Duration? duration,
    Curve? curve,
    double? parallaxFactor,
    double? overlayOpacity,
  }) {
    return IOSPageRoute<T>(
      child: Builder(
        builder: (context) => builder(context),
      ),
      settings: settings,
      transitionDuration: duration ?? const Duration(milliseconds: 300),
      curve: curve ?? Curves.easeOutCubic,
      parallaxFactor: parallaxFactor ?? 0.3,
      overlayOpacity: overlayOpacity ?? 0.1,
    );
  }

  /// Wrapper cho MaterialPageRoute với iOS transition
  static Route<T> iOSRoute<T>({
    required Widget page,
    required RouteSettings settings,
    Duration? duration,
  }) {
    return IOSPageRoute<T>(
      child: page,
      settings: settings,
      transitionDuration: duration ?? const Duration(milliseconds: 300),
    );
  }
}

/// Mixin để dễ dàng áp dụng iOS transitions cho các route
mixin IOSRouteMixin {
  Route<T> createIOSRoute<T>(Widget page, RouteSettings settings) {
    return IOSRouteGenerator.iOSRoute<T>(
      page: page,
      settings: settings,
    );
  }
}