import 'package:flutter/material.dart';
import '../../features/customers/screens/customers/customer_list_screen.dart'; // Cập nhật đường dẫn
import '../../features/products/screens/products/product_list_screen.dart'; // Cập nhật đường dẫn
import '../../features/pos/screens/pos/pos_screen.dart'; // Cập nhật đường dẫn
import '../../features/pos/screens/cart/cart_screen.dart'; // Cập nhật đường dẫn
import '../../features/pos/screens/transaction/transaction_success_screen.dart'; // Cập nhật đường dẫn
import '../../presentation/home/home_screen.dart';
import 'route_names.dart';

class AppRouter {
  static const String home = RouteNames.home;
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
        
      case RouteNames.customers:
        return MaterialPageRoute(builder: (_) => CustomerListScreen());
        
      case RouteNames.products:
        return MaterialPageRoute(builder: (_) => const ProductListScreen());
        
      case RouteNames.pos:
        return MaterialPageRoute(builder: (_) => const POSScreen());

      case RouteNames.cart: // Thêm route cho CartScreen
        return MaterialPageRoute(builder: (_) => const CartScreen());

      case RouteNames.transactionSuccess: // Thêm route cho TransactionSuccessScreen
        final args = settings.arguments as String?; // Lấy transactionId
        return MaterialPageRoute(builder: (_) => TransactionSuccessScreen(transactionId: args!));
        
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}