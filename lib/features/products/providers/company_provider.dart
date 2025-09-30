import 'package:flutter/foundation.dart';

import '../models/company.dart';
import '../models/product.dart';
import '../services/company_service.dart';
import '../../../shared/services/base_service.dart';

enum CompanyStatus { idle, loading, success, error }

enum CompanyFilterType {
  hasProducts,    // Có sản phẩm
  hasOrders,      // Có đơn hàng
  hasPhone,       // Có SĐT
  hasAddress,     // Có địa chỉ
}

class CompanyProvider extends ChangeNotifier {
  final CompanyService _companyService = CompanyService();
  List<Company> _companies = [];
  Company? _selectedCompany;
  List<Product> _companyProducts = []; // State cho sản phẩm của công ty
  CompanyStatus _status = CompanyStatus.idle;
  String _errorMessage = '';

  // Search & Filter state
  String _searchQuery = '';
  Set<CompanyFilterType> _activeFilters = {};

  // Getters
  List<Company> get companies => _companies;
  Company? get selectedCompany => _selectedCompany;
  List<Product> get companyProducts => _companyProducts; // Getter cho sản phẩm
  CompanyStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == CompanyStatus.loading;
  bool get hasError => _status == CompanyStatus.error;
  String get searchQuery => _searchQuery;
  Set<CompanyFilterType> get activeFilters => _activeFilters;

  // Filtered & grouped companies
  Map<String, List<Company>> get groupedCompanies {
    // 1. Apply search filter
    List<Company> filtered = _companies.where((company) {
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      final matchName = company.name.toLowerCase().contains(query);
      final matchPhone = company.phone?.toLowerCase().contains(query) ?? false;
      final matchContact = company.contactPerson?.toLowerCase().contains(query) ?? false;

      return matchName || matchPhone || matchContact;
    }).toList();

    // 2. Apply additional filters
    if (_activeFilters.isNotEmpty) {
      filtered = filtered.where((company) {
        return _activeFilters.every((filter) => _matchesFilter(company, filter));
      }).toList();
    }

    // 3. Sort alphabetically
    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // 4. Group by first character
    Map<String, List<Company>> grouped = {};
    for (var company in filtered) {
      String firstChar = _getFirstChar(company.name);
      grouped.putIfAbsent(firstChar, () => []).add(company);
    }

    return grouped;
  }

  List<String> get availableSections {
    return groupedCompanies.keys.toList()..sort();
  }

  // Load tất cả companies (load basic trước, metadata on-demand)
  Future<void> loadCompanies({bool forceReload = false}) async {
    _status = CompanyStatus.loading;
    notifyListeners();

    try {
      // Load basic companies (fast)
      _companies = await _companyService.getCompanies();
      _status = CompanyStatus.success;
      _errorMessage = '';
    } catch (e) {
      _status = CompanyStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Load metadata khi cần thiết (khi user toggle hasProducts/hasOrders filters)
  Future<void> loadMetadata() async {
    if (_companies.isEmpty) return;

    try {
      final companiesData = await _companyService.getCompaniesWithMetadata();
      _companies = companiesData
          .map((json) => Company.fromJson(json))
          .toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi load metadata: $e';
    }
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
      // Store guard
      if (BaseService.currentUserStoreId == null || BaseService.currentUserStoreId!.isEmpty) {
        _errorMessage = 'Không xác định được cửa hàng. Vui lòng đăng nhập lại.';
        notifyListeners();
        return false;
      }
      // Duplicate name check (per store)
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

  // Cập nhật company
  Future<bool> updateCompany(Company company) async {
    try {
      // Store guard
      if (BaseService.currentUserStoreId == null || BaseService.currentUserStoreId!.isEmpty) {
        _errorMessage = 'Không xác định được cửa hàng. Vui lòng đăng nhập lại.';
        notifyListeners();
        return false;
      }
      // Duplicate name check (exclude current id)
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

  // Search & filter actions
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFilter(CompanyFilterType filter) async {
    if (_activeFilters.contains(filter)) {
      _activeFilters.remove(filter);
    } else {
      _activeFilters.add(filter);

      // Load metadata nếu filter cần metadata và chưa có
      if ((filter == CompanyFilterType.hasProducts || filter == CompanyFilterType.hasOrders) &&
          _companies.isNotEmpty &&
          _companies.first.productsCount == null) {
        await loadMetadata();
      }
    }
    notifyListeners();
  }

  void clearFilters() {
    _activeFilters.clear();
    _searchQuery = '';
    notifyListeners();
  }

  // Helper methods
  String _getFirstChar(String name) {
    if (name.isEmpty) return '#';
    String first = name[0].toUpperCase();
    return RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
  }

  bool _matchesFilter(Company company, CompanyFilterType filter) {
    switch (filter) {
      case CompanyFilterType.hasProducts:
        return company.hasProducts;
      case CompanyFilterType.hasOrders:
        return company.hasOrders;
      case CompanyFilterType.hasPhone:
        return company.phone != null && company.phone!.isNotEmpty;
      case CompanyFilterType.hasAddress:
        return company.address != null && company.address!.isNotEmpty;
    }
  }
}
