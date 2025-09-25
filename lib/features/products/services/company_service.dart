import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/company.dart';
import '../models/product.dart'; // Thêm import cho Product model

class CompanyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy tất cả companies
  Future<List<Company>> getCompanies() async {
    try {
      final response = await _supabase
          .from('companies')
          .select('*')
          .order('name', ascending: true);
      return (response as List)
          .map((json) => Company.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách nhà cung cấp: $e');
    }
  }

  // Tạo company mới
  Future<Company> createCompany(Company company) async {
    try {
      final response = await _supabase
          .from('companies')
          .insert(company.toJson())
          .select()
          .single();
      return Company.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi tạo nhà cung cấp: $e');
    }
  }

  // Cập nhật company
  Future<Company> updateCompany(Company company) async {
    try {
      final response = await _supabase
          .from('companies')
          .update(company.toJson())
          .eq('id', company.id)
          .select()
          .single();
      return Company.fromJson(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật nhà cung cấp: $e');
    }
  }

  // Xóa company (soft delete nếu có products)
  Future<void> deleteCompany(String companyId) async {
    try {
      // Check xem có products nào đang dùng company này không
      final products = await _supabase
          .from('products')
          .select('id')
          .eq('company_id', companyId)
          .eq('is_active', true);

      if (products.isNotEmpty) {
        throw Exception(
            'Không thể xóa nhà cung cấp vì còn ${products.length} sản phẩm đang sử dụng');
      }

      await _supabase.from('companies').delete().eq('id', companyId);
    } catch (e) {
      throw Exception('Lỗi xóa nhà cung cấp: $e');
    }
  }

  // Lấy sản phẩm của một company
  Future<List<Product>> getCompanyProducts(String companyId) async {
    try {
      final response = await _supabase
          .from('products_with_details')
          .select('*')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('name', ascending: true);
      return (response as List)
          .map((json) => Product.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy sản phẩm của nhà cung cấp: $e');
    }
  }
}
