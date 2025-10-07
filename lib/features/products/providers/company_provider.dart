import 'package:flutter/foundation.dart';

import '../models/company.dart';
import '../models/product.dart';
import '../services/company_service.dart';
import '../../../shared/services/base_service.dart';

enum CompanyStatus { idle, loading, success, error }

class CompanyProvider extends ChangeNotifier {
  final CompanyService _companyService = CompanyService();
  List<Company> _companies = [];
  Company? _selectedCompany;
  List<Product> _companyProducts = [];
  CompanyStatus _status = CompanyStatus.idle;
  String _errorMessage = '';

  String _searchQuery = '';

  // Getters
  List<Company> get companies => _companies;
  Company? get selectedCompany => _selectedCompany;
  List<Product> get companyProducts => _companyProducts;
  CompanyStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CompanyStatus.loading;
  bool get hasError => _status == CompanyStatus.error;
  String get searchQuery => _searchQuery;

  // Filtered companies based on search query
  List<Company> get filteredCompanies {
    List<Company> filtered = _companies;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = _companies.where((company) {
        final matchName = company.name.toLowerCase().contains(query);
        final matchPhone = company.phone?.toLowerCase().contains(query) ?? false;
        final matchContact = company.contactPerson?.toLowerCase().contains(query) ?? false;
        return matchName || matchPhone || matchContact;
      }).toList();
    }

    // Sort alphabetically
    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  // Load all companies safely
  Future<void> loadCompanies({bool forceReload = false}) async {
    if (_status == CompanyStatus.loading && !forceReload) return;
    
    _status = CompanyStatus.loading;
    _errorMessage = '';
    // Do not notify listeners here to prevent build errors

    try {
      _companies = await _companyService.getCompanies();
      _status = CompanyStatus.success;
    } catch (e) {
      _status = CompanyStatus.error;
      _errorMessage = e.toString();
    } finally {
      // Notify listeners only once at the end
      notifyListeners();
    }
  }

  // Load products for a specific company safely
  Future<void> loadCompanyProducts(String companyId) async {
    _status = CompanyStatus.loading;
    _companyProducts = [];
    // Do not notify listeners here

    try {
      _companyProducts = await _companyService.getCompanyProducts(companyId);
      _status = CompanyStatus.success;
    } catch (e) {
      _status = CompanyStatus.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Add a new company
  Future<bool> addCompany(Company company) async {
    try {
      if (BaseService.currentUserStoreId == null || BaseService.currentUserStoreId!.isEmpty) {
        _errorMessage = 'Không xác định được cửa hàng. Vui lòng đăng nhập lại.';
        notifyListeners();
        return false;
      }
      final exists = await _companyService.existsCompanyName(company.name);
      if (exists) {
        _errorMessage = 'Tên nhà cung cấp đã tồn tại trong cửa hàng.';
        notifyListeners();
        return false;
      }
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

  // Update a company
  Future<bool> updateCompany(Company company) async {
    try {
      if (BaseService.currentUserStoreId == null || BaseService.currentUserStoreId!.isEmpty) {
        _errorMessage = 'Không xác định được cửa hàng. Vui lòng đăng nhập lại.';
        notifyListeners();
        return false;
      }
      final exists = await _companyService.existsCompanyName(company.name, excludeId: company.id);
      if (exists) {
        _errorMessage = 'Tên nhà cung cấp đã tồn tại trong cửa hàng.';
        notifyListeners();
        return false;
      }
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

  // Delete a company
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

  // Select a company for detail view
  void selectCompany(Company? company) {
    _selectedCompany = company;
    if (company == null) {
      _companyProducts = [];
    }
    notifyListeners();
  }

  // Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}