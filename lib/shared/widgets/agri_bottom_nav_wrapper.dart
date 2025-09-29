import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/routing/route_names.dart';
import '../transitions/cupertino_page_scaffold.dart';

/// Wrapper widget cho screens cần bottom navigation
/// Kết hợp Cupertino design với Material bottom navigation
class AgriBottomNavWrapper extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool showBackButton;

  const AgriBottomNavWrapper({
    Key? key,
    required this.child,
    required this.currentRoute,
    required this.title,
    this.leading,
    this.trailing,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AgriCupertinoPageScaffold(
      navigationBar: AgriCupertinoNavigationBar(
        leading: showBackButton
            ? (leading ?? AgriCupertinoBackButton(previousPageTitle: 'Home'))
            : leading,
        middle: Text(title),
        trailing: trailing,
      ),
      child: Stack(
        children: [
          // Main content với padding cho bottom nav
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 80, // Height cho bottom nav + safe area
            child: child,
          ),
          // Bottom navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigation(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              _buildNavItem(
                context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Trang chủ',
                route: RouteNames.home,
                isActive: currentRoute == RouteNames.home,
              ),
              _buildNavItem(
                context,
                icon: Icons.history_outlined,
                activeIcon: Icons.history,
                label: 'Giao dịch',
                route: RouteNames.transactionList,
                isActive: currentRoute == RouteNames.transactionList,
              ),
              _buildNavItem(
                context,
                icon: Icons.point_of_sale_outlined,
                activeIcon: Icons.point_of_sale,
                label: 'Bán hàng',
                route: RouteNames.pos,
                isActive: currentRoute == RouteNames.pos,
              ),
              _buildNavItem(
                context,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Sản phẩm',
                route: RouteNames.products,
                isActive: currentRoute == RouteNames.products,
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Tài khoản',
                route: RouteNames.profile,
                isActive: currentRoute == RouteNames.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isActive) {
              _navigateToRoute(context, route);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 24,
                  color: isActive ? AgriCupertinoTheme.primaryGreen : Colors.grey[600],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? AgriCupertinoTheme.primaryGreen : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRoute(BuildContext context, String route) {
    // Handle navigation logic
    switch (route) {
      case RouteNames.home:
        // Pop to main navigation (home screen)
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case RouteNames.pos:
        if (currentRoute != RouteNames.pos) {
          // Pop về home trước rồi push POS để tránh stack issues
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.pos,
            (route) => route.settings.name == RouteNames.home
          );
        }
        break;
      case RouteNames.products:
        if (currentRoute != RouteNames.products) {
          // Pop về home trước rồi push Products để tránh stack issues
          Navigator.of(context).pushNamedAndRemoveUntil(
            RouteNames.products,
            (route) => route.settings.name == RouteNames.home
          );
        }
        break;
      case RouteNames.transactionList:
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.transactionList,
          (route) => route.settings.name == RouteNames.home
        );
        break;
      case RouteNames.profile:
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.profile,
          (route) => route.settings.name == RouteNames.home
        );
        break;
      default:
        Navigator.of(context).pushNamed(route);
        break;
    }
  }
}