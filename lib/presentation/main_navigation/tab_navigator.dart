import 'package:flutter/material.dart';

/// Widget quản lý navigation stack riêng cho mỗi tab
/// Mỗi tab có Navigator riêng để giữ state và navigation history
class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget initialScreen;
  final Map<String, WidgetBuilder>? routes;

  const TabNavigator({
    Key? key,
    required this.navigatorKey,
    required this.initialScreen,
    this.routes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        // Root route cho tab này
        if (settings.name == '/') {
          return MaterialPageRoute(
            builder: (context) => initialScreen,
            settings: settings,
          );
        }

        // Custom routes cho tab này (nếu có)
        if (routes != null && routes!.containsKey(settings.name)) {
          return MaterialPageRoute(
            builder: routes![settings.name]!,
            settings: settings,
          );
        }

        // Fallback
        return MaterialPageRoute(
          builder: (context) => initialScreen,
          settings: settings,
        );
      },
    );
  }
}

/// Helper class để quản lý các GlobalKey cho mỗi tab navigator
class TabNavigatorKeys {
  static final home = GlobalKey<NavigatorState>();
  static final transactions = GlobalKey<NavigatorState>();
  static final pos = GlobalKey<NavigatorState>();
  static final products = GlobalKey<NavigatorState>();
  static final profile = GlobalKey<NavigatorState>();

  /// Get navigator key theo tab index
  static GlobalKey<NavigatorState> getKeyForIndex(int index) {
    switch (index) {
      case 0:
        return home;
      case 1:
        return transactions;
      case 2:
        return pos;
      case 3:
        return products;
      case 4:
        return profile;
      default:
        return home;
    }
  }

  /// Pop current tab's navigation stack
  /// Returns true nếu pop được, false nếu đã ở root
  static Future<bool> popCurrentTab(int currentIndex) async {
    final key = getKeyForIndex(currentIndex);
    if (key.currentState?.canPop() ?? false) {
      key.currentState?.pop();
      return true;
    }
    return false;
  }

  /// Reset tab về root screen
  static void resetTab(int index) {
    final key = getKeyForIndex(index);
    key.currentState?.popUntil((route) => route.isFirst);
  }
}