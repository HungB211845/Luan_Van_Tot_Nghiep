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
  int _previousIndex = 0;

  // Create navigator keys once for the entire lifetime
  late final GlobalKey<NavigatorState> _homeKey;
  late final GlobalKey<NavigatorState> _transactionsKey;
  late final GlobalKey<NavigatorState> _posKey;
  late final GlobalKey<NavigatorState> _productsKey;
  late final GlobalKey<NavigatorState> _profileKey;

  @override
  void initState() {
    super.initState();

    // Initialize navigator keys once
    _homeKey = GlobalKey<NavigatorState>(debugLabel: 'HomeNavigator');
    _transactionsKey = GlobalKey<NavigatorState>(debugLabel: 'TransactionsNavigator');
    _posKey = GlobalKey<NavigatorState>(debugLabel: 'POSNavigator');
    _productsKey = GlobalKey<NavigatorState>(debugLabel: 'ProductsNavigator');
    _profileKey = GlobalKey<NavigatorState>(debugLabel: 'ProfileNavigator');

    // Initialize providers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  /// Get navigator key by index
  GlobalKey<NavigatorState> _getKeyForIndex(int index) {
    switch (index) {
      case 0: return _homeKey;
      case 1: return _transactionsKey;
      case 2: return _posKey;
      case 3: return _productsKey;
      case 4: return _profileKey;
      default: return _homeKey;
    }
  }

  /// Handle back button - pop current tab's navigation stack
  Future<bool> _onWillPop() async {
    final key = _getKeyForIndex(_currentIndex);
    if (key.currentState?.canPop() ?? false) {
      key.currentState?.pop();
      return false; // Don't exit app
    }
    return true; // Exit app
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      // Tap vào tab hiện tại → reset về root của tab đó
      final key = _getKeyForIndex(index);
      key.currentState?.popUntil((route) => route.isFirst);
    } else {
      // Switch sang tab khác
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });

      // Refresh data when switching to transaction tab
      if (index == 1) {
        context.read<TransactionProvider>().refresh();
      }
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
              children: [
                // Tab 0: Home với nested navigator
                TabNavigator(
                  navigatorKey: _homeKey,
                  initialScreen: const HomeScreen(),
                ),

                // Tab 1: Transactions với nested navigator
                TabNavigator(
                  navigatorKey: _transactionsKey,
                  initialScreen: const TransactionListScreen(),
                ),

                // Tab 2: POS (standalone - fullscreen)
                TabNavigator(
                  navigatorKey: _posKey,
                  initialScreen: const POSScreen(),
                ),

                // Tab 3: Products với nested navigator
                TabNavigator(
                  navigatorKey: _productsKey,
                  initialScreen: const ProductListScreen(),
                ),

                // Tab 4: Profile với nested navigator
                TabNavigator(
                  navigatorKey: _profileKey,
                  initialScreen: const ProfileScreen(),
                ),
              ],
            ),
            bottomNavigationBar: hideBottomNav ? null : _buildCustomBottomNav(),
            floatingActionButton: hideBottomNav ? null : _buildCenterPOSButton(),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          ),
        );
      },
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, Icons.home, 'Trang chủ'),
          _buildNavItem(1, Icons.history_outlined, Icons.history, 'Giao dịch'),
          const SizedBox(width: 60), // Space cho center button
          _buildNavItem(3, Icons.inventory_2_outlined, Icons.inventory_2, 'Sản phẩm'),
          _buildNavItem(4, Icons.person_outline, Icons.person, 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 24,
                color: isActive ? Colors.green : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.green : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPOSButton() {
    final isActive = _currentIndex == 2;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(35),
          onTap: () => _onTabTapped(2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.point_of_sale,
                size: 28,
                color: Colors.white,
              ),
              const SizedBox(height: 2),
              Text(
                'Bán hàng',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static helper class để navigate từ bất kỳ đâu trong app
class MainNavigationHelper {
  /// Switch đến tab cụ thể từ bất kỳ context nào
  static void switchToTab(BuildContext context, int tabIndex) {
    // Find MainNavigationScreen trong widget tree và trigger tab change
    // Vì ta đang dùng nested navigator, cần pop về root trước
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      return route.settings.name == '/' || !route.navigator!.canPop();
    });
  }

  /// Navigate đến một screen trong tab hiện tại
  static void navigateInCurrentTab(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Navigate đến một screen và show route name
  static void navigateToRoute(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }
}