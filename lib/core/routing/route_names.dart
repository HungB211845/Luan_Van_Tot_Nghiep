class RouteNames {
  static const String home = '/';
  // Alias to support direct navigation to '/home' from Splash if needed
  static const String homeAlias = '/home';
  // Auth
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otp = '/otp';
  static const String biometricLogin = '/biometric-login';
  static const String storeSetup = '/store-setup';
  static const String onboarding = '/onboarding';
  static const String customers = '/customers';
  static const String products = '/products';
  static const String productDetail = '/product-detail';
  static const String companies = '/companies';
  static const String addCompany = '/companies/add';
  static const String editCompany = '/companies/edit';
  static const String companyDetail = '/companies/detail';
  static const String purchaseOrders = '/purchase-orders';
  static const String createPurchaseOrder = '/purchase-orders/create';
  static const String purchaseOrderDetail = '/purchase-orders/detail';
  static const String purchaseOrderReceiveSuccess = '/purchase-orders/receive-success';
  static const String pos = '/pos';
  static const String cart = '/cart'; // Thêm route cho CartScreen
  static const String transactionSuccess = '/transaction-success'; // Thêm route cho TransactionSuccessScreen
  static const String transactionList = '/transaction-list'; // Transaction history screen
  static const String reports = '/reports';
  static const String profile = '/profile';
  static const String changePassword = '/change-password';
  static const String logout = '/logout';
}