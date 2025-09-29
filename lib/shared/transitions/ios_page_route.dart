import 'package:flutter/material.dart';

/// iOS-style page transition với parallax effect
/// Trang hiện tại trượt sang trái với parallax (chậm hơn)
/// Trang mới slide từ phải vào với hiệu ứng mượt mà
class IOSPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Duration transitionDuration;
  final Curve curve;
  final double parallaxFactor;
  final double overlayOpacity;

  IOSPageRoute({
    required this.child,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.parallaxFactor = 0.3, // Trang hiện tại di chuyển 30% so với trang mới
    this.overlayOpacity = 0.1, // Độ tối của overlay
    RouteSettings? settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          settings: settings,
          transitionDuration: transitionDuration,
          reverseTransitionDuration: transitionDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              context,
              animation,
              secondaryAnimation,
              child,
              curve,
              parallaxFactor,
              overlayOpacity,
            );
          },
        );

  static Widget _buildTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    Curve curve,
    double parallaxFactor,
    double overlayOpacity,
  ) {
    // Animation cho trang mới (slide từ phải)
    const newPageBegin = Offset(1.0, 0.0);
    const newPageEnd = Offset.zero;

    var newPageTween = Tween(begin: newPageBegin, end: newPageEnd).chain(
      CurveTween(curve: curve),
    );

    // Animation cho trang hiện tại (parallax effect)
    var currentPageTween = Tween(
      begin: Offset.zero,
      end: Offset(-parallaxFactor, 0.0),
    ).chain(
      CurveTween(curve: curve),
    );

    // Animation cho reverse (khi back)
    var reversePageTween = Tween(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).chain(
      CurveTween(curve: curve),
    );

    // Xử lý cả forward và reverse animation
    return Stack(
      children: [
        // Trang phía sau (current page khi forward, previous page khi reverse)
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          SlideTransition(
            position: secondaryAnimation.drive(currentPageTween),
            child: Container(
              color: Colors.black.withValues(alpha: overlayOpacity * secondaryAnimation.value),
            ),
          ),

        // Trang mới
        SlideTransition(
          position: animation.drive(
            secondaryAnimation.status != AnimationStatus.dismissed
                ? reversePageTween  // Khi back từ trang khác
                : newPageTween,     // Khi push trang mới
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Extension để dễ sử dụng
extension IOSNavigation on NavigatorState {
  /// Push với iOS-style transition
  Future<T?> pushiOS<T>(Widget page, {RouteSettings? settings}) {
    return push<T>(IOSPageRoute<T>(child: page, settings: settings));
  }

  /// Push named với iOS-style transition
  Future<T?> pushNamediOS<T>(String routeName, {Object? arguments}) {
    return pushNamed<T>(routeName, arguments: arguments);
  }
}

/// Extension cho BuildContext để dễ sử dụng
extension IOSNavigationContext on BuildContext {
  /// Push với iOS-style transition
  Future<T?> pushiOS<T>(Widget page) {
    return Navigator.of(this).pushiOS<T>(page);
  }

  /// Push named với iOS-style transition (cần config trong router)
  Future<T?> pushNamediOS<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }
}