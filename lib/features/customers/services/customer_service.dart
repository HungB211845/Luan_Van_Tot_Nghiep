import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/customer.dart';

class CustomerService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await addStoreFilter(
        _supabase.from('customers').select('*'),
      ).order('name', ascending: true);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách khách hàng: $e');
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final response = await addStoreFilter(
        _supabase
            .from('customers')
            .select('*')
            .or('name.ilike.%$query%,phone.ilike.%$query%,address.ilike.%$query%'),
      ).order('name', ascending: true);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi tìm kiếm khách hàng: $e');
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final response = await _supabase
          .from('customers')
          .insert(addStoreId(customer.toJson()))
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi tạo khách hàng mới: $e');
    }
  }

  Future<Customer> updateCustomer(Customer customer) async {
    try {
      ensureAuthenticated();
      final response = await _supabase
          .from('customers')
          .update(customer.toJson())
          .eq('id', customer.id)
          .eq('store_id', currentStoreId!)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật khách hàng: $e');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    try {
      ensureAuthenticated();
      await _supabase
          .from('customers')
          .delete()
          .eq('id', customerId)
          .eq('store_id', currentStoreId!);
    } catch (e) {
      throw Exception('Lỗi xóa khách hàng: $e');
    }
  }

  Future<Customer?> getCustomerById(String customerId) async {
    try {
      ensureAuthenticated();
      final response = await _supabase
          .from('customers')
          .select()
          .eq('id', customerId)
          .eq('store_id', currentStoreId!)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi lấy thông tin khách hàng: $e');
    }
  }

  Future<List<Customer>> getCustomersSorted(String sortBy, bool ascending) async {
    try {
      String orderField;
      switch (sortBy) {
        case 'name':
          orderField = 'name';
          break;
        case 'debt_limit':
          orderField = 'debt_limit';
          break;
        case 'created_at':
          orderField = 'created_at';
          break;
        default:
          orderField = 'name';
      }

      final response = await addStoreFilter(
        _supabase.from('customers').select('*'),
      ).order(orderField, ascending: ascending);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi sắp xếp danh sách: $e');
    }
  }

  Future<Map<String, dynamic>> getCustomerStatistics(String customerId) async {
    try {
      ensureAuthenticated();
      print('🔍 DEBUG: Getting customer statistics for customer: $customerId, store: $currentStoreId');

      final response = await _supabase.rpc(
        'get_customer_statistics',
        params: {
          'p_customer_id': customerId,
          'p_store_id': currentStoreId,
        },
      );

      print('📊 DEBUG: RPC response: $response');
      print('📊 DEBUG: Response type: ${response.runtimeType}');

      if (response == null) {
        print('⚠️ DEBUG: Null response, returning default values');
        return {
          'transaction_count': 0,
          'total_revenue': 0.0,
          'outstanding_debt': 0.0,
        };
      }

      // Handle both JSON object response and Map response
      Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        data = response;
      } else if (response is String) {
        // If response is JSON string, parse it
        data = json.decode(response);
      } else {
        print('⚠️ DEBUG: Unexpected response format: $response');
        data = {};
      }

      final result = {
        'transaction_count': data['transaction_count'] ?? 0,
        'total_revenue': (data['total_revenue'] ?? 0.0).toDouble(),
        'outstanding_debt': (data['outstanding_debt'] ?? 0.0).toDouble(),
      };

      print('✅ DEBUG: Returning result: $result');
      return result;
    } catch (e) {
      print('❌ DEBUG: Error getting customer statistics: $e');
      throw Exception('Lỗi lấy thống kê khách hàng: $e');
    }
  }
}