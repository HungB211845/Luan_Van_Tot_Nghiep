// =============================================================================
// FAB MANAGER - QUẢN LÝ FLOATING ACTION BUTTON THEO CONTEXT
// =============================================================================

import 'package:flutter/material.dart';
import '../models/layout_config.dart';

class FABManager {
  static Widget? buildFAB(
    LayoutConfig config,
    BuildContext context, {
    VoidCallback? onPressed,
  }) {
    if (config.fabType == FABType.none) return null;

    final action = onPressed ?? config.fabAction;
    if (action == null) return null;

    switch (config.fabType) {
      case FABType.standard:
        return _buildStandardFAB(config, action);

      case FABType.extended:
        return _buildExtendedFAB(config, action);

      case FABType.mini:
        return _buildMiniFAB(config, action);

      case FABType.none:
        return null;
    }
  }

  static FloatingActionButton _buildStandardFAB(
    LayoutConfig config,
    VoidCallback onPressed,
  ) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      elevation: 6,
      child: Icon(
        config.fabIcon ?? Icons.add,
        size: 24,
      ),
    );
  }

  static Widget _buildExtendedFAB(
    LayoutConfig config,
    VoidCallback onPressed,
  ) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: Icon(
        config.fabIcon ?? Icons.add,
        size: 20,
      ),
      label: Text(
        config.fabLabel ?? 'Thêm mới',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  static FloatingActionButton _buildMiniFAB(
    LayoutConfig config,
    VoidCallback onPressed,
  ) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      elevation: 4,
      mini: true,
      child: Icon(
        config.fabIcon ?? Icons.add,
        size: 20,
      ),
    );
  }

  // FAB LOCATION MANAGEMENT
  static FloatingActionButtonLocation getFABLocation(LayoutConfig config) {
    switch (config.fabType) {
      case FABType.mini:
        return FloatingActionButtonLocation.miniEndFloat;
      case FABType.extended:
        return FloatingActionButtonLocation.centerFloat;
      case FABType.standard:
      default:
        return FloatingActionButtonLocation.endFloat;
    }
  }

  // HELPER METHODS FOR SPECIAL FAB BEHAVIORS

  static Widget buildSpeedDial({
    required BuildContext context,
    required List<SpeedDialChild> children,
    IconData? icon,
    String? tooltip,
    Color? backgroundColor,
  }) {
    return SpeedDial(
      icon: icon ?? Icons.add,
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? Colors.green,
      foregroundColor: Colors.white,
      children: children,
    );
  }

  static Widget buildAnimatedFAB({
    required BuildContext context,
    required VoidCallback onPressed,
    required Animation<double> animation,
    IconData? icon,
    String? label,
  }) {
    return ScaleTransition(
      scale: animation,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: Icon(icon ?? Icons.add),
        label: Text(label ?? 'Thêm mới'),
      ),
    );
  }
}

// =============================================================================
// SPEED DIAL IMPLEMENTATION - CHO MULTIPLE ACTIONS
// =============================================================================

class SpeedDial extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<SpeedDialChild> children;

  const SpeedDial({
    super.key,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    required this.children,
  });

  @override
  State<SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<SpeedDial>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ...widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child_widget) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 8,
                    right: index % 2 == 0 ? 0 : 72,
                  ),
                  child: _buildSpeedDialChild(child),
                ),
              );
            },
          );
        }).toList(),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 3.14159, // π radians = 180°
              child: FloatingActionButton(
                onPressed: _toggle,
                backgroundColor: widget.backgroundColor ?? Colors.green,
                foregroundColor: widget.foregroundColor ?? Colors.white,
                tooltip: widget.tooltip,
                child: Icon(_isOpen ? Icons.close : widget.icon),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSpeedDialChild(SpeedDialChild child) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (child.label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              child.label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        FloatingActionButton(
          onPressed: () {
            _toggle();
            child.onPressed();
          },
          backgroundColor: child.backgroundColor ?? Colors.white,
          foregroundColor: child.foregroundColor ?? Colors.green,
          mini: true,
          child: Icon(child.icon),
        ),
      ],
    );
  }
}

class SpeedDialChild {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDialChild({
    required this.icon,
    this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });
}