import 'package:flutter/cupertino.dart';

/// Enhanced CupertinoPageRoute với custom configurations
/// Provide consistent iOS-style navigation cho toàn bộ AgriPOS app
class AgriCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  AgriCupertinoPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    String? title,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) : super(
          builder: builder,
          settings: settings,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
          title: title,
        );

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Material to Cupertino transition wrapper
/// Automatically wrap Material widgets trong CupertinoApp context
class CupertinoMaterialWrapper extends StatelessWidget {
  final Widget child;
  final bool usesMaterialScaffold;

  const CupertinoMaterialWrapper({
    Key? key,
    required this.child,
    this.usesMaterialScaffold = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (usesMaterialScaffold) {
      // Wrap Material Scaffold với Cupertino theming
      return CupertinoTheme(
        data: const CupertinoThemeData(
          primaryColor: Color(0xFF2E7D32),
        ),
        child: child,
      );
    }
    return child;
  }
}

/// Page transition helper functions
class AgriTransitions {
  /// Create iOS-style route từ Widget
  static Route<T> iOSRoute<T>(Widget page, {RouteSettings? settings}) {
    return AgriCupertinoPageRoute<T>(
      builder: (_) => page,
      settings: settings,
    );
  }

  /// Create modal route (full screen dialog)
  static Route<T> modalRoute<T>(Widget page, {RouteSettings? settings}) {
    return AgriCupertinoPageRoute<T>(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: true,
    );
  }

  /// Create material route wrapped trong Cupertino context (cho backward compatibility)
  static Route<T> materialToCupertino<T>(Widget page, {RouteSettings? settings}) {
    return AgriCupertinoPageRoute<T>(
      builder: (_) => CupertinoMaterialWrapper(
        usesMaterialScaffold: true,
        child: page,
      ),
      settings: settings,
    );
  }
}

/// Navigation extensions cho easy usage
extension AgriNavigation on NavigatorState {
  /// Push với iOS-style transition
  Future<T?> pushiOS<T>(Widget page, {RouteSettings? settings}) {
    return push<T>(AgriTransitions.iOSRoute<T>(page, settings: settings));
  }

  /// Push modal với full screen dialog
  Future<T?> pushModal<T>(Widget page, {RouteSettings? settings}) {
    return push<T>(AgriTransitions.modalRoute<T>(page, settings: settings));
  }

  /// Push Material page với Cupertino wrapper
  Future<T?> pushMaterialiOS<T>(Widget page, {RouteSettings? settings}) {
    return push<T>(AgriTransitions.materialToCupertino<T>(page, settings: settings));
  }
}

extension AgriNavigationContext on BuildContext {
  /// Push với iOS-style transition
  Future<T?> pushiOS<T>(Widget page) {
    return Navigator.of(this).pushiOS<T>(page);
  }

  /// Push modal với full screen dialog
  Future<T?> pushModal<T>(Widget page) {
    return Navigator.of(this).pushModal<T>(page);
  }

  /// Push Material page với Cupertino wrapper
  Future<T?> pushMaterialiOS<T>(Widget page) {
    return Navigator.of(this).pushMaterialiOS<T>(page);
  }

  /// Pop với haptic feedback
  void popiOS<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }
}