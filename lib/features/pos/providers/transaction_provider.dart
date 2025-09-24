import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../services/transaction_service.dart';
import '../../../shared/models/paginated_result.dart';


enum TransactionStatus { idle, loading, success, error }

class TransactionProvider extends ChangeNotifier {
  final TransactionService _transactionService = TransactionService();

  // =====================================================
  // STATE VARIABLES
  // =====================================================

  List<Transaction> _transactions = [];
  List<TransactionItem> _transactionItems = [];
  Transaction? _selectedTransaction;

  TransactionStatus _status = TransactionStatus.idle;
  String _errorMessage = '';

  // Pagination state
  PaginatedResult<Transaction>? _paginatedTransactions;
  bool _isLoadingMore = false;
  PaginationParams _currentPaginationParams = const PaginationParams();

  // Search state
  String _searchQuery = '';
  List<Transaction> _searchResults = [];
  PaginatedResult<Transaction>? _paginatedSearchResults;

  // =====================================================
  // GETTERS
  // =====================================================

  List<Transaction> get transactions => _transactions;
  List<TransactionItem> get transactionItems => _transactionItems;
  Transaction? get selectedTransaction => _selectedTransaction;
  
  TransactionStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == TransactionStatus.loading;
  bool get hasError => _status == TransactionStatus.error;

  // Pagination getters
  PaginatedResult<Transaction>? get paginatedTransactions => _paginatedTransactions;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreTransactions => _paginatedTransactions?.hasNextPage ?? false;
  PaginationParams get currentPaginationParams => _currentPaginationParams;

  // Search getters
  String get searchQuery => _searchQuery;
  List<Transaction> get searchResults => _searchResults;
  PaginatedResult<Transaction>? get paginatedSearchResults => _paginatedSearchResults;
  bool get hasSearchResults => _searchResults.isNotEmpty;

  // =====================================================
  // TRANSACTION OPERATIONS - PAGINATED (RECOMMENDED)
  // =====================================================

  /// Load transactions with pagination
  Future<void> loadTransactionsPaginated({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false, // Default: newest first
  }) async {
    _setStatus(TransactionStatus.loading);
    try {
      _currentPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      _paginatedTransactions = await _transactionService.getTransactionHistoryPaginated(
        params: _currentPaginationParams,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        isDebt: isDebt,
        paymentMethod: paymentMethod,
      );

      // Update legacy _transactions list for backward compatibility
      _transactions = _paginatedTransactions!.items;

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load more transactions (pagination)
  Future<void> loadMoreTransactions({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
  }) async {
    if (!hasMoreTransactions || _isLoadingMore || _paginatedTransactions == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextParams = _currentPaginationParams.nextPage();
      final nextPage = await _transactionService.getTransactionHistoryPaginated(
        params: nextParams,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        isDebt: isDebt,
        paymentMethod: paymentMethod,
      );

      // Merge results
      _paginatedTransactions = _paginatedTransactions!.merge(nextPage);
      _currentPaginationParams = nextParams;

      // Update legacy _transactions list
      _transactions = _paginatedTransactions!.items;

      _isLoadingMore = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  /// Search transactions with pagination
  Future<void> searchTransactionsPaginated({
    required String query,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      await loadTransactionsPaginated(
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        isDebt: isDebt,
        paymentMethod: paymentMethod,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );
      return;
    }

    _setStatus(TransactionStatus.loading);
    try {
      _currentPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      _paginatedSearchResults = await _transactionService.searchTransactionsPaginated(
        query: _searchQuery,
        params: _currentPaginationParams,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        isDebt: isDebt,
        paymentMethod: paymentMethod,
      );

      // Update search results for backward compatibility
      _searchResults = _paginatedSearchResults!.items;

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load more search results
  Future<void> loadMoreSearchResults({
    required String query,
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
  }) async {
    if (_isLoadingMore || _paginatedSearchResults == null || !_paginatedSearchResults!.hasNextPage) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextParams = _currentPaginationParams.nextPage();
      final nextPage = await _transactionService.searchTransactionsPaginated(
        query: query,
        params: nextParams,
        customerId: customerId,
        startDate: startDate,
        endDate: endDate,
        isDebt: isDebt,
        paymentMethod: paymentMethod,
      );

      // Merge results
      _paginatedSearchResults = _paginatedSearchResults!.merge(nextPage);
      _currentPaginationParams = nextParams;

      // Update search results
      _searchResults = _paginatedSearchResults!.items;

      _isLoadingMore = false;
      _clearError();
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  /// Load debt transactions with pagination
  Future<void> loadDebtTransactionsPaginated({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    await loadTransactionsPaginated(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      isDebt: true,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Load today's transactions with pagination
  Future<void> loadTodayTransactionsPaginated({
    String? customerId,
    PaymentMethod? paymentMethod,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    _setStatus(TransactionStatus.loading);
    try {
      _currentPaginationParams = PaginationParams(
        page: 1,
        pageSize: pageSize,
        sortBy: sortBy,
        ascending: ascending,
      );

      _paginatedTransactions = await _transactionService.getTodayTransactionsPaginated(
        params: _currentPaginationParams,
        customerId: customerId,
        paymentMethod: paymentMethod,
      );

      // Update legacy _transactions list
      _transactions = _paginatedTransactions!.items;

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // =====================================================
  // TRANSACTION OPERATIONS - LEGACY (DEPRECATED)
  // =====================================================

  /// Tạo transaction mới
  Future<String?> createTransaction({
    required String? customerId,
    required List<TransactionItem> items,
    required PaymentMethod paymentMethod,
    bool isDebt = false,
    String? notes,
  }) async {
    _setStatus(TransactionStatus.loading);

    try {
      final transactionId = await _transactionService.createTransaction(
        customerId: customerId,
        items: items,
        paymentMethod: paymentMethod,
        notes: notes,
      );

      // TODO: Trigger debt creation if isDebt = true
      if (isDebt && customerId != null) {
        // This will be handled by DebtService later
        // await _createDebtFromTransaction(transactionId, customerId);
      }

      _setStatus(TransactionStatus.success);
      _clearError();
      
      return transactionId;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  @deprecated
  /// Load transaction history
  Future<void> loadTransactionHistory({String? customerId, int limit = 50}) async {
    _setStatus(TransactionStatus.loading);

    try {
      _transactions = await _transactionService.getTransactionHistory(
        customerId: customerId,
        limit: limit,
      );

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Load transaction details
  Future<void> loadTransactionDetails(String transactionId) async {
    _setStatus(TransactionStatus.loading);

    try {
      _selectedTransaction = await _transactionService.getTransactionById(transactionId);
      
      if (_selectedTransaction != null) {
        _transactionItems = await _transactionService.getTransactionItems(transactionId);
      }

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  @deprecated
  /// Load debt transactions
  Future<void> loadDebtTransactions({String? customerId}) async {
    _setStatus(TransactionStatus.loading);

    try {
      _transactions = await _transactionService.getDebtTransactions(
        customerId: customerId,
      );

      _setStatus(TransactionStatus.success);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Select transaction
  void selectTransaction(Transaction? transaction) {
    _selectedTransaction = transaction;
    notifyListeners();
  }

  /// Clear transaction selection
  void clearSelection() {
    _selectedTransaction = null;
    _transactionItems = [];
    notifyListeners();
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  void _setStatus(TransactionStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = TransactionStatus.error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // =====================================================
  // PAGINATION UTILITIES
  // =====================================================

  /// Reset pagination state and reload first page
  Future<void> resetTransactionsPagination({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isDebt,
    PaymentMethod? paymentMethod,
    int pageSize = 20,
    String? sortBy,
    bool ascending = false,
  }) async {
    _paginatedTransactions = null;
    _isLoadingMore = false;
    _currentPaginationParams = const PaginationParams();

    await loadTransactionsPaginated(
      customerId: customerId,
      startDate: startDate,
      endDate: endDate,
      isDebt: isDebt,
      paymentMethod: paymentMethod,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  /// Clear search state
  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _paginatedSearchResults = null;
    notifyListeners();
  }

  /// Clear all pagination state
  void clearPaginationState() {
    _paginatedTransactions = null;
    _paginatedSearchResults = null;
    _isLoadingMore = false;
    _currentPaginationParams = const PaginationParams();
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // =====================================================
  // REFRESH & RELOAD
  // =====================================================

  Future<void> refresh({String? customerId}) async {
    // Use paginated method if pagination state exists, otherwise use legacy method
    if (_paginatedTransactions != null) {
      await resetTransactionsPagination(customerId: customerId);
    } else {
      await loadTransactionHistory(customerId: customerId);
    }
  }
}
