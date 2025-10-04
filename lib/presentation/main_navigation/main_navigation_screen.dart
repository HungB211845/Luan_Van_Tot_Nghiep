import 'package:agricultural_pos/features/auth/models/auth_state.dart';
import 'package:agricultural_pos/features/auth/providers/auth_provider.dart';
import 'package:agricultural_pos/features/auth/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

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

// Tab Navigator + Responsive
import 'tab_navigator.dart';
import '../../shared/utils/responsive.dart';

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



        return WillPopScope(
          onWillPop: _onWillPop,
          child: context.adaptiveWidget(
            mobile: _buildMobileLayout(currentIndex, navigationProvider, hideBottomNav),
            tablet: _buildMobileLayout(currentIndex, navigationProvider, hideBottomNav),
            desktop: _buildDesktopLayout(currentIndex, navigationProvider),
          ),
        );
      },
    );
  }

  Widget _buildOffstageNavigator(int index, Widget initialScreen, int currentIndex) {
    return Offstage(
      offstage: currentIndex != index,
      child: TabNavigator(
        navigatorKey: _navigatorKeys[index],
        initialScreen: initialScreen,
      ),
    );
  }

  Widget _buildFlatIOSBottomNav(int currentIndex, NavigationProvider navigationProvider) {
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
  
  // 🎯 RESPONSIVE LAYOUTS
  
  Widget _buildMobileLayout(int currentIndex, NavigationProvider navigationProvider, bool hideBottomNav) {
    return Scaffold(
      body: _buildIndexedStack(currentIndex),
      bottomNavigationBar: hideBottomNav ? null : _buildFlatIOSBottomNav(currentIndex, navigationProvider),
    );
  }
  
  Widget _buildDesktopLayout(int currentIndex, NavigationProvider navigationProvider) {
    return Scaffold(
      body: Column(
        children: [
          _buildWebHeaderNavigation(currentIndex, navigationProvider),
          Expanded(child: _buildIndexedStack(currentIndex)),
        ],
      ),
    );
  }
  
  Widget _buildIndexedStack(int currentIndex) {
    return IndexedStack(
      index: currentIndex,
      children: <Widget>[
        _buildOffstageNavigator(0, const HomeScreen(), currentIndex),
        _buildOffstageNavigator(1, const TransactionListScreen(), currentIndex),
        _buildOffstageNavigator(2, const POSScreen(), currentIndex),
        _buildOffstageNavigator(3, const ProductListScreen(), currentIndex),
        _buildOffstageNavigator(4, const ProfileScreen(), currentIndex),
      ],
    );
  }
  
  Widget _buildSideNavigation(int currentIndex, NavigationProvider navigationProvider, {bool isDesktop = false}) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: isDesktop ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ] : null,
        border: !isDesktop ? Border(right: BorderSide(color: Colors.grey[300]!)) : null,
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green,
              border: Border(bottom: BorderSide(color: Colors.green[700]!)),
            ),
            child: const Center(
              child: Text(
                'Agricultural POS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSideNavItem(0, Icons.home, 'Trang chủ', currentIndex, navigationProvider),
                _buildSideNavItem(1, Icons.receipt_long, 'Giao dịch', currentIndex, navigationProvider),
                _buildSideNavItem(2, Icons.point_of_sale, 'Bán hàng', currentIndex, navigationProvider),
                _buildSideNavItem(3, Icons.inventory_2, 'Sản phẩm', currentIndex, navigationProvider),
                _buildSideNavItem(4, Icons.account_circle, 'Tài khoản', currentIndex, navigationProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSideNavItem(int index, IconData icon, String title, int currentIndex, NavigationProvider navigationProvider) {
    final isSelected = index == currentIndex;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navigationProvider.changeTab(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.green : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeaderNavigation(int currentIndex, NavigationProvider navigationProvider) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo/Brand
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.agriculture, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Agricultural POS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Navigation Items
          Expanded(
            child: Row(
              children: [
                _buildHeaderNavItem(0, Icons.home, 'Trang chủ', currentIndex, navigationProvider),
                _buildHeaderNavItem(1, Icons.receipt_long, 'Giao dịch', currentIndex, navigationProvider),
                _buildHeaderNavItem(2, Icons.point_of_sale, 'Bán hàng', currentIndex, navigationProvider),
                _buildHeaderNavItem(3, Icons.inventory_2, 'Sản phẩm', currentIndex, navigationProvider),
                _buildHeaderNavItem(4, Icons.account_circle, 'Tài khoản', currentIndex, navigationProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderNavItem(int index, IconData icon, String title, int currentIndex, NavigationProvider navigationProvider) {
    final isSelected = index == currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => navigationProvider.changeTab(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: Colors.green.withOpacity(0.3)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.green : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
