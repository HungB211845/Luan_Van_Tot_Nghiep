import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';

enum CustomerStatus { idle, loading, success, error }

class CustomerProvider extends ChangeNotifier {
  final CustomerService _customerService = CustomerService();

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  Customer? _selectedCustomer;
  CustomerStatus _status = CustomerStatus.idle;
  String _errorMessage = '';
  String _searchQuery = '';

  List<Customer> get customers => _filteredCustomers.isEmpty && _searchQuery.isEmpty
      ? _customers
      : _filteredCustomers;
  Customer? get selectedCustomer => _selectedCustomer;
  CustomerStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CustomerStatus.loading;
  bool get hasError => _status == CustomerStatus.error;

  Future<void> loadCustomers() async {
    _setStatus(CustomerStatus.loading);

    try {
      _customers = await _customerService.getCustomers();
      _setStatus(CustomerStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> searchCustomers(String query) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredCustomers = [];
      notifyListeners();
      return;
    }

    _setStatus(CustomerStatus.loading);

    try {
      _filteredCustomers = await _customerService.searchCustomers(_searchQuery);
      _setStatus(CustomerStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> addCustomer(Customer customer) async {
    _setStatus(CustomerStatus.loading);

    try {
      final newCustomer = await _customerService.createCustomer(customer);
      _customers.add(newCustomer);
      _setStatus(CustomerStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    _setStatus(CustomerStatus.loading);

    try {
      final updatedCustomer = await _customerService.updateCustomer(customer);

      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = updatedCustomer;
      }

      if (_selectedCustomer?.id == customer.id) {
        _selectedCustomer = updatedCustomer;
      }

      _setStatus(CustomerStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    _setStatus(CustomerStatus.loading);

    try {
      await _customerService.deleteCustomer(customerId);
      _customers.removeWhere((c) => c.id == customerId);

      if (_selectedCustomer?.id == customerId) {
        _selectedCustomer = null;
      }

      _setStatus(CustomerStatus.success);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredCustomers = [];
    notifyListeners();
  }

  void _setStatus(CustomerStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = CustomerStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadCustomers();
  }
}