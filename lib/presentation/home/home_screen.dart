import 'package:flutter/material.dart';
import '../../core/routing/route_names.dart';
import '../../shared/widgets/connectivity_banner.dart';
import '../../features/products/screens/products/product_list_screen.dart';
import '../../features/customers/screens/customers/customer_list_screen.dart';
import '../../features/products/screens/company/company_list_screen.dart';
import '../../features/products/screens/purchase_order/po_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleFeatureNavigation(BuildContext context, String route) {
    // Navigate using root navigator for full-screen (no bottom nav)
    switch (route) {
      case RouteNames.products:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => const ProductListScreen()),
        );
        break;
      case RouteNames.customers:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => CustomerListScreen()),
        );
        break;
      case RouteNames.companies:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => const CompanyListScreen()),
        );
        break;
      case RouteNames.purchaseOrders:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => PurchaseOrderListScreen()),
        );
        break;
      case '/reports':
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => ReportsScreen()),
        );
        break;
      default:
        // Các routes khác (POS, Profile, Transaction) là tabs
        // Show snackbar hướng dẫn dùng bottom nav
        final tabNames = {
          RouteNames.pos: 'Bán Hàng',
          RouteNames.profile: 'Tài khoản',
          RouteNames.transactionList: 'Giao Dịch',
        };
        if (tabNames.containsKey(route)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dùng thanh điều hướng bên dưới để chuyển đến ${tabNames[route]}'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa Hàng Nông Nghiệp'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button since this is a tab
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Connectivity status
            const ConnectivityBanner(),
            const SizedBox(height: 30),
            
            // Navigation cards - sử dụng Expanded để tránh overflow
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.point_of_sale,
                    title: 'Bán Hàng',
                    subtitle: 'POS System',
                    route: RouteNames.pos,
                    color: Colors.green,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.inventory,
                    title: 'Sản Phẩm',
                    subtitle: 'Kho hàng',
                    route: RouteNames.products,
                    color: Colors.orange,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.people,
                    title: 'Khách Hàng',
                    subtitle: 'Quản lý KH',
                    route: RouteNames.customers,
                    color: Colors.blue,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.business,
                    title: 'Nhà Cung Cấp',
                    subtitle: 'Quản lý NCC',
                    route: RouteNames.companies,
                    color: Colors.teal,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.receipt_long,
                    title: 'Đơn Nhập Hàng',
                    subtitle: 'Nhập kho',
                    route: RouteNames.purchaseOrders,
                    color: Colors.indigo,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.history,
                    title: 'Lịch Sử Giao Dịch',
                    subtitle: 'Xem giao dịch POS',
                    route: RouteNames.transactionList,
                    color: Colors.deepOrange,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.analytics,
                    title: 'Báo Cáo',
                    subtitle: 'Thống kê',
                    route: '/reports', // Add this route later
                    color: Colors.purple,
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.person,
                    title: 'Tài khoản',
                    subtitle: 'Quản lý tài khoản',
                    route: RouteNames.profile,
                    color: Colors.brown,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _handleFeatureNavigation(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
