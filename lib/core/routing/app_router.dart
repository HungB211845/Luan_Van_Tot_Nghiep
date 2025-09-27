import 'package:flutter/material.dart';
import '../../features/customers/screens/customers/customer_list_screen.dart';
import '../../features/products/models/company.dart';
import '../../features/products/models/purchase_order.dart';
import '../../features/products/screens/products/product_list_screen.dart';
import '../../features/products/screens/company/company_list_screen.dart';
import '../../features/products/screens/company/add_edit_company_screen.dart';
import '../../features/products/screens/company/company_detail_screen.dart';
import '../../features/products/screens/purchase_order/create_po_screen.dart';
import '../../features/products/screens/purchase_order/po_list_screen.dart';
import '../../features/products/screens/purchase_order/po_detail_screen.dart';
import '../../features/pos/screens/pos/pos_screen.dart';
import '../../features/pos/screens/cart/cart_screen.dart';
import '../../features/pos/screens/transaction/transaction_success_screen.dart';
import '../../features/pos/screens/transaction/transaction_list_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
// Auth screens
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/biometric_setup_screen.dart';
import '../../features/auth/screens/biometric_login_screen.dart';
import '../../features/auth/screens/store_setup_screen.dart';
import '../../presentation/home/home_screen.dart';
import 'route_names.dart';
import '../../features/products/screens/purchase_order/po_receive_success_screen.dart';
import '../../features/auth/screens/account_screen.dart';

class AppRouter {
  static const String home = RouteNames.home;
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case RouteNames.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case RouteNames.otp:
        return MaterialPageRoute(builder: (_) => const OtpVerificationScreen());
      case RouteNames.biometricLogin:
        return MaterialPageRoute(builder: (_) => const BiometricLoginScreen());
      case RouteNames.storeSetup:
        return MaterialPageRoute(builder: (_) => const StoreSetupScreen());
      // Removed onboarding route (screen not implemented)
      case RouteNames.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case RouteNames.homeAlias:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const AccountScreen());
        
      case RouteNames.customers:
        return MaterialPageRoute(builder: (_) => CustomerListScreen());
        
      case RouteNames.products:
        return MaterialPageRoute(builder: (_) => const ProductListScreen());

      case RouteNames.companies:
        return MaterialPageRoute(builder: (_) => const CompanyListScreen());

      case RouteNames.addCompany:
        return MaterialPageRoute(builder: (_) => const AddEditCompanyScreen());

      case RouteNames.editCompany:
        final company = settings.arguments as Company;
        return MaterialPageRoute(builder: (_) => AddEditCompanyScreen(company: company));

      case RouteNames.companyDetail:
        final company = settings.arguments as Company;
        return MaterialPageRoute(builder: (_) => CompanyDetailScreen(company: company));

      case RouteNames.purchaseOrders:
        return MaterialPageRoute(builder: (_) => const PurchaseOrderListScreen());

      case RouteNames.purchaseOrderDetail:
        final po = settings.arguments as PurchaseOrder;
        return MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrder: po));

      case RouteNames.createPurchaseOrder:
        return MaterialPageRoute(builder: (_) => const CreatePurchaseOrderScreen());
      
      case RouteNames.purchaseOrderReceiveSuccess:
        final poNumber = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => POReceiveSuccessScreen(poNumber: poNumber));
        
      case RouteNames.pos:
        return MaterialPageRoute(builder: (_) => const POSScreen());

      case RouteNames.cart: // Thêm route cho CartScreen
        return MaterialPageRoute(builder: (_) => const CartScreen());

      case RouteNames.transactionSuccess: // Thêm route cho TransactionSuccessScreen
        final args = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => TransactionSuccessScreen(transactionId: args!));

      case RouteNames.transactionList: // Transaction history screen
        return MaterialPageRoute(builder: (_) => const TransactionListScreen());

      case RouteNames.reports:
        return MaterialPageRoute(builder: (_) => const ReportsScreen());
        
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
