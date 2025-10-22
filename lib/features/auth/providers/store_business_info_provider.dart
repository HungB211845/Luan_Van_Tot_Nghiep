import 'package:flutter/foundation.dart';
import '../models/store_business_info.dart';
import '../services/store_business_info_service.dart';
import '../../../shared/utils/tax_code_lookup_cache.dart';
import '../../../shared/models/tax_code_lookup_result.dart';

/// Provider for managing store business information state
///
/// Handles:
/// - Loading/saving store business info
/// - Tax code validation
/// - Auto-filling data from tax code API lookup (VietQR → masothue)
/// - Caching lookup results (15min TTL)
class StoreBusinessInfoProvider extends ChangeNotifier {
  final StoreBusinessInfoService _service = StoreBusinessInfoService();
  final TaxCodeLookupCache _cache = TaxCodeLookupCache();

  // State
  StoreBusinessInfo? _storeBusinessInfo;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isValidatingTaxCode = false;
  Map<String, String>? _autoFilledData;
  String? _validationSource;  // 'VIETQR', 'MASOTHUE', or null

  // Getters
  StoreBusinessInfo? get storeBusinessInfo => _storeBusinessInfo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isValidatingTaxCode => _isValidatingTaxCode;
  Map<String, String>? get autoFilledData => _autoFilledData;
  String? get validationSource => _validationSource;

  /// Check if store has business info configured
  bool get hasBusinessInfo => _storeBusinessInfo != null && _storeBusinessInfo!.isComplete;

  /// Check if tax code was validated via API
  bool get isTaxCodeValidated => _storeBusinessInfo?.isApiValidated ?? false;

  /// Load store business info from database
  Future<void> loadStoreBusinessInfo() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeBusinessInfo = await _service.getStoreBusinessInfo();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Save or update store business info
  ///
  /// Returns true if successful, false otherwise
  Future<bool> saveStoreBusinessInfo(StoreBusinessInfo info) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _storeBusinessInfo = await _service.createOrUpdateStoreBusinessInfo(info);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Validate tax code format (client-side)
  ///
  /// Returns error message if invalid, null if valid
  String? validateTaxCodeFormat(String taxCode) {
    if (!_service.validateTaxCodeFormat(taxCode)) {
      return 'Mã số thuế không đúng định dạng (phải có 10 hoặc 13 chữ số)';
    }
    return null;
  }

  /// Validate and fetch tax code info from API with caching
  ///
  /// Cascade lookup: VietQR → masothue → null
  /// Caches results (including failures) for 15 minutes
  /// Auto-fills business name, tax authority, address, legal representative if found
  ///
  /// Returns true if data was fetched successfully
  Future<bool> validateAndFetchTaxCode(String taxCode) async {
    // Clear previous auto-filled data
    _autoFilledData = null;
    _errorMessage = null;
    _validationSource = null;

    // Validate format first
    final formatError = validateTaxCodeFormat(taxCode);
    if (formatError != null) {
      _errorMessage = formatError;
      notifyListeners();
      return false;
    }

    // Check cache first (15min TTL)
    if (_cache.has(taxCode)) {
      final cachedResult = _cache.get(taxCode);

      if (cachedResult == null) {
        // Cached failure - show error immediately
        _errorMessage = 'Không tìm thấy thông tin trong các nguồn chính thức, mời nhập thủ công';
        notifyListeners();
        return false;
      }

      // Cached success - apply data
      _applyLookupResult(cachedResult);
      notifyListeners();
      return true;
    }

    _isValidatingTaxCode = true;
    notifyListeners();

    try {
      final result = await _service.fetchTaxCodeInfo(taxCode);

      _isValidatingTaxCode = false;

      if (result != null) {
        // Success - cache and apply
        _cache.set(taxCode, result);
        _applyLookupResult(result);
        notifyListeners();
        return true;
      } else {
        // Not found in any source - cache failure
        _cache.set(taxCode, null);
        _errorMessage = 'Không tìm thấy thông tin trong các nguồn chính thức, mời nhập thủ công';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isValidatingTaxCode = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Apply lookup result to provider state
  void _applyLookupResult(TaxCodeLookupResult result) {
    _validationSource = result.source;
    _autoFilledData = result.toAutoFillData();
    _errorMessage = null;
  }

  /// Clear auto-filled data
  void clearAutoFilledData() {
    _autoFilledData = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Delete store business info
  Future<bool> deleteStoreBusinessInfo() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteStoreBusinessInfo();
      _storeBusinessInfo = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Refresh store business info
  Future<void> refresh() async {
    await loadStoreBusinessInfo();
  }
}
