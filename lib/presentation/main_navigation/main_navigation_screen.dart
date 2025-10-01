import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens for each tab
import '../home/home_screen.dart';
import '../../features/pos/screens/transaction/transaction_list_screen.dart';
import '../../features/pos/screens/pos/pos_screen.dart';
import '../../features/auth/screens/profile/profile_screen.dart';
import '../../features/products/screens/products/product_list_screen.dart';

// Providers
import '../../features/pos/providers/transaction_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../features/products/providers/product_edit_mode_provider.dart';

// Tab Navigator
import 'tab_navigator.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

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
    // Initialize providers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  Future<bool> _onWillPop() async {
    final key = _navigatorKeys[_currentIndex];
    if (key.currentState?.canPop() ?? false) {
      key.currentState?.pop();
      return false; // Don't exit app
    }
    return true; // Exit app
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      // If tapping the current tab, pop to the first route
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      // Switch to the new tab
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductEditModeProvider>(
      builder: (context, editModeProvider, child) {
        final hideBottomNav = editModeProvider.isEditMode;

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: <Widget>[
                _buildOffstageNavigator(0, const HomeScreen()),
                _buildOffstageNavigator(1, const TransactionListScreen()),
                _buildOffstageNavigator(2, const POSScreen()),
                _buildOffstageNavigator(3, const ProductListScreen()),
                _buildOffstageNavigator(4, const ProfileScreen()),
              ],
            ),
            bottomNavigationBar: hideBottomNav ? null : _buildFlatIOSBottomNav(),
          ),
        );
      },
    );
  }

  Widget _buildOffstageNavigator(int index, Widget initialScreen) {
    return Offstage(
      offstage: _currentIndex != index,
      child: TabNavigator(
        navigatorKey: _navigatorKeys[index],
        initialScreen: initialScreen,
      ),
    );
  }

  Widget _buildFlatIOSBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        
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
