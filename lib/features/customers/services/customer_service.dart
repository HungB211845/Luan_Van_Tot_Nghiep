import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';

class CustomerService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _supabase
          .from('customers')
          .select('*')
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách khách hàng: $e');
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final response = await _supabase
          .from('customers')
          .select('*')
          .or('name.ilike.%$query%,phone.ilike.%$query%,address.ilike.%$query%')
          .order('name', ascending: true);

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
          .insert(customer.toJson())
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi tạo khách hàng mới: $e');
    }
  }

  Future<Customer> updateCustomer(Customer customer) async {
    try {
      final response = await _supabase
          .from('customers')
          .update(customer.toJson())
          .eq('id', customer.id)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật khách hàng: $e');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    try {
      await _supabase
          .from('customers')
          .delete()
          .eq('id', customerId);
    } catch (e) {
      throw Exception('Lỗi xóa khách hàng: $e');
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

      final response = await _supabase
          .from('customers')
          .select('*')
          .order(orderField, ascending: ascending);

      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi sắp xếp danh sách: $e');
    }
  }
}