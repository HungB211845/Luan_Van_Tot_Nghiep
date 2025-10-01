import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../models/payment_method.dart';
import '../services/transaction_service.dart';
import '../../../shared/utils/formatter.dart';

// Using an enum for status is a robust pattern.
enum TransactionStatus { idle, loading, loadingMore, success, error }

/// A data class to hold all the filter parameters for searching transactions.
/// This makes the provider's state cleaner and easier to manage.
@immutable
class TransactionFilter {
  final String? searchText;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final Set<PaymentMethod> paymentMethods;
  final Set<String> customerIds;
  final String? debtStatus; // e.g., 'paid', 'unpaid', 'all'

  const TransactionFilter({
    this.searchText,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.paymentMethods = const {},
    this.customerIds = const {},
    this.debtStatus,
  });

  /// Creates a copy of the filter with updated values.
  TransactionFilter copyWith({
    String? searchText,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    Set<PaymentMethod>? paymentMethods,
    Set<String>? customerIds,
    String? debtStatus,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return TransactionFilter(
      searchText: searchText ?? this.searchText,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      customerIds: customerIds ?? this.customerIds,
      debtStatus: debtStatus ?? this.debtStatus,
    );
  }
}

class TransactionProvider extends ChangeNotifier {
  final TransactionService _service = TransactionService();

  // State
  var _status = TransactionStatus.idle;
  String _errorMessage = '';
  List<Transaction> _transactions = [];
  TransactionFilter _filter = const TransactionFilter();
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;

  // Getters
  TransactionStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Transaction> get transactions => _transactions;
  TransactionFilter get filter => _filter;
  bool get hasMore => _hasMore;
  bool get isLoading => _status == TransactionStatus.loading;
  bool get isLoadingMore => _status == TransactionStatus.loadingMore;

  /// Groups transactions by date for the UI.
  Map<String, List<Transaction>> get groupedTransactions {
    final Map<String, List<Transaction>> grouped = {};
    for (final transaction in _transactions) {
      final dateKey = AppFormatter.formatDate(transaction.transactionDate);
      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }
    return grouped;
  }

  /// The main method to fetch transactions, called on initial load and when filters change.
  Future<void> loadTransactions() async {
    _currentPage = 1;
    _transactions = [];
    _hasMore = true;
    _status = TransactionStatus.loading;
    notifyListeners();
    await _fetchTransactions();
  }

  /// Fetches the next page of transactions.
  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !_hasMore) return;

    _status = TransactionStatus.loadingMore;
    notifyListeners();

    _currentPage++;
    await _fetchTransactions(isLoadMore: true);
  }

  /// The private workhorse method that calls the service.
  Future<void> _fetchTransactions({bool isLoadMore = false}) async {
    try {
      final result = await _service.searchTransactions(
        searchText: _filter.searchText,
        startDate: _filter.startDate,
        endDate: _filter.endDate,
        minAmount: _filter.minAmount,
        maxAmount: _filter.maxAmount,
        paymentMethods: _filter.paymentMethods.toList(),
        customerIds: _filter.customerIds.toList(),
        debtStatus: _filter.debtStatus,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (isLoadMore) {
        _transactions.addAll(result.items);
      }
      else {
        _transactions = result.items;
      }

      _hasMore = result.hasNextPage;
      _status = TransactionStatus.success;
    } catch (e) {
      _errorMessage = e.toString();
      _status = TransactionStatus.error;
    } finally {
      notifyListeners();
    }
  }

  /// Updates the filter and reloads the transaction list.
  Future<void> updateFilter(TransactionFilter newFilter) async {
    _filter = newFilter;
    await loadTransactions();
  }

  /// A convenience method to refresh the data.
  Future<void> refresh() async {
    await loadTransactions();
  }

  /// Fetches a single transaction by its ID.
  /// This is useful for navigating to a detail screen when you only have the ID.
  Future<Transaction?> getTransactionById(String transactionId) async {
    // No need to set global loading status for this single fetch
    try {
      final transaction = await _service.getTransactionWithItems(transactionId);
      return transaction;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
