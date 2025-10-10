import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../features/products/providers/product_provider.dart';
import '../../features/products/providers/product_edit_mode_provider.dart';
import '../../features/pos/providers/transaction_provider.dart';
import '../../features/products/providers/company_provider.dart';
import '../../features/products/providers/purchase_order_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/permission_provider.dart';
import '../../features/auth/providers/store_provider.dart';
import '../../features/auth/providers/session_provider.dart';
import '../../features/debt/providers/debt_provider.dart';
import '../../presentation/home/providers/quick_access_provider.dart';
import '../../presentation/home/providers/dashboard_provider.dart';
import '../../features/reports/providers/report_provider.dart';
import '../providers/navigation_provider.dart';
import '../../services/cache_manager.dart';

class AppProviders {
  static List<SingleChildWidget> get list => [
    // Core Cache Manager (Singleton)
    ChangeNotifierProvider.value(value: CacheManager()),
    
    // Business Logic Providers
    ChangeNotifierProvider(create: (_) => CustomerProvider()),
    ChangeNotifierProvider(create: (_) => ProductProvider()),
    ChangeNotifierProvider(create: (_) => ProductEditModeProvider()),
    ChangeNotifierProvider(create: (_) => TransactionProvider()),
    ChangeNotifierProvider(create: (_) => CompanyProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => PermissionProvider()),
    ChangeNotifierProvider(create: (_) => StoreProvider()),
    ChangeNotifierProvider(create: (_) => SessionProvider()),
    ChangeNotifierProvider(
      create: (context) => PurchaseOrderProvider(
        Provider.of<ProductProvider>(context, listen: false),
      ),
    ),
    ChangeNotifierProvider(create: (_) => DebtProvider()),
    ChangeNotifierProvider(create: (_) => QuickAccessProvider()),
    ChangeNotifierProvider(create: (_) => DashboardProvider()),
    ChangeNotifierProvider(create: (_) => ReportProvider()),
    ChangeNotifierProvider(create: (_) => NavigationProvider()),
    // Dễ dàng thêm providers mới ở đây
  ];
}
