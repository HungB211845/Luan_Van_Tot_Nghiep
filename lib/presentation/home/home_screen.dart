import 'package:flutter/material.dart';
import '../../core/routing/route_names.dart';
import '../../shared/widgets/connectivity_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agricultural POS'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Cửa Hàng Nông Nghiệp',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Connectivity status
            const ConnectivityBanner(),
            const SizedBox(height: 30),
            
            // Navigation buttons
            _buildNavigationButton(
              context,
              icon: Icons.point_of_sale,
              label: 'Bán Hàng (POS)',
              route: RouteNames.pos,
              color: Colors.green,
            ),
            const SizedBox(height: 15),
            
            _buildNavigationButton(
              context,
              icon: Icons.people,
              label: 'Quản Lý Khách Hàng',
              route: RouteNames.customers,
              color: Colors.blue,
            ),
            const SizedBox(height: 15),
            
            _buildNavigationButton(
              context,
              icon: Icons.inventory,
              label: 'Quản Lý Sản Phẩm',
              route: RouteNames.products,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}