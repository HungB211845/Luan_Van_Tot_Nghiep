import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom CupertinoPageScaffold với AgriPOS green theme
/// Provide consistent iOS-style experience cho toàn bộ app
class AgriCupertinoPageScaffold extends StatelessWidget {
  final Widget child;
  final ObstructingPreferredSizeWidget? navigationBar;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const AgriCupertinoPageScaffold({
    Key? key,
    required this.child,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: navigationBar,
      backgroundColor: backgroundColor ?? CupertinoColors.systemGroupedBackground,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: child,
    );
  }
}

/// Custom CupertinoNavigationBar với AgriPOS styling
class AgriCupertinoNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  final Widget? leading;
  final Widget middle;
  final Widget? trailing;
  final bool automaticallyImplyLeading;
  final String? previousPageTitle;
  final Color? backgroundColor;
  final Brightness? brightness;
  final EdgeInsetsDirectional? padding;
  final bool transitionBetweenRoutes;

  const AgriCupertinoNavigationBar({
    Key? key,
    this.leading,
    required this.middle,
    this.trailing,
    this.automaticallyImplyLeading = true,
    this.previousPageTitle,
    this.backgroundColor,
    this.brightness,
    this.padding,
    this.transitionBetweenRoutes = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoNavigationBar(
      leading: leading,
      middle: DefaultTextStyle(
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 17.0,
          fontWeight: FontWeight.w600,
        ),
        child: middle,
      ),
      trailing: trailing,
      automaticallyImplyLeading: automaticallyImplyLeading,
      previousPageTitle: previousPageTitle,
      backgroundColor: backgroundColor ?? Colors.green,
      brightness: brightness ?? Brightness.dark,
      padding: padding,
      transitionBetweenRoutes: transitionBetweenRoutes,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(44.0);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;
}

/// iOS-style back button với custom styling
class AgriCupertinoBackButton extends StatelessWidget {
  final String? previousPageTitle;
  final VoidCallback? onPressed;
  final Color? color;

  const AgriCupertinoBackButton({
    Key? key,
    this.previousPageTitle,
    this.onPressed,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.chevron_left,
            size: 24.0,
            color: color ?? CupertinoColors.white,
          ),
          if (previousPageTitle != null) ...[
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                previousPageTitle!,
                style: TextStyle(
                  color: color ?? CupertinoColors.white,
                  fontSize: 17.0,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Utility class cho consistent theming với existing project
class AgriCupertinoTheme {
  // Match với Colors.green trong home screen
  static const Color primaryGreen = Colors.green;
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color orange = Colors.orange;

  /// Get CupertinoThemeData với AgriPOS colors
  static CupertinoThemeData get themeData {
    return const CupertinoThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      barBackgroundColor: primaryGreen,
      textTheme: CupertinoTextThemeData(
        primaryColor: CupertinoColors.label,
        textStyle: TextStyle(
          fontFamily: '.SF Pro Text',
          fontSize: 17.0,
          letterSpacing: -0.41,
        ),
      ),
    );
  }

  /// Navigation bar height constant
  static const double navigationBarHeight = 44.0;

  /// Status bar height (for safe area calculation)
  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Total top safe area (status bar + nav bar)
  static double getTotalTopHeight(BuildContext context) {
    return getStatusBarHeight(context) + navigationBarHeight;
  }
}