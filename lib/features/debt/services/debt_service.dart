import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../models/debt_adjustment.dart';
import '../../pos/models/transaction.dart' as pos;

/// Service for debt management operations
/// Extends BaseService for multi-tenant store isolation
class DebtService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // DEBT OPERATIONS
  // =====================================================

  /// Create debt from POS transaction (call RPC for atomicity)
  Future<String> createDebtFromTransaction({
    required pos.Transaction transaction,
    String? customerId,
    DateTime? dueDate,
    String? notes,
  }) async {
    try {
      ensureAuthenticated();

      final storeId = currentStoreId;
      if (storeId == null) {
        throw Exception('Store ID not found. Please ensure you are logged in.');
      }

      final actualCustomerId = customerId ?? transaction.customerId;

      if (actualCustomerId == null) {
        throw Exception('Customer ID is required for credit sale');
      }

      // Call RPC function for atomic debt creation
      final response = await _supabase.rpc(
        'create_credit_sale',
        params: {
          'p_store_id': storeId,
          'p_customer_id': actualCustomerId,
          'p_transaction_id': transaction.id,
          'p_amount': transaction.totalAmount,
          'p_due_date': dueDate?.toIso8601String(),
          'p_notes': notes,
        },
      );

      if (response == null) {
        throw Exception('Failed to create debt: No response from server');
      }

      return response as String;
    } catch (e) {
      throw Exception('Lỗi tạo công nợ: $e');
    }
  }

  /// Get all debts for a customer
  Future<List<Debt>> getCustomerDebts(String customerId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase
          .from('debts')
          .select()
          .eq('store_id', storeId)
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Debt.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách nợ: $e');
    }
  }

  /// Get customer debt summary
  Future<Map<String, dynamic>> getCustomerDebtSummary(
      String customerId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase.rpc(
        'get_customer_debt_summary',
        params: {
          'p_store_id': storeId,
          'p_customer_id': customerId,
        },
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Lỗi lấy tổng hợp công nợ: $e');
    }
  }

  /// Get all debts in store with optional filters
  Future<List<Debt>> getAllDebts({
    String? status,
    bool onlyOverdue = false,
  }) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      dynamic query = _supabase
          .from('debts')
          .select()
          .eq('store_id', storeId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (onlyOverdue) {
        query = query.eq('status', 'overdue');
      }

      query = query.order('created_at', ascending: false);

      final response = await query;

      return (response as List)
          .map((json) => Debt.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách nợ: $e');
    }
  }

  // =====================================================
  // PAYMENT OPERATIONS
  // =====================================================

  /// Add payment for customer (call RPC with overpayment prevention)
  Future<Map<String, dynamic>> addPayment({
    required String customerId,
    required double paymentAmount,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      // Call RPC function - will throw exception if overpayment
      final response = await _supabase.rpc(
        'process_customer_payment',
        params: {
          'p_store_id': storeId,
          'p_customer_id': customerId,
          'p_payment_amount': paymentAmount,
          'p_payment_method': paymentMethod,
          'p_notes': notes,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      // Extract user-friendly error message for overpayment
      if (e.message.contains('vượt quá tổng nợ')) {
        throw Exception(e.message);
      }
      throw Exception('Lỗi xử lý thanh toán: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi xử lý thanh toán: $e');
    }
  }

  /// Get payment history for a debt
  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase
          .from('debt_payments')
          .select()
          .eq('store_id', storeId)
          .eq('debt_id', debtId)
          .order('payment_date', ascending: false);

      return (response as List)
          .map((json) => DebtPayment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử thanh toán: $e');
    }
  }

  /// Get all payments for a customer
  Future<List<DebtPayment>> getCustomerPayments(String customerId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase
          .from('debt_payments')
          .select()
          .eq('store_id', storeId)
          .eq('customer_id', customerId)
          .order('payment_date', ascending: false);

      return (response as List)
          .map((json) => DebtPayment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử thanh toán: $e');
    }
  }

  // =====================================================
  // ADJUSTMENT OPERATIONS
  // =====================================================

  /// Adjust debt amount (call RPC with validation)
  Future<Map<String, dynamic>> adjustDebt({
    required String debtId,
    required double adjustmentAmount,
    required String adjustmentType,
    required String reason,
  }) async {
    try {
      ensureAuthenticated();

      // Validate adjustment type
      if (!['increase', 'decrease', 'write_off'].contains(adjustmentType)) {
        throw Exception('Loại điều chỉnh không hợp lệ');
      }

      if (reason.trim().isEmpty) {
        throw Exception('Lý do điều chỉnh là bắt buộc');
      }

      // Call RPC function - will throw exception if invalid
      final response = await _supabase.rpc(
        'adjust_debt_amount',
        params: {
          'p_debt_id': debtId,
          'p_adjustment_amount': adjustmentAmount,
          'p_adjustment_type': adjustmentType,
          'p_reason': reason,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      // Extract user-friendly error message
      if (e.message.contains('negative debt')) {
        throw Exception(
            'Điều chỉnh này sẽ làm công nợ âm. Vui lòng kiểm tra lại số tiền.');
      }
      throw Exception('Lỗi điều chỉnh công nợ: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi điều chỉnh công nợ: $e');
    }
  }

  /// Get adjustment history for a debt
  Future<List<DebtAdjustment>> getDebtAdjustments(String debtId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase
          .from('debt_adjustments')
          .select()
          .eq('store_id', storeId)
          .eq('debt_id', debtId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DebtAdjustment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử điều chỉnh: $e');
    }
  }

  // =====================================================
  // UTILITY OPERATIONS
  // =====================================================

  /// Calculate overdue interest for a debt
  Future<double> calculateOverdueInterest(
    String debtId, {
    double dailyInterestRate = 0.001, // 0.1% per day default
  }) async {
    try {
      ensureAuthenticated();

      final response = await _supabase.rpc(
        'calculate_overdue_interest',
        params: {
          'p_debt_id': debtId,
          'p_daily_interest_rate': dailyInterestRate,
        },
      );

      return (response as num).toDouble();
    } catch (e) {
      throw Exception('Lỗi tính lãi quá hạn: $e');
    }
  }

  /// Get single debt by ID
  Future<Debt?> getDebtById(String debtId) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      final response = await _supabase
          .from('debts')
          .select()
          .eq('id', debtId)
          .eq('store_id', storeId)
          .maybeSingle();

      if (response == null) return null;

      return Debt.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin nợ: $e');
    }
  }

  /// Cancel/void a debt
  Future<bool> cancelDebt(String debtId, String reason) async {
    try {
      ensureAuthenticated();
      final storeId = currentStoreId!;

      await _supabase
          .from('debts')
          .update({
            'status': 'cancelled',
            'notes': 'Đã hủy: $reason',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', debtId)
          .eq('store_id', storeId);

      return true;
    } catch (e) {
      throw Exception('Lỗi hủy công nợ: $e');
    }
  }
}
