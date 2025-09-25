import 'package:flutter/foundation.dart';

import '../models/company.dart';
import '../models/product.dart';
import '../services/company_service.dart';

enum CompanyStatus { idle, loading, success, error }

class CompanyProvider extends ChangeNotifier {
  final CompanyService _companyService = CompanyService();
  List<Company> _companies = [];
  Company? _selectedCompany;
  List<Product> _companyProducts = []; // State cho sản phẩm của công ty
  CompanyStatus _status = CompanyStatus.idle;
  String _errorMessage = '';

  // Getters
  List<Company> get companies => _companies;
  Company? get selectedCompany => _selectedCompany;
  List<Product> get companyProducts => _companyProducts; // Getter cho sản phẩm
  CompanyStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CompanyStatus.loading;
  bool get hasError => _status == CompanyStatus.error;

  // Load tất cả companies
  Future<void> loadCompanies() async {
    _status = CompanyStatus.loading;
    notifyListeners();

    try {
      _companies = await _companyService.getCompanies();
      _status = CompanyStatus.success;
      _errorMessage = '';
    } catch (e) {
      _status = CompanyStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Load sản phẩm của một company
  Future<void> loadCompanyProducts(String companyId) async {
    _status = CompanyStatus.loading;
    _companyProducts = []; // Xóa list cũ
    notifyListeners();

    try {
      _companyProducts = await _companyService.getCompanyProducts(companyId);
      _status = CompanyStatus.success;
      _errorMessage = '';
    } catch (e) {
      _status = CompanyStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Thêm company mới
  Future<bool> addCompany(Company company) async {
    try {
      final newCompany = await _companyService.createCompany(company);
      _companies.add(newCompany);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Cập nhật company
  Future<bool> updateCompany(Company company) async {
    try {
      final updatedCompany = await _companyService.updateCompany(company);
      final index = _companies.indexWhere((c) => c.id == company.id);
      if (index != -1) {
        _companies[index] = updatedCompany;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Xóa company
  Future<bool> deleteCompany(String companyId) async {
    try {
      await _companyService.deleteCompany(companyId);
      _companies.removeWhere((c) => c.id == companyId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Select company
  void selectCompany(Company? company) {
    _selectedCompany = company;
    if (company == null) {
      _companyProducts = [];
    }
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}
