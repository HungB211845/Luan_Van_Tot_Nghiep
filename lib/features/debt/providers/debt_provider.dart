import 'package:flutter/foundation.dart';
import '../services/debt_service.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../models/debt_adjustment.dart';
import '../../pos/models/transaction.dart' as pos;

/// Provider for debt management state
class DebtProvider extends ChangeNotifier {
  final DebtService _debtService = DebtService();

  // =====================================================
  // STATE
  // =====================================================

  List<Debt> _debts = [];
  List<DebtPayment> _payments = [];
  List<DebtAdjustment> _adjustments = [];
  Map<String, dynamic>? _debtSummary;

  bool _isLoading = false;
  String _errorMessage = '';
  String _paymentError = '';

  // For Master-Detail view
  String? _selectedCustomerId;

  // =====================================================
  // GETTERS
  // =====================================================

  String? get selectedCustomerId => _selectedCustomerId;

  List<Debt> get debts => _debts;
  List<DebtPayment> get payments => _payments;
  List<DebtAdjustment> get adjustments => _adjustments;
  Map<String, dynamic>? get debtSummary => _debtSummary;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get paymentError => _paymentError;

  // Get debts by status
  List<Debt> getDebtsByStatus(String status) {
    return _debts.where((d) => d.status.value == status).toList();
  }

  // Get overdue debts
  List<Debt> get overdueDebts {
    return _debts.where((d) => d.isOverdue).toList();
  }

  // Get total remaining debt
  double get totalRemainingDebt {
    return _debts.fold(0, (sum, debt) => sum + debt.remainingAmount);
  }

  // =====================================================
  // DEBT OPERATIONS
  // =====================================================

  /// Select a customer to show in the detail pane of a Master-Detail view.
  void selectCustomerForDetail(String? customerId) {
    _selectedCustomerId = customerId;
    notifyListeners();
  }

  /// Create debt from POS transaction
  Future<String?> createDebtFromTransaction({
    required pos.Transaction transaction,
    String? customerId,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      _errorMessage = '';
      notifyListeners();

      final debtId = await _debtService.createDebtFromTransaction(
        transaction: transaction,
        customerId: customerId,
        dueDate: dueDate,
        notes: notes,
      );

      return debtId;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Load debts for a customer
  Future<void> loadCustomerDebts(String customerId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _debts = await _debtService.getCustomerDebts(customerId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _debts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all debts in store
  Future<void> loadAllDebts({
    String? status,
    bool onlyOverdue = false,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _debts = await _debtService.getAllDebts(
        status: status,
        onlyOverdue: onlyOverdue,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _debts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load customer debt summary
  Future<void> loadCustomerDebtSummary(String customerId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _debtSummary = await _debtService.getCustomerDebtSummary(customerId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _debtSummary = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get single debt by ID
  Future<Debt?> getDebtById(String debtId) async {
    try {
      _errorMessage = '';
      notifyListeners();

      return await _debtService.getDebtById(debtId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Cancel a debt
  Future<bool> cancelDebt(String debtId, String reason) async {
    try {
      _errorMessage = '';
      notifyListeners();

      final success = await _debtService.cancelDebt(debtId, reason);

      // Refresh debts list after cancellation
      if (success && _debts.isNotEmpty) {
        _debts = _debts.map((debt) {
          if (debt.id == debtId) {
            return Debt.fromJson({
              ...debt.toJson(),
              'status': 'cancelled',
            });
          }
          return debt;
        }).toList();
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // =====================================================
  // PAYMENT OPERATIONS
  // =====================================================

  /// Add payment for customer (with overpayment prevention)
  Future<bool> addPayment({
    required String customerId,
    required double paymentAmount,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      _paymentError = '';
      notifyListeners();

      final result = await _debtService.addPayment(
        customerId: customerId,
        paymentAmount: paymentAmount,
        paymentMethod: paymentMethod,
        notes: notes,
      );

      // Payment successful, result contains distribution info
      return true;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');

      // Check if it's an overpayment error
      if (errorMsg.contains('vượt quá tổng nợ')) {
        _paymentError = errorMsg;
      } else {
        _errorMessage = errorMsg;
      }

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load payment history for a debt
  Future<void> loadDebtPayments(String debtId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _payments = await _debtService.getDebtPayments(debtId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all payments for a customer
  Future<void> loadCustomerPayments(String customerId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _payments = await _debtService.getCustomerPayments(customerId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // ADJUSTMENT OPERATIONS
  // =====================================================

  /// Adjust debt amount
  Future<bool> adjustDebt({
    required String debtId,
    required double adjustmentAmount,
    required String adjustmentType,
    required String reason,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      final result = await _debtService.adjustDebt(
        debtId: debtId,
        adjustmentAmount: adjustmentAmount,
        adjustmentType: adjustmentType,
        reason: reason,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load adjustment history for a debt
  Future<void> loadDebtAdjustments(String debtId) async {
    try {
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();

      _adjustments = await _debtService.getDebtAdjustments(debtId);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _adjustments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =====================================================
  // UTILITY OPERATIONS
  // =====================================================

  /// Calculate overdue interest for a debt
  Future<double?> calculateOverdueInterest(
    String debtId, {
    double dailyInterestRate = 0.001,
  }) async {
    try {
      _errorMessage = '';
      notifyListeners();

      return await _debtService.calculateOverdueInterest(
        debtId,
        dailyInterestRate: dailyInterestRate,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  /// Clear payment error (for UI)
  void clearPaymentError() {
    _paymentError = '';
    notifyListeners();
  }

  /// Clear general error
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}
