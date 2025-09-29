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

// NOTE: Removed global key to fix duplicate GlobalKey issues

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
    const ProductListScreen(),
    const ProfileScreen(),
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
      case RouteNames.products:
        _onTabTapped(3); // Switch to Products tab
        break;
      case RouteNames.profile:
        _onTabTapped(4); // Switch to Profile tab
        break;
      default:
        // For other routes, navigate normally with bottom nav preserved
        Navigator.pushNamed(context, route);
        break;
    }
  }

  // Static method to navigate from anywhere in the app
  static void navigateToTab(BuildContext context, String route) {
    // Fallback to normal navigation since we removed global key
    Navigator.pushNamed(context, route);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
      floatingActionButton: _buildCenterPOSButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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

// Static helper class for navigation
class MainNavigationHelper {
  static void navigateToTab(BuildContext context, String route) {
    // Fallback to normal navigation since we removed global key
    Navigator.pushNamed(context, route);
  }
}