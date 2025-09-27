import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/purchase_order_status.dart';
import '../models/product_batch.dart';
import '../services/purchase_order_service.dart';
import '../services/product_service.dart'; // For product filtering
import '../models/product.dart'; // For adding to cart
import './product_provider.dart'; // Import ProductProvider
import '../../../shared/services/base_service.dart';

// Trạng thái cho giỏ hàng nhập

// Trạng thái cho giỏ hàng nhập
class POCartItem {
  final Product product;
  int quantity;
  double unitCost;
  String? unit;
  // Add controllers for quantity and unitCost
  final TextEditingController quantityController;
  final TextEditingController unitCostController;

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.unit,
  }) : quantityController = TextEditingController(text: quantity.toString()),
       unitCostController = TextEditingController(text: unitCost.toStringAsFixed(0));

  // Add a dispose method for the controllers
  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
  }
}

enum POStatus { idle, loading, success, error }

class PurchaseOrderProvider extends ChangeNotifier {
  final PurchaseOrderService _poService = PurchaseOrderService();
  final ProductService _productService = ProductService();
  final ProductProvider _productProvider;

  PurchaseOrderProvider(this._productProvider);

  // State
  List<PurchaseOrder> _purchaseOrders = [];
  PurchaseOrder? _selectedPO;
  List<PurchaseOrderItem> _selectedPOItems = [];
  List<ProductBatch> _batchesForPO = []; // State mới
  POStatus _status = POStatus.idle;
  String _errorMessage = '';

  // PO Cart State
  String? _selectedSupplierId;
  List<POCartItem> _poCartItems = [];

  // Product Filtering State
  List<Product> _filteredProducts = [];
  bool _loadingProducts = false;

  // Search and Filter State
  String _searchText = '';
  List<String> _selectedSupplierIds = [];
  String _sortBy = 'order_date'; // Default sort
  bool _sortAsc = false;

  // Pagination for list screen (client-side)
  final int _pageSize = 20;
  int _visibleCount = 20;

  // Range filters
  DateTime? _fromDate;
  DateTime? _toDate;
  double? _minTotal;
  double? _maxTotal;
  // Status filters
  Set<PurchaseOrderStatus> _statusFilters = {};

  // Getters
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  PurchaseOrder? get selectedPO => _selectedPO;
  List<PurchaseOrderItem> get selectedPOItems => _selectedPOItems;
  List<ProductBatch> get batchesForPO => _batchesForPO; // Getter mới
  POStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get isLoading => _status == POStatus.loading;

  // PO Cart Getters
  List<POCartItem> get poCartItems => _poCartItems;
  String? get selectedSupplierId => _selectedSupplierId;
  double get poCartTotal => _poCartItems.fold(0, (sum, item) {
    // Only include items with quantity > 0 in total
    return sum + (item.quantity > 0 ? item.quantity * item.unitCost : 0);
  });

  // Get valid items for PO creation (quantity > 0)
  List<POCartItem> get validPOCartItems => _poCartItems.where((item) => item.quantity > 0).toList();

  // Product Filtering Getters
  List<Product> get filteredProducts => _filteredProducts;
  bool get loadingProducts => _loadingProducts;

  // Search and Filter Getters
  String get searchText => _searchText;
  List<String> get selectedSupplierIds => _selectedSupplierIds;
  String get sortBy => _sortBy;
  bool get sortAsc => _sortAsc;

  // Pagination getters
  List<PurchaseOrder> get visibleOrders =>
      _purchaseOrders.take(_visibleCount).toList();
  bool get reachedEnd => _visibleCount >= _purchaseOrders.length;

  // Range filter getters
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  double? get minTotal => _minTotal;
  double? get maxTotal => _maxTotal;
  Set<PurchaseOrderStatus> get statusFilters => _statusFilters;

  // Methods
  Future<void> loadPurchaseOrders() async {
    _setStatus(POStatus.loading);
    try {
      _purchaseOrders = await _poService.getPurchaseOrders();
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> searchPurchaseOrders() async {
    _setStatus(POStatus.loading);
    try {
      final fetched = await _poService.searchPurchaseOrders(
        searchText: _searchText,
        supplierIds: _selectedSupplierIds.isNotEmpty ? _selectedSupplierIds : null,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
      );

      // Apply client-side filtering/sorting as a safety net
      List<PurchaseOrder> results = List.from(fetched);

      // Filter by supplier ids
      if (_selectedSupplierIds.isNotEmpty) {
        results = results
            .where((po) => po.supplierId != null && _selectedSupplierIds.contains(po.supplierId))
            .toList();
      }

      // Filter by date range
      if (_fromDate != null) {
        final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        results = results.where((po) {
          final od = DateTime(po.orderDate.year, po.orderDate.month, po.orderDate.day);
          return od.isAtSameMomentAs(start) || od.isAfter(start);
        }).toList();
      }
      if (_toDate != null) {
        final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
        results = results.where((po) {
          final od = DateTime(po.orderDate.year, po.orderDate.month, po.orderDate.day);
          return od.isAtSameMomentAs(end) || od.isBefore(end);
        }).toList();
      }

      // Filter by amount range
      if (_minTotal != null) {
        results = results.where((po) => po.totalAmount >= _minTotal!).toList();
      }
      if (_maxTotal != null) {
        results = results.where((po) => po.totalAmount <= _maxTotal!).toList();
      }

      // Filter by search text (po_number, supplier_name) or exact date (dd/mm/yyyy | dd.mm.yyyy | dd-mm-yyyy)
      final q = _searchText.trim().toLowerCase();
      DateTime? dateQuery;
      if (q.isNotEmpty) {
        // Parse d/m/yyyy with '/', '.' or '-' as separators
        final reg = RegExp(r'^(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{4})$');
        final m = reg.firstMatch(q);
        if (m != null) {
          final d = int.tryParse(m.group(1)!);
          final mo = int.tryParse(m.group(2)!);
          final y = int.tryParse(m.group(3)!);
          if (d != null && mo != null && y != null) {
            dateQuery = DateTime(y, mo, d);
          }
        }
      }
      if (q.isNotEmpty) {
        results = results.where((po) {
          final poNum = (po.poNumber ?? '').toLowerCase();
          final supplierName = (po.supplierName ?? '').toLowerCase();
          final matchesText = poNum.contains(q) || supplierName.contains(q);
          if (dateQuery != null) {
            final od = DateTime(po.orderDate.year, po.orderDate.month, po.orderDate.day);
            final dq = DateTime(dateQuery!.year, dateQuery!.month, dateQuery!.day);
            return od == dq; // exact date match
          }
          return matchesText;
        }).toList();
      }

      // Sort
      results.sort((a, b) {
        int cmp;
        if (_sortBy == 'total_amount') {
          cmp = (a.totalAmount).compareTo(b.totalAmount);
        } else {
          // Default by order_date
          cmp = a.orderDate.compareTo(b.orderDate);
        }
        return _sortAsc ? cmp : -cmp;
      });

      _purchaseOrders = results;
      // Reset pagination on every search
      _visibleCount = _pageSize;
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Methods to update filters
  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
    // Optional: debounce search
  }

  void toggleSupplierFilter(String supplierId) {
    if (_selectedSupplierIds.contains(supplierId)) {
      _selectedSupplierIds.remove(supplierId);
    } else {
      _selectedSupplierIds.add(supplierId);
    }
    notifyListeners();
  }

  void setSort(String sortBy, bool ascending) {
    _sortBy = sortBy;
    _sortAsc = ascending;
    notifyListeners();
  }

  void applyFiltersAndSearch() {
    searchPurchaseOrders();
  }

  // Load next page (client-side)
  void loadMore() {
    if (reachedEnd) return;
    _visibleCount = (_visibleCount + _pageSize).clamp(0, _purchaseOrders.length);
    notifyListeners();
  }

  // Range filter setters
  void setDateRange({DateTime? from, DateTime? to}) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void setAmountRange({double? min, double? max}) {
    _minTotal = min;
    _maxTotal = max;
    notifyListeners();
  }

  // Status filter setter
  void toggleStatusFilter(PurchaseOrderStatus status) {
    if (_statusFilters.contains(status)) {
      _statusFilters.remove(status);
    } else {
      _statusFilters.add(status);
    }
    notifyListeners();
  }

  // Quick date ranges
  void quickToday() {
    final now = DateTime.now();
    setDateRange(from: now, to: now);
  }

  void quickLast7Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    setDateRange(from: start, to: now);
  }

  void quickLast30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));
    setDateRange(from: start, to: now);
  }

  Future<void> loadPODetails(String poId) async {
    _setStatus(POStatus.loading);
    try {
      final details = await _poService.getPurchaseOrderDetails(poId);
      _selectedPO = details['order'];
      _selectedPOItems = details['items'];
      await loadBatchesForPO(poId); // Tải luôn batch khi xem chi tiết
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Method mới để tải batches từ PO
  Future<void> loadBatchesForPO(String poId) async {
    try {
      _batchesForPO = await _poService.getBatchesFromPO(poId);
      notifyListeners();
    } catch (e) {
      // Lỗi này có thể bỏ qua một cách nhẹ nhàng vì nó là dữ liệu phụ
      print('Error loading batches for PO: $e');
    }
  }

  // Method mới cho quy trình nhận hàng
  Future<bool> receivePO(String poId) async {
    _setStatus(POStatus.loading);
    try {
      final updatedPO = await _poService.receivePurchaseOrder(poId);

      // Cập nhật lại PO trong list và trong state selected
      final index = _purchaseOrders.indexWhere((po) => po.id == poId);
      if (index != -1) {
        _purchaseOrders[index] = updatedPO;
      }
      if (_selectedPO?.id == poId) {
        _selectedPO = updatedPO;
        // Tải lại danh sách batch sau khi nhận hàng
        await loadBatchesForPO(poId);

        // Lấy danh sách product IDs từ các item của PO này
        // Cần đảm bảo _selectedPOItems đã được load hoặc load lại
        await loadPODetails(poId); // Ensure _selectedPOItems is updated
        final productIds = _selectedPOItems.map((item) => item.productId).toList();

        // Yêu cầu ProductProvider làm mới tồn kho và giá cho các sản phẩm này
        await _productProvider.refreshInventoryAfterGoodsReceipt(productIds);
      }

      _setStatus(POStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Get product IDs from PO items for inventory refresh
  List<String> getProductIdsFromPO(String poId) {
    return _selectedPOItems.map((item) => item.productId).toList();
  }

  // PO Cart Management
  void setSupplierForCart(String supplierId) {
    if (_selectedSupplierId != supplierId) {
      _poCartItems.clear(); // Clear cart if supplier changes
      _selectedSupplierId = supplierId;
      _loadProductsForSupplier(); // Auto-load filtered products
    } else {
      _selectedSupplierId = supplierId;
    }
    notifyListeners();
  }

  // Load products filtered by selected supplier
  Future<void> _loadProductsForSupplier() async {
    if (_loadingProducts) return; // Prevent concurrent calls

    _loadingProducts = true;
    notifyListeners();

    try {
      _filteredProducts = await _productService.getProductsByCompany(_selectedSupplierId);
    } catch (e) {
      debugPrint('Error loading products for supplier: $e');
      _filteredProducts = [];
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  // Force reload products for current supplier
  Future<void> refreshProductsForSupplier() async {
    await _loadProductsForSupplier();
  }

  void addToPOCart(Product product, {int quantity = 1, double? unitCost, String? unit}) {
    final existingIndex = _poCartItems.indexWhere((item) => item.product.id == product.id);
    if (existingIndex != -1) {
      _poCartItems[existingIndex].quantity += quantity;
    } else {
      _poCartItems.add(POCartItem(
        product: product,
        quantity: quantity,
        unitCost: unitCost ?? 0.0,
        unit: unit,
      ));
    }
    notifyListeners();
  }

  void updatePOCartItem(String productId, {int? newQuantity, double? newUnitCost, String? newUnit}) {
    final index = _poCartItems.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (newQuantity != null) {
        // Allow quantity = 0, don't auto-remove
        _poCartItems[index].quantity = newQuantity.clamp(0, 999999);
        // Update controller text
        _poCartItems[index].quantityController.text = _poCartItems[index].quantity.toString();
      }
      if (newUnitCost != null) {
        _poCartItems[index].unitCost = newUnitCost.clamp(0.0, double.infinity);
        // Update controller text
        _poCartItems[index].unitCostController.text = _poCartItems[index].unitCost.toStringAsFixed(0);
      }
      if (newUnit != null) {
        _poCartItems[index].unit = newUnit;
      }
      notifyListeners();
    }
  }

  // Explicit method for removing items from cart
  void removeFromPOCartWithConfirmation(String productId) {
    // This method is for UI to call when user explicitly wants to delete
    removeFromPOCart(productId);
  }

  void removeFromPOCart(String productId) {
    final index = _poCartItems.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      _poCartItems[index].dispose(); // Dispose controllers
      _poCartItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearPOCart() {
    _selectedSupplierId = null;
    for (var item in _poCartItems) {
      item.dispose(); // Dispose all controllers
    }
    _poCartItems.clear();
    _filteredProducts.clear(); // Clear filtered products
    notifyListeners();
  }

  // Create Purchase Order from Cart
  Future<PurchaseOrder?> createPOFromCart({String? notes, PurchaseOrderStatus status = PurchaseOrderStatus.draft}) async {
    final validItems = validPOCartItems;
    if (_selectedSupplierId == null || validItems.isEmpty) {
      _setError('Vui lòng chọn nhà cung cấp và thêm sản phẩm có số lượng > 0 vào đơn hàng');
      return null;
    }

    _setStatus(POStatus.loading);

    final order = PurchaseOrder(
      id: '', // Handled by DB
      supplierId: _selectedSupplierId!,
      orderDate: DateTime.now(),
      status: status,
      notes: notes,
      totalAmount: poCartTotal,
      subtotal: poCartTotal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      storeId: BaseService.getDefaultStoreId(),
    );

    final items = validItems.map((cartItem) => PurchaseOrderItem(
      id: '', // Handled by DB
      purchaseOrderId: '', // Handled by service
      productId: cartItem.product.id,
      quantity: cartItem.quantity,
      unitCost: cartItem.unitCost,
      unit: cartItem.unit,
      totalCost: cartItem.quantity * cartItem.unitCost,
      createdAt: DateTime.now(),
      storeId: BaseService.getDefaultStoreId(),
    )).toList();

    try {
      final newPO = await _poService.createPurchaseOrder(order, items);
      clearPOCart();
      await loadPurchaseOrders(); // Refresh the list
      _setStatus(POStatus.success);
      return newPO;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> updatePOStatus(String poId, PurchaseOrderStatus status) async {
    _setStatus(POStatus.loading);
    try {
      final updatedPO = await _poService.updatePurchaseOrderStatus(poId, status);
      final index = _purchaseOrders.indexWhere((po) => po.id == poId);
      if (index != -1) {
        _purchaseOrders[index] = updatedPO;
      }
      if (_selectedPO?.id == poId) {
        _selectedPO = updatedPO;
      }
      _setStatus(POStatus.success);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void _setStatus(POStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = POStatus.error;
    notifyListeners();
  }
}
