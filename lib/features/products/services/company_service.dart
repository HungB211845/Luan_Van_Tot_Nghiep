import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/company.dart';
import '../models/product.dart'; // Thêm import cho Product model

class CompanyService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy tất cả companies
  Future<List<Company>> getCompanies() async {
    try {
      final response = await addStoreFilter(
        _supabase.from('companies').select('*'),
      )
          .eq('is_active', true)
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
      // Normalize name (trim + single spaces)
      final normalizedName = company.name.trim().replaceAll(RegExp(r'\s+'), ' ');

      // Duplicate name check within current store (case-insensitive)
      final dup = await addStoreFilter(
        _supabase.from('companies').select('id').eq('is_active', true),
      )
          .ilike('name', normalizedName)
          .maybeSingle();
      if (dup != null) {
        throw Exception('Tên nhà cung cấp đã tồn tại trong cửa hàng');
      }

      final data = addStoreId({
        ...company.toJson(),
        'name': normalizedName,
      });

      final response = await _supabase
          .from('companies')
          .insert(data)
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
      ensureAuthenticated();

      final normalizedName = company.name.trim().replaceAll(RegExp(r'\s+'), ' ');

      // Check duplicate name (exclude current id)
      final dupList = await addStoreFilter(
        _supabase
            .from('companies')
            .select('id')
            .eq('is_active', true),
      )
          .ilike('name', normalizedName);
      final hasDup = (dupList as List)
          .any((row) => row['id'] != company.id);
      if (hasDup) {
        throw Exception('Tên nhà cung cấp đã tồn tại trong cửa hàng');
      }

      final response = await _supabase
          .from('companies')
          .update({
            ...company.toJson(),
            'name': normalizedName,
          })
          .eq('id', company.id)
          .eq('store_id', currentStoreId!)
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
      ensureAuthenticated();
      // Check xem có products nào đang dùng company này không
      final products = await addStoreFilter(
        _supabase.from('products').select('id'),
      )
          .eq('company_id', companyId)
          .eq('is_active', true);

      if ((products as List).isNotEmpty) {
        throw Exception(
            'Không thể xóa nhà cung cấp vì còn ${products.length} sản phẩm đang sử dụng');
      }

      // Soft delete to avoid FK issues
      await _supabase
          .from('companies')
          .update({'is_active': false})
          .eq('id', companyId)
          .eq('store_id', currentStoreId!);
    } catch (e) {
      throw Exception('Lỗi xóa nhà cung cấp: $e');
    }
  }

  // Lấy sản phẩm của một company
  Future<List<Product>> getCompanyProducts(String companyId) async {
    try {
      final response = await addStoreFilter(
        _supabase.from('products_with_details').select('*'),
      )
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

  // Kiểm tra tên NCC đã tồn tại (case-insensitive) trong store hiện tại
  Future<bool> existsCompanyName(String name, {String? excludeId}) async {
    final normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final rows = await addStoreFilter(
      _supabase.from('companies').select('id').eq('is_active', true),
    )
        .ilike('name', normalized);
    final list = rows as List;
    if (excludeId == null) return list.isNotEmpty;
    return list.any((r) => r['id'] != excludeId);
  }

  // Check if company has products
  Future<bool> hasProducts(String companyId) async {
    ensureAuthenticated();

    final response = await addStoreFilter(
      _supabase.from('products').select('id'),
    )
        .eq('company_id', companyId)
        .eq('is_active', true)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  // Check if company has purchase orders
  Future<bool> hasPurchaseOrders(String companyId) async {
    ensureAuthenticated();

    final response = await addStoreFilter(
      _supabase.from('purchase_orders').select('id'),
    )
        .eq('supplier_id', companyId)
        .limit(1);

    return (response as List).isNotEmpty;
  }

  // Get companies with metadata (products count, orders count)
  Future<List<Map<String, dynamic>>> getCompaniesWithMetadata() async {
    ensureAuthenticated();

    try {
      // Load basic companies first
      final companies = await getCompanies();

      // Manually count products and orders for each company
      final companiesWithMetadata = <Map<String, dynamic>>[];

      for (var company in companies) {
        // Count products - use actual query result length
        final productsResponse = await addStoreFilter(
          _supabase.from('products').select('id'),
        )
            .eq('company_id', company.id)
            .eq('is_active', true);
        final productsCount = (productsResponse as List).length;

        // Count purchase orders (dùng supplier_id, không phải company_id)
        final ordersResponse = await addStoreFilter(
          _supabase.from('purchase_orders').select('id'),
        )
            .eq('supplier_id', company.id);
        final ordersCount = (ordersResponse as List).length;

        companiesWithMetadata.add({
          'id': company.id,
          'name': company.name,
          'phone': company.phone,
          'address': company.address,
          'contact_person': company.contactPerson,
          'note': company.note,
          'store_id': company.storeId,
          'created_at': company.createdAt?.toIso8601String(),
          'updated_at': company.updatedAt?.toIso8601String(),
          'products_count': productsCount,
          'orders_count': ordersCount,
        });
      }

      return companiesWithMetadata;
    } catch (e) {
      throw Exception('Lỗi lấy danh sách nhà cung cấp với metadata: $e');
    }
  }
}
