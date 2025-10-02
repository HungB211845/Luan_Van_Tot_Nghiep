import '../../providers/customer_provider.dart';
import '../../models/customer.dart';

class CustomerListViewModel {
  final CustomerProvider customerProvider;

  CustomerListViewModel(this.customerProvider);

  Future<void> initialize() async {
    if (customerProvider.customers.isEmpty) {
      await customerProvider.loadCustomers();
    }
  }

  Future<void> handleSearch(String query) async {
    await customerProvider.searchCustomers(query);
  }

  Future<void> handleRefresh() async {
    await customerProvider.refresh();
  }

  void handleCustomerTap(Customer customer) {
    customerProvider.selectCustomer(customer);
  }

  Future<void> handleSort(String sortBy, bool ascending) async {
    await customerProvider.loadCustomersSorted(sortBy, ascending);
  }

  String? validateCustomerName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Tên khách hàng không được để trống';
    }
    if (name.trim().length < 2) {
      return 'Tên khách hàng phải có ít nhất 2 ký tự';
    }
    return null;
  }

  String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    final phoneRegex = RegExp(r'^[0-9]{10,11}$');
    if (!phoneRegex.hasMatch(phone.trim())) {
      return 'Số điện thoại không hợp lệ (10-11 số)';
    }

    return null;
  }

  String? validateDebtLimit(String? debtLimitStr) {
    if (debtLimitStr == null || debtLimitStr.trim().isEmpty) {
      return 'Hạn mức nợ không được để trống';
    }

    final debtLimit = double.tryParse(debtLimitStr.trim());
    if (debtLimit == null) {
      return 'Hạn mức nợ phải là số';
    }

    if (debtLimit < 0) {
      return 'Hạn mức nợ không được âm';
    }

    return null;
  }

  String? validateInterestRate(String? interestRateStr) {
    if (interestRateStr == null || interestRateStr.trim().isEmpty) {
      return null;
    }

    final interestRate = double.tryParse(interestRateStr.trim());
    if (interestRate == null) {
      return 'Lãi suất phải là số';
    }

    if (interestRate < 0 || interestRate > 100) {
      return 'Lãi suất phải từ 0% đến 100%';
    }

    return null;
  }

  // 🎯 RESPONSIVE: Additional methods needed for customer list
  Customer? getSelectedCustomer() {
    return customerProvider.selectedCustomer;
  }

  void selectCustomer(Customer customer) {
    customerProvider.selectCustomer(customer);
  }
}