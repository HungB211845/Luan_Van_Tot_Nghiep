// =============================================================================
// BOTTOM NAV BAR COMPONENTS - CÁC COMPONENT BOTTOM NAVIGATION TÁI SỬ DỤNG
// =============================================================================

import 'package:flutter/material.dart';
import '../models/navigation_item.dart';

class CustomBottomNavBar extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double elevation;
  final bool showLabels;

  const CustomBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.elevation = 8,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: elevation,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: showLabels ? 70 : 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              
              return _buildNavItem(item, isSelected, index);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item, bool isSelected, int index) {
    final color = isSelected 
        ? (selectedItemColor ?? Colors.green)
        : (unselectedItemColor ?? Colors.grey);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.enabled ? () => onTap(index) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconWithBadge(item, color, isSelected),
                if (showLabels) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(NavigationItem item, Color color, bool isSelected) {
    final iconData = isSelected && item.activeIcon != null 
        ? item.activeIcon! 
        : item.icon;
    
    final icon = Icon(
      iconData,
      color: color,
      size: isSelected ? 26 : 24,
    );

    if (item.badgeCount == null || item.badgeCount! <= 0) {
      return icon;
    }

    return Badge(
      label: Text(
        item.badgeCount! > 99 ? '99+' : item.badgeCount!.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: Colors.red,
      child: icon,
    );
  }
}

// =============================================================================
// CURVED BOTTOM NAV BAR - BOTTOM NAVIGATION VỚI THIẾT KẾ CONG
// =============================================================================

class CurvedBottomNavBar extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double height;
  final double curveHeight;

  const CurvedBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.height = 70,
    this.curveHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(MediaQuery.of(context).size.width, height),
      painter: CurveNavBarPainter(
        backgroundColor: backgroundColor ?? Colors.white,
        curveHeight: curveHeight,
      ),
      child: SizedBox(
        height: height,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == currentIndex;
                
                return _buildCurvedNavItem(item, isSelected, index);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurvedNavItem(NavigationItem item, bool isSelected, int index) {
    final color = isSelected 
        ? (selectedItemColor ?? Colors.green)
        : (unselectedItemColor ?? Colors.grey);

    return GestureDetector(
      onTap: item.enabled ? () => onTap(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected && item.activeIcon != null ? item.activeIcon! : item.icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 12 : 10,
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CURVE NAV BAR PAINTER - VẼ ĐƯỜNG CONG CHO BOTTOM NAV
// =============================================================================

class CurveNavBarPainter extends CustomPainter {
  final Color backgroundColor;
  final double curveHeight;

  CurveNavBarPainter({
    required this.backgroundColor,
    required this.curveHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Start from top-left
    path.moveTo(0, curveHeight);
    
    // Create a smooth curve at the top
    path.quadraticBezierTo(
      size.width * 0.5, 0,
      size.width, curveHeight,
    );
    
    // Continue to bottom-right
    path.lineTo(size.width, size.height);
    
    // Go to bottom-left
    path.lineTo(0, size.height);
    
    // Close the path
    path.close();

    // Add shadow
    canvas.drawShadow(path, Colors.black26, 8, false);
    
    // Draw the shape
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}

// =============================================================================
// FLOATING BOTTOM NAV BAR - BOTTOM NAVIGATION FLOATING
// =============================================================================

class FloatingBottomNavBar extends StatelessWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final double margin;
  final double borderRadius;

  const FloatingBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.margin = 16,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(margin),
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(borderRadius),
        color: backgroundColor ?? Colors.white,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              
              return _buildFloatingNavItem(item, isSelected, index);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem(NavigationItem item, bool isSelected, int index) {
    final color = isSelected 
        ? (selectedItemColor ?? Colors.green)
        : (unselectedItemColor ?? Colors.grey);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.enabled ? () => onTap(index) : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Icon(
                    isSelected && item.activeIcon != null ? item.activeIcon! : item.icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
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
}
