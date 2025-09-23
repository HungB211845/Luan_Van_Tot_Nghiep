import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/transaction_item.dart';
import '../services/transaction_service.dart';


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

  // =====================================================
  // TRANSACTION OPERATIONS
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
  // REFRESH & RELOAD
  // =====================================================

  Future<void> refresh({String? customerId}) async {
    await loadTransactionHistory(customerId: customerId);
  }
}
