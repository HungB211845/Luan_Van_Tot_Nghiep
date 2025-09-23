// =============================================================================
// CUSTOM APP BAR COMPONENTS - CÁC COMPONENT APPBAR TÁI SỬ DỤNG
// =============================================================================

import 'package:flutter/material.dart';

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String? title;
  final String hintText;
  final Function(String)? onSearchChanged;
  final Function(String)? onSearchSubmitted;
  final VoidCallback? onSearchClear;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool autofocus;

  const SearchAppBar({
    super.key,
    this.title,
    this.hintText = 'Tìm kiếm...',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchClear,
    this.actions,
    this.backgroundColor,
    this.autofocus = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    widget.onSearchClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: widget.backgroundColor ?? Colors.green,
      elevation: 4,
      title: _isSearching ? _buildSearchField() : Text(widget.title ?? ''),
      actions: _isSearching ? _buildSearchActions() : _buildNormalActions(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: widget.autofocus,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
      onChanged: widget.onSearchChanged,
      onSubmitted: widget.onSearchSubmitted,
    );
  }

  List<Widget> _buildSearchActions() {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: _stopSearch,
      ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: _startSearch,
      ),
      ...?widget.actions,
    ];
  }
}

// =============================================================================
// TABBED APP BAR - APP BAR VỚI TABS
// =============================================================================

class TabbedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Tab> tabs;
  final TabController? controller;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;

  const TabbedAppBar({
    super.key,
    this.title,
    required this.tabs,
    this.controller,
    this.backgroundColor,
    this.indicatorColor,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.green,
      elevation: 0,
      title: title != null ? Text(title!) : null,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: TabBar(
        controller: controller,
        tabs: tabs,
        indicatorColor: indicatorColor ?? Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}

// =============================================================================
// ACTION APP BAR - APP BAR VỚI POPUP MENU
// =============================================================================

class ActionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<PopupMenuEntry<String>> menuItems;
  final Function(String)? onMenuSelected;
  final List<Widget>? leadingActions;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;

  const ActionAppBar({
    super.key,
    this.title,
    required this.menuItems,
    this.onMenuSelected,
    this.leadingActions,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? Colors.green,
      elevation: 4,
      title: title != null ? Text(title!) : null,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: [
        ...?leadingActions,
        PopupMenuButton<String>(
          onSelected: onMenuSelected,
          itemBuilder: (context) => menuItems,
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

// =============================================================================
// GRADIENT APP BAR - APP BAR VỚI GRADIENT BACKGROUND
// =============================================================================

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Color> gradientColors;
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double elevation;

  const GradientAppBar({
    super.key,
    this.title,
    required this.gradientColors,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.elevation = 4,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: gradientBegin,
          end: gradientEnd,
        ),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: elevation,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: title != null ? Text(title!) : null,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
      ),
    );
  }
}
