import 'package:flutter/material.dart';
import '../../features/customers/screens/customers/customer_list_screen.dart';
import '../../features/products/models/company.dart';
import '../../features/products/models/purchase_order.dart';
import '../../features/products/models/product.dart';
import '../../features/pos/models/transaction.dart';
import '../../features/customers/models/customer.dart';
import '../../features/products/screens/products/product_list_screen.dart';
import '../../features/products/screens/products/product_detail_screen.dart';
import '../../features/products/screens/products/add_product_step1_screen.dart';
import '../../features/products/screens/products/add_product_step2_screen.dart';
import '../../features/products/screens/products/add_product_step3_screen.dart';
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
// import '../../features/auth/screens/biometric_login_screen.dart'; // File missing
import '../../features/auth/screens/store_setup_screen.dart';
import '../../features/auth/screens/store_code_screen.dart';
import '../../features/auth/screens/signup_step1_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/main_navigation/main_navigation_screen.dart';
import 'route_names.dart';
import '../../features/products/screens/purchase_order/po_receive_success_screen.dart';
import '../../features/auth/screens/account_screen.dart';
import '../../features/auth/screens/profile/profile_screen.dart';
import '../../features/auth/screens/edit_profile_screen.dart';
import '../../features/auth/screens/edit_store_info_screen.dart';
import '../../features/auth/screens/employee_management_screen.dart';
import '../../features/auth/screens/invoice_settings_screen.dart';
import '../../features/auth/screens/change_password_screen.dart';
import '../../shared/transitions/ios_page_route.dart';
import '../../presentation/home/screens/edit_quick_access_screen.dart';
import '../../presentation/home/screens/global_search_screen.dart';
import '../../features/debt/screens/debt_list_screen.dart';
import '../../features/pos/screens/transaction/transaction_detail_screen.dart';
import '../../features/customers/screens/customers/customer_detail_screen.dart';

class AppRouter {
  static const String home = RouteNames.home;

  static Route<dynamic> generateRoute(RouteSettings settings) {
    debugPrint('🔍 ROUTER DEBUG: Generating route for: ${settings.name}');
    switch (settings.name) {
      case RouteNames.splash:
        return IOSPageRoute(child: const SplashScreen(), settings: settings);
      case RouteNames.login:
        return IOSPageRoute(child: const LoginScreen(), settings: settings);
      case RouteNames.storeCode:
        return IOSPageRoute(child: const StoreCodeScreen(), settings: settings);
      case RouteNames.signupStep1:
        return IOSPageRoute(child: const SignupStep1Screen(), settings: settings);
      case RouteNames.forgotPassword:
        return IOSPageRoute(
          child: const ForgotPasswordScreen(),
          settings: settings,
        );
      case RouteNames.otp:
        return IOSPageRoute(
          child: const OtpVerificationScreen(),
          settings: settings,
        );
      case RouteNames.biometricLogin:
        // BiometricLoginScreen removed - redirect to login
        return IOSPageRoute(
          child: const LoginScreen(),
          settings: settings,
        );
      case RouteNames.storeSetup:
        return IOSPageRoute(
          child: const StoreSetupScreen(),
          settings: settings,
        );
      // Removed onboarding route (screen not implemented)
      case RouteNames.home:
        return IOSPageRoute(
          child: const MainNavigationScreen(),
          settings: settings,
        );
      case RouteNames.homeAlias:
        return IOSPageRoute(
          child: const MainNavigationScreen(),
          settings: settings,
        );
      case RouteNames.profile:
        return IOSPageRoute(child: const ProfileScreen(), settings: settings);

      case RouteNames.customers:
        return IOSPageRoute(child: CustomerListScreen(), settings: settings);

      case RouteNames.products:
        return IOSPageRoute(
          child: const ProductListScreen(),
          settings: settings,
        );

      case RouteNames.productDetail:
        return IOSPageRoute(
          child: const ProductDetailScreen(),
          settings: settings,
        );

      case RouteNames.addProductStep1:
        return IOSPageRoute(
          child: const AddProductStep1Screen(),
          settings: settings,
        );

      case RouteNames.addProductStep2:
        final args = settings.arguments as Map<String, dynamic>;
        return IOSPageRoute(
          child: AddProductStep2Screen(
            productName: args['productName'],
            companyId: args['companyId'],
          ),
          settings: settings,
        );

      case RouteNames.addProductStep3:
        final args = settings.arguments as Map<String, dynamic>;
        return IOSPageRoute(
          child: AddProductStep3Screen(
            productName: args['productName'],
            companyId: args['companyId'],
            category: args['category'],
          ),
          settings: settings,
        );

      case RouteNames.companies:
        return IOSPageRoute(
          child: const CompanyListScreen(),
          settings: settings,
        );

      case RouteNames.addCompany:
        return IOSPageRoute(
          child: const AddEditCompanyScreen(),
          settings: settings,
        );

      case RouteNames.editCompany:
        final company = settings.arguments as Company;
        return IOSPageRoute(
          child: AddEditCompanyScreen(company: company),
          settings: settings,
        );

      case RouteNames.companyDetail:
        final company = settings.arguments as Company;
        return IOSPageRoute(
          child: CompanyDetailScreen(company: company),
          settings: settings,
        );

      case RouteNames.purchaseOrders:
        return IOSPageRoute(
          child: const PurchaseOrderListScreen(),
          settings: settings,
        );

      case RouteNames.purchaseOrderDetail:
        final po = settings.arguments as PurchaseOrder;
        return IOSPageRoute(
          child: PurchaseOrderDetailScreen(purchaseOrder: po),
          settings: settings,
        );

      case RouteNames.createPurchaseOrder:
        return IOSPageRoute(
          child: const CreatePurchaseOrderScreen(),
          settings: settings,
        );

      case RouteNames.purchaseOrderReceiveSuccess:
        final poNumber = settings.arguments as String?;
        return IOSPageRoute(
          child: POReceiveSuccessScreen(poNumber: poNumber),
          settings: settings,
        );

      case RouteNames.pos:
        return IOSPageRoute(child: const POSScreen(), settings: settings);

      case RouteNames.cart: // Thêm route cho CartScreen
        return IOSPageRoute(child: const CartScreen(), settings: settings);

      case RouteNames
          .transactionSuccess: // Thêm route cho TransactionSuccessScreen
        final args = settings.arguments as String?;
        return IOSPageRoute(
          child: TransactionSuccessScreen(transactionId: args!),
          settings: settings,
        );

      case RouteNames.transactionList: // Transaction history screen
        return IOSPageRoute(
          child: const TransactionListScreen(),
          settings: settings,
        );

      case RouteNames.reports:
        return IOSPageRoute(child: const ReportsScreen(), settings: settings);

      case RouteNames.debts:
        return IOSPageRoute(child: const DebtListScreen(), settings: settings);

      case RouteNames.editQuickAccess:
        return IOSPageRoute(
          child: const EditQuickAccessScreen(),
          settings: settings,
        );

      case RouteNames.globalSearch:
        return IOSPageRoute(
          child: const GlobalSearchScreen(),
          settings: settings,
        );

      case RouteNames.editProfile:
        return IOSPageRoute(
          child: const EditProfileScreen(),
          settings: settings,
        );

      case RouteNames.editStoreInfo:
        return IOSPageRoute(
          child: const EditStoreInfoScreen(),
          settings: settings,
        );

      case RouteNames.employeeManagement:
        return IOSPageRoute(
          child: const EmployeeManagementScreen(),
          settings: settings,
        );

      case RouteNames.invoiceSettings:
        return IOSPageRoute(
          child: const InvoiceSettingsScreen(),
          settings: settings,
        );

      case RouteNames.changePassword:
        return IOSPageRoute(
          child: const ChangePasswordScreen(),
          settings: settings,
        );

      case RouteNames.transactionDetail:
        final transaction = settings.arguments as Transaction;
        return IOSPageRoute(
          child: TransactionDetailScreen(transaction: transaction),
          settings: settings,
        );

      case RouteNames.customerDetail:
        final customer = settings.arguments as Customer;
        return IOSPageRoute(
          child: CustomerDetailScreen(customer: customer),
          settings: settings,
        );

      default:
        return IOSPageRoute(
          child: Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}
