import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/customers/providers/customer_provider.dart';
import '../../features/products/providers/product_provider.dart';
import '../../features/pos/providers/transaction_provider.dart';
import '../../features/products/providers/company_provider.dart';
import '../../features/products/providers/purchase_order_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get list => [
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(
          create: (context) => PurchaseOrderProvider(
            Provider.of<ProductProvider>(context, listen: false),
          ),
        ),
        // Dễ dàng thêm providers mới ở đây
      ];
}
