import 'package:agricultural_pos/features/auth/models/auth_state.dart';
import 'package:agricultural_pos/features/auth/providers/auth_provider.dart';
import 'package:agricultural_pos/features/auth/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
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

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            body: IndexedStack(
              index: currentIndex,
              children: <Widget>[
                _buildOffstageNavigator(0, const HomeScreen(), currentIndex),
                _buildOffstageNavigator(1, const TransactionListScreen(), currentIndex),
                _buildOffstageNavigator(2, const POSScreen(), currentIndex),
                _buildOffstageNavigator(3, const ProductListScreen(), currentIndex),
                _buildOffstageNavigator(4, const ProfileScreen(), currentIndex),
              ],
            ),
            bottomNavigationBar: hideBottomNav ? null : _buildFlatIOSBottomNav(currentIndex, navigationProvider),
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
}
