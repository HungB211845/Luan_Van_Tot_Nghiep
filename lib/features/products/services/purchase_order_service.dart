import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/base_service.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/purchase_order_status.dart';
import '../models/product_batch.dart';
import '../models/product.dart'; // 🔥 FIX: Add missing import
import '../models/product_unit.dart';
import './product_service.dart'; // 🔥 FIX: Add missing import
import './product_unit_service.dart';

class PurchaseOrderService extends BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lấy danh sách đơn nhập hàng (có thể thêm phân trang sau)
  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    try {
      final response = await addStoreFilter(
        _supabase.from('purchase_orders_with_details').select('*'),
      )
          .order('order_date', ascending: false);
      return (response as List)
          .map((json) => PurchaseOrder.fromMap(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy danh sách đơn nhập hàng: $e');
    }
  }

  // Search purchase orders using the RPC function
  Future<List<PurchaseOrder>> searchPurchaseOrders({
    String? searchText,
    List<String>? supplierIds,
    Set<PurchaseOrderStatus>? statusFilters,
    DateTime? fromDate,
    DateTime? toDate,
    double? minTotal,
    double? maxTotal,
    String? sortBy,
    bool? sortAsc,
  }) async {
    try {
      final params = {
        'p_search_text': searchText,
        'p_supplier_ids': supplierIds,
        'p_status_filters': statusFilters?.map((s) => s.name).toList(),
        'p_from_date': fromDate?.toIso8601String(),
        'p_to_date': toDate?.toIso8601String(),
        'p_min_total': minTotal,
        'p_max_total': maxTotal,
        'p_sort_by': sortBy,
        'p_sort_asc': sortAsc,
      };

      final response = await _supabase.rpc('search_purchase_orders', params: params);
      return (response as List)
          .map((json) => PurchaseOrder.fromMap(json))
          .toList();
    } catch (e) {
      // Fallback gracefully to basic list if RPC is not available
      try {
        final fallback = await getPurchaseOrders();
        return fallback;
      } catch (_) {
        throw Exception('Lỗi tìm kiếm đơn nhập hàng: $e');
      }
    }
  }

  // Lấy chi tiết một đơn nhập hàng và các sản phẩm của nó
  Future<Map<String, dynamic>> getPurchaseOrderDetails(String poId) async {
    try {
      final poResponse = await addStoreFilter(
        _supabase.from('purchase_orders_with_details').select('*'),
      )
          .eq('id', poId)
          .single();

      // Join products to enrich with product name for UI
      final itemsResponse = await addStoreFilter(
        _supabase.from('purchase_order_items').select('''
            id,
            purchase_order_id,
            product_id,
            quantity,
            unit_cost,
            selling_price,
            unit,
            total_cost,
            received_quantity,
            notes,
            created_at,
            products(name)
          '''),
      )
          .eq('purchase_order_id', poId);

      return {
        'order': PurchaseOrder.fromMap(poResponse),
        'items': (itemsResponse as List)
            .map((json) => PurchaseOrderItem.fromMap(json))
            .toList(),
      };
    } catch (e) {
      throw Exception('Lỗi lấy chi tiết đơn nhập hàng: $e');
    }
  }

  // Tạo một đơn nhập hàng mới
  Future<PurchaseOrder> createPurchaseOrder(
      PurchaseOrder order, List<PurchaseOrderItem> items) async {
    try {
      ensureAuthenticated();
      // 1. Insert the main purchase order
      final poMap = order.toMap();
      poMap.remove('id'); // ID is auto-generated

      final poResponse = await _supabase
          .from('purchase_orders')
          .insert(addStoreId(poMap))
          .select()
          .single();

      final newOrderId = poResponse['id'];

      // 2. Insert the purchase order items
      final List<Map<String, dynamic>> itemsToInsert = [];
      for (var item in items) {
        final itemMap = item.toMap();
        itemMap.remove('id');
        itemMap['purchase_order_id'] = newOrderId;
        itemsToInsert.add(itemMap);
      }

      // add store_id for each item
      final itemsWithStore = itemsToInsert.map((m) => addStoreId(m)).toList();
      await _supabase.from('purchase_order_items').insert(itemsWithStore);

      // Return the newly created purchase order
      return PurchaseOrder.fromMap(poResponse);
    } catch (e) {
      throw Exception('Lỗi tạo đơn nhập hàng: $e');
    }
  }

  // Cập nhật trạng thái đơn nhập hàng (chung)
  Future<PurchaseOrder> updatePurchaseOrderStatus(
      String poId, PurchaseOrderStatus status) async {
    try {
      ensureAuthenticated();
      final response = await _supabase
          .from('purchase_orders')
          .update({'status': status.name})
          .eq('id', poId)
          .eq('store_id', currentStoreId!)
          .select()
          .single();
      return PurchaseOrder.fromMap(response);
    } catch (e) {
      throw Exception('Lỗi cập nhật trạng thái đơn nhập hàng: $e');
    }
  }

  // Nhận hàng cho một PO và trả về cả PO và danh sách sản phẩm đã được cập nhật
  Future<Map<String, dynamic>> receivePurchaseOrder(String poId) async {
    try {
      ensureAuthenticated();

      // 1. Gọi RPC để xử lý nghiệp vụ chính (tạo batch, cập nhật giá)
      await _supabase.rpc('create_batches_from_po', params: {'po_id': poId});

      // 2. Đảm bảo trạng thái đã chuyển sang DELIVERED
      await _supabase
          .from('purchase_orders')
          .update({'status': PurchaseOrderStatus.delivered.name})
          .eq('id', poId)
          .eq('store_id', currentStoreId!);

      // 3. Lấy lại thông tin PO mới nhất
      final updatedPoResponse = await addStoreFilter(
        _supabase.from('purchase_orders_with_details').select('*'),
      )
          .eq('id', poId)
          .single();
      final updatedPO = PurchaseOrder.fromMap(updatedPoResponse);

      // 4. Lấy danh sách các sản phẩm bị ảnh hưởng từ PO
      final poItems = await addStoreFilter(
        _supabase.from('purchase_order_items').select('product_id'),
      ).eq('purchase_order_id', poId);

      final productIds = (poItems as List)
          .map((item) => item['product_id'] as String)
          .toSet()
          .toList();

      // 5. Chủ động lấy lại dữ liệu mới nhất của các sản phẩm đó
      final productService = ProductService();
      final updatedProducts = <Product>[];
      for (final productId in productIds) {
        final product = await productService.getProductById(productId);
        if (product != null) {
          updatedProducts.add(product);
        }
      }

      // 6. Nạp lại danh sách đơn vị để đảm bảo giá/đa đơn vị cập nhật
      final unitService = ProductUnitService();
      final Map<String, List<ProductUnit>> unitsByProduct = {};
      for (final productId in productIds) {
        try {
          final units = await unitService.getProductUnits(productId);
          unitsByProduct[productId] = units;
        } catch (e) {
          // Ignore unit failures to avoid blocking flow
          print('Warning: Failed to refresh units for $productId: $e');
        }
      }

      // 7. Trả về một object chứa tất cả dữ liệu đã được làm mới
      return {
        'po': updatedPO,
        'products': updatedProducts,
        'units': unitsByProduct,
      };
    } catch (e) {
      throw Exception('Lỗi khi nhận hàng cho đơn nhập: $e');
    }
  }

  // Lấy các lô hàng được tạo từ một PO
  Future<List<ProductBatch>> getBatchesFromPO(String poId) async {
    try {
      final response = await addStoreFilter(
        _supabase.from('product_batches').select('id,product_id,purchase_order_id,supplier_id,batch_number,quantity,cost_price,received_date,expiry_date,supplier_batch_id,notes,is_available,created_at,updated_at, products(name), companies(name)'),
      )
          .eq('purchase_order_id', poId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => ProductBatch.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Lỗi lấy lô hàng từ đơn nhập: $e');
    }
  }
}
