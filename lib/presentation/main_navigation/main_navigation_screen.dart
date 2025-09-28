import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens for each tab
import '../home/home_screen.dart';
import '../../features/pos/screens/transaction/transaction_list_screen.dart';
import '../../features/pos/screens/pos/pos_screen.dart';
import '../../features/auth/screens/profile/profile_screen.dart';

// Additional screens for feature cards
import '../../features/products/screens/products/product_list_screen.dart';
import '../../features/customers/screens/customers/customer_list_screen.dart';
import '../../features/products/screens/company/company_list_screen.dart';
import '../../features/products/screens/purchase_order/po_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';

// Providers
import '../../features/pos/providers/transaction_provider.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../core/routing/route_names.dart';

// Global key to control navigation from outside
final GlobalKey<_MainNavigationScreenState> mainNavigationKey = GlobalKey<_MainNavigationScreenState>();

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TransactionListScreen(),
    const POSScreen(),
    const ProfileScreen(),
  ];

  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Trang chủ',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.history_outlined),
      activeIcon: Icon(Icons.history),
      label: 'Giao dịch',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.point_of_sale_outlined),
      activeIcon: Icon(Icons.point_of_sale),
      label: 'Bán hàng',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Tài khoản',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize providers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load initial data for transaction screen
      context.read<TransactionProvider>().loadTransactions();
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Refresh data when switching to transaction tab
    if (index == 1) {
      context.read<TransactionProvider>().refresh();
    }
  }

  // Method to handle feature card navigation
  void navigateToFeature(String route) {
    switch (route) {
      case RouteNames.pos:
        _onTabTapped(2); // Switch to POS tab
        break;
      case RouteNames.transactionList:
        _onTabTapped(1); // Switch to Transaction tab
        break;
      case RouteNames.profile:
        _onTabTapped(3); // Switch to Profile tab
        break;
      default:
        // For other routes, navigate normally with bottom nav preserved
        Navigator.pushNamed(context, route);
        break;
    }
  }

  // Static method to navigate from anywhere in the app
  static void navigateToTab(BuildContext context, String route) {
    final mainNav = mainNavigationKey.currentState;
    if (mainNav != null) {
      mainNav.navigateToFeature(route);
    } else {
      // Fallback to normal navigation
      Navigator.pushNamed(context, route);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          items: _navItems,
        ),
      ),
    );
  }
}

// Static helper class for navigation
class MainNavigationHelper {
  static void navigateToTab(BuildContext context, String route) {
    final mainNav = mainNavigationKey.currentState;
    if (mainNav != null) {
      mainNav.navigateToFeature(route);
    } else {
      // Fallback to normal navigation
      Navigator.pushNamed(context, route);
    }
  }
}