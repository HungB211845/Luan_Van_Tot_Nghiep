import 'package:agricultural_pos/features/auth/models/auth_state.dart';
import 'package:agricultural_pos/features/auth/providers/auth_provider.dart';
import 'package:agricultural_pos/features/auth/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agricultural_pos/shared/utils/responsive.dart';
import 'package:agricultural_pos/shared/layout/models/navigation_item.dart';

// Screens for each tab
import '../../core/routing/route_names.dart';
import '../home/home_screen.dart';
import '../../features/pos/screens/transaction/transaction_list_screen.dart';
import '../../features/pos/screens/pos/pos_screen.dart';
import '../../features/auth/screens/profile/profile_screen.dart';
import '../../features/products/screens/products/product_list_screen.dart';

// Providers
import '../../features/pos/providers/transaction_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../features/products/providers/product_edit_mode_provider.dart';
import '../../core/providers/navigation_provider.dart';

// Tab Navigator
import 'tab_navigator.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final AuthProvider _authProvider;

  // Navigator keys to maintain state for each tab
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(debugLabel: 'HomeNavigator'),
    GlobalKey<NavigatorState>(debugLabel: 'TransactionsNavigator'),
    GlobalKey<NavigatorState>(debugLabel: 'POSNavigator'),
    GlobalKey<NavigatorState>(debugLabel: 'ProductsNavigator'),
    GlobalKey<NavigatorState>(debugLabel: 'ProfileNavigator'),
  ];

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthStateChanged);

    // Initialize providers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (!mounted) return;

    if (_authProvider.state.status == AuthStatus.unauthenticated) {
      // Use a post-frame callback to avoid trying to navigate during a build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final storeCode = await SecureStorageService().getLastStoreCode();
        if (!mounted) return;

        final route = (storeCode == null || storeCode.isEmpty)
            ? RouteNames.storeCode
            : RouteNames.login;

        Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
      });
    }
  }

  Future<bool> _onWillPop() async {
    final navigationProvider = context.read<NavigationProvider>();
    final key = _navigatorKeys[navigationProvider.currentIndex];
    if (key.currentState?.canPop() ?? false) {
      key.currentState?.pop();
      return false; // Don't exit app
    }
    return true; // Exit app
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductEditModeProvider, NavigationProvider>(
      builder: (context, editModeProvider, navigationProvider, child) {
        final hideBottomNav = editModeProvider.isEditMode;
        final currentIndex = navigationProvider.currentIndex;
        final size = MediaQuery.of(context).size;
        final deviceType = ResponsiveBreakpoints.getDeviceType(size.width);
        final isDesktopShell = deviceType == ResponsiveDeviceType.desktop;

        return WillPopScope(
          onWillPop: _onWillPop,
          child: isDesktopShell
              ? _buildDesktopScaffold(currentIndex, navigationProvider)
              : Scaffold(
                  body: IndexedStack(
                    index: currentIndex,
                    children: <Widget>[
                      _buildOffstageNavigator(0, const HomeScreen(), currentIndex),
                      _buildOffstageNavigator(
                        1,
                        const TransactionListScreen(),
                        currentIndex,
                      ),
                      _buildOffstageNavigator(2, const POSScreen(), currentIndex),
                      _buildOffstageNavigator(
                        3,
                        const ProductListScreen(),
                        currentIndex,
                      ),
                      _buildOffstageNavigator(4, const ProfileScreen(), currentIndex),
                    ],
                  ),
                  bottomNavigationBar: hideBottomNav
                      ? null
                      : _buildFlatIOSBottomNav(currentIndex, navigationProvider),
                ),
        );
      },
    );
  }

  Widget _buildOffstageNavigator(
    int index,
    Widget initialScreen,
    int currentIndex,
  ) {
    return Offstage(
      offstage: currentIndex != index,
      child: TabNavigator(
        navigatorKey: _navigatorKeys[index],
        initialScreen: initialScreen,
      ),
    );
  }

  Widget _buildFlatIOSBottomNav(
    int currentIndex,
    NavigationProvider navigationProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => navigationProvider.changeTab(index),

        // iOS-style configuration
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey[600],
        elevation: 0,
        selectedFontSize: 10,
        unselectedFontSize: 10,

        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Giao dịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Bán hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Sản phẩm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopScaffold(
    int currentIndex,
    NavigationProvider navigationProvider,
  ) {
    return Scaffold(
      body: Column(
        children: [
          // Top navigation (no AppBar)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              
              return Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // App title / brand
                        const Icon(Icons.agriculture, color: Colors.green),
                        const SizedBox(width: 8),
                        if (!isNarrow) const Text(
                          'Agricultural POS',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 24),
                        // Horizontal nav buttons (hide labels on narrow screens)
                        ..._desktopNavItems().asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final bool selected = index == currentIndex;
                          
                          if (isNarrow) {
                            // Icon only on narrow screens
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: IconButton(
                                onPressed: () => navigationProvider.changeTab(index),
                                icon: Icon(
                                  selected ? (item.activeIcon ?? item.icon) : item.icon,
                                  color: selected ? Colors.green : Colors.grey[700],
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: selected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                                ),
                              ),
                            );
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextButton.icon(
                              onPressed: () => navigationProvider.changeTab(index),
                              icon: Icon(
                                selected ? (item.activeIcon ?? item.icon) : item.icon,
                                color: selected ? Colors.green : Colors.grey[700],
                              ),
                              label: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected ? Colors.green : Colors.grey[800],
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.green,
                                backgroundColor: selected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          );
                        }).toList(),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Content
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: <Widget>[
                _buildOffstageNavigator(0, const HomeScreen(), currentIndex),
                _buildOffstageNavigator(
                  1,
                  const TransactionListScreen(),
                  currentIndex,
                ),
                _buildOffstageNavigator(2, const POSScreen(), currentIndex),
                _buildOffstageNavigator(
                  3,
                  const ProductListScreen(),
                  currentIndex,
                ),
                _buildOffstageNavigator(4, const ProfileScreen(), currentIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Trang chủ';
      case 1:
        return 'Giao dịch';
      case 2:
        return 'Bán hàng';
      case 3:
        return 'Sản phẩm';
      case 4:
        return 'Tài khoản';
      default:
        return '';
    }
  }

  List<NavigationItem> _desktopNavItems() {
    return const [
      NavigationItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Trang chủ',
        route: '/',
      ),
      NavigationItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Giao dịch',
        route: '/transactions',
      ),
      NavigationItem(
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        label: 'Bán hàng',
        route: '/pos',
      ),
      NavigationItem(
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        label: 'Sản phẩm',
        route: '/products',
      ),
      NavigationItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Tài khoản',
        route: '/profile',
      ),
    ];
  }
}
