import 'user_profile.dart';

class Permission {
  static const String managePOS = 'manage_pos';
  static const String manageInventory = 'manage_inventory';
  static const String manageCustomers = 'manage_customers';
  static const String managePurchaseOrders = 'manage_purchase_orders';
  static const String viewReports = 'view_reports';
  static const String manageUsers = 'manage_users';
  static const String manageStoreSettings = 'manage_store_settings';
  static const String exportData = 'export_data';

  static Map<UserRole, List<String>> get defaultPermissions => {
        UserRole.owner: [
          managePOS,
          manageInventory,
          manageCustomers,
          managePurchaseOrders,
          viewReports,
          manageUsers,
          manageStoreSettings,
          exportData,
        ],
        UserRole.manager: [
          managePOS,
          manageInventory,
          manageCustomers,
          managePurchaseOrders,
          viewReports,
          manageUsers,
        ],
        UserRole.cashier: [managePOS, manageCustomers],
        UserRole.inventoryStaff: [manageInventory, managePurchaseOrders, viewReports],
      };
}
