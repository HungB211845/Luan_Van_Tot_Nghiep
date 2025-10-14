import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_order.dart';
import '../models/purchase_order_item.dart';
import '../models/purchase_order_status.dart';
import '../models/product_batch.dart';
import '../models/product_unit.dart'; // Add this import
import '../services/purchase_order_service.dart';
import '../services/product_service.dart'; // For product filtering
import '../models/product.dart'; // For adding to cart
import './product_provider.dart'; // Import ProductProvider
import '../../../shared/services/base_service.dart';
import '../../../shared/utils/formatter.dart'; // 🔥 ADD: For proper formatting

// Trạng thái cho giỏ hàng nhập

// Trạng thái cho giỏ hàng nhập
class POCartItem {
  final Product product;
  int quantity;
  double unitCost;
  double? sellingPrice; // MODIFIED: Make nullable
  String? unit;
  String? unitId; // 🔥 NEW: Unit ID for Multi-UoM conversion

  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController sellingPriceController; // ADDED

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.sellingPrice,
    this.unit,
    this.unitId, // 🔥 NEW: Unit ID parameter
  })  : quantityController = TextEditingController(text: quantity.toString()),
        unitCostController = TextEditingController(
          text: unitCost > 0 ? AppFormatter.formatNumber(unitCost) : '', // 🔥 FIXED: Use AppFormatter
        ),
        sellingPriceController = TextEditingController(
          text: sellingPrice != null && sellingPrice! > 0 
              ? AppFormatter.formatNumber(sellingPrice!) // 🔥 FIXED: Use AppFormatter
              : '',
        );

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    sellingPriceController.dispose(); // ADDED
  }

  POCartItem copyWith({
    Product? product,
    int? quantity,
    double? unitCost,
    double? sellingPrice,
    String? unit,
    String? unitId, // 🔥 NEW: unitId parameter
  }) {
    return POCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unit: unit ?? this.unit,
      unitId: unitId ?? this.unitId, // 🔥 NEW: Copy unitId
    );
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
  final Map<String, List<ProductUnit>> _productUnitsById = {};
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
  List<ProductUnit>? unitsForProduct(String productId) =>
      _productUnitsById[productId];
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
  List<POCartItem> get validPOCartItems =>
      _poCartItems.where((item) => item.quantity > 0).toList();

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
        supplierIds: _selectedSupplierIds.isNotEmpty
            ? _selectedSupplierIds
            : null,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
      );

      debugPrint(
        '🔍 searchPurchaseOrders: fetched ${fetched.length} rows (search="$_searchText", suppliers=${_selectedSupplierIds.join(',')}, statusFilters=${_statusFilters.map((e) => e.name).join(',')})',
      );

      // Apply client-side filtering/sorting as a safety net
      List<PurchaseOrder> results = List.from(fetched);

      // Filter by supplier ids
      if (_selectedSupplierIds.isNotEmpty) {
        results = results
            .where(
              (po) =>
                  po.supplierId != null &&
                  _selectedSupplierIds.contains(po.supplierId),
            )
            .toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after supplier filter ${results.length} rows',
        );
      }

      // Filter by date range
      if (_fromDate != null) {
        final start = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        );
        results = results.where((po) {
          final od = DateTime(
            po.orderDate.year,
            po.orderDate.month,
            po.orderDate.day,
          );
          return od.isAtSameMomentAs(start) || od.isAfter(start);
        }).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after fromDate filter ${results.length} rows',
        );
      }
      if (_toDate != null) {
        final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
        results = results.where((po) {
          final od = DateTime(
            po.orderDate.year,
            po.orderDate.month,
            po.orderDate.day,
          );
          return od.isAtSameMomentAs(end) || od.isBefore(end);
        }).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after toDate filter ${results.length} rows',
        );
      }

      // Filter by amount range
      if (_minTotal != null) {
        results = results.where((po) => po.totalAmount >= _minTotal!).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after minTotal filter ${results.length} rows',
        );
      }
      if (_maxTotal != null) {
        results = results.where((po) => po.totalAmount <= _maxTotal!).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after maxTotal filter ${results.length} rows',
        );
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
            final od = DateTime(
              po.orderDate.year,
              po.orderDate.month,
              po.orderDate.day,
            );
            final dq = DateTime(
              dateQuery!.year,
              dateQuery!.month,
              dateQuery!.day,
            );
            return od == dq; // exact date match
          }
          return matchesText;
        }).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after text/date filter ${results.length} rows',
        );
      }

      // Filter by status
      if (_statusFilters.isNotEmpty) {
        results = results.where((po) => _statusFilters.contains(po.status)).toList();
        debugPrint(
          '🔍 searchPurchaseOrders: after status filter ${results.length} rows',
        );
      }

      // Sort
      results.sort((a, b) {
        int cmp;
        if (_sortBy == 'total_amount') {
          cmp = a.totalAmount.compareTo(b.totalAmount);
        } else {
          // Default by order_date
          cmp = a.orderDate.compareTo(b.orderDate);
        }

        // If primary sort key is the same, use creation time as a tie-breaker
        if (cmp == 0) {
          cmp = b.createdAt.compareTo(a.createdAt); // Newest first
        }

        return _sortAsc ? cmp : -cmp;
      });

      _purchaseOrders = results;
      debugPrint(
        '🔍 searchPurchaseOrders: final ${_purchaseOrders.length} rows, first=${_purchaseOrders.isNotEmpty ? _purchaseOrders.first.poNumber : 'none'}',
      );
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
    _visibleCount = (_visibleCount + _pageSize).clamp(
      0,
      _purchaseOrders.length,
    );
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
      // Gán giá trị sau khi đã có dữ liệu để tránh lỗi
      _selectedPO = details['order'];
      _selectedPOItems = details['items'];
      await _ensureUnitsForProducts(
        _selectedPOItems.map((item) => item.productId).toSet(),
      );
      await loadBatchesForPO(poId);
      _setStatus(POStatus.success);
    } catch (e) {
      _setError(e.toString());
    } finally {
      // Đảm bảo notify dù thành công hay thất bại
      notifyListeners();
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
      // Ensure PO is in CONFIRMED state before receiving (backend requirement)
      final currentStatus = _selectedPO?.status;
      if (currentStatus == PurchaseOrderStatus.sent) {
        final confirmedPO = await _poService.updatePurchaseOrderStatus(
          poId,
          PurchaseOrderStatus.confirmed,
        );
        _selectedPO = confirmedPO;
        _updatePurchaseOrderInList(confirmedPO);
      }

      final result = await _poService.receivePurchaseOrder(poId);
      final updatedPO = result['po'] as PurchaseOrder;
      final updatedProducts = (result['products'] as List<Product>?) ?? const [];
      final unitsMap = (result['units'] as Map<String, List<ProductUnit>>?) ??
          const <String, List<ProductUnit>>{};

      // Update local PO state
      _selectedPO = updatedPO;
      _updatePurchaseOrderInList(updatedPO);

      // Determine affected product IDs (fallback to existing items if service didn't return products)
      final productIds = updatedProducts.isNotEmpty
          ? updatedProducts.map((p) => p.id).toList()
          : _selectedPOItems.map((item) => item.productId).toList();

      // Refresh product data & caches
      for (final productId in productIds) {
        await _productProvider.refreshProductSummary(productId);
        final prefetchedUnits = unitsMap[productId];
        await _productProvider.refreshProductUnitsCache(
          productId,
          forceNetwork: prefetchedUnits == null,
          prefetchedUnits: prefetchedUnits,
        );
        if (prefetchedUnits != null && prefetchedUnits.isNotEmpty) {
          _productUnitsById[productId] = prefetchedUnits;
        }
      }
      if (productIds.isNotEmpty) {
        await _productProvider.refreshInventoryAfterGoodsReceipt(productIds);
      }

      await loadPODetails(poId);

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void _updatePurchaseOrderInList(PurchaseOrder updatedPO) {
    final index = _purchaseOrders.indexWhere((po) => po.id == updatedPO.id);
    if (index != -1) {
      _purchaseOrders[index] = updatedPO;
    } else {
      _purchaseOrders.insert(0, updatedPO);
    }
  }

  Future<void> _ensureUnitsForProducts(Set<String> productIds) async {
    for (final productId in productIds) {
      if (_productUnitsById.containsKey(productId) &&
          _productUnitsById[productId]!.isNotEmpty) {
        continue;
      }
      try {
        final units =
            await _productProvider.getProductUnits(productId, forceRefresh: false);
        _productUnitsById[productId] = units;
      } catch (e) {
        debugPrint('Unable to load units for $productId: $e');
      }
    }
  }

  String formatItemQuantity(PurchaseOrderItem item) {
    final unitName = item.unit;
    if (unitName == null || unitName.isEmpty) {
      return '${item.quantity}';
    }
    final units = _productUnitsById[item.productId];
    if (units != null && units.isNotEmpty) {
      final matching = units.firstWhere(
        (u) => u.unitName.toLowerCase() == unitName.toLowerCase(),
        orElse: () => units.first,
      );
      if (matching.conversionFactor > 0) {
        final qty = item.quantity / matching.conversionFactor;
        final formatted = _formatQuantity(qty);
        return '$formatted $unitName';
      }
    }
    return '${_formatQuantity(item.quantity.toDouble())} $unitName';
  }

  String formatBatchQuantity(ProductBatch batch) {
    final units = _productUnitsById[batch.productId];
    if (units != null && units.isNotEmpty) {
      // Prefer default selling unit
      final defaultUnit = units.firstWhere(
        (u) => u.isDefaultSellingUnit,
        orElse: () => units.first,
      );
      if (defaultUnit.conversionFactor > 0) {
        final qty = batch.quantity / defaultUnit.conversionFactor;
        final formatted = _formatQuantity(qty);
        return '$formatted ${defaultUnit.unitName}';
      }
    }
    return _formatQuantity(batch.quantity.toDouble());
  }

  String _formatQuantity(double value) {
    final rounded = value.roundToDouble();
    if ((rounded - value).abs() < 0.0001) {
      return rounded.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(
          RegExp(r'\.$'),
          '',
        );
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
      _filteredProducts = await _productService.getProductsByCompany(
        _selectedSupplierId,
      );
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

  void addToPOCart(
    Product product, {
    int quantity = 1,
    double? unitCost,
    String? unit,
    double? sellingPrice,
  }) {
    final existingIndex = _poCartItems.indexWhere(
      (item) => item.product.id == product.id,
    );
    if (existingIndex != -1) {
      _poCartItems[existingIndex].quantity += quantity;
    } else {
      _poCartItems.add(
        POCartItem(
          product: product,
          quantity: quantity,
          unitCost: unitCost ?? 0.0,
          sellingPrice: sellingPrice,
          unit: unit,
        ),
      );
    }
    notifyListeners();
  }

  void addPOCartItem(POCartItem item) {
    final existingIndex = _poCartItems.indexWhere(
      (cartItem) => cartItem.product.id == item.product.id,
    );
    if (existingIndex != -1) {
      _poCartItems[existingIndex] = item;
    } else {
      _poCartItems.add(item);
    }
    notifyListeners();
  }

  void updatePOCartItem(
    String productId, {
    int? newQuantity,
    double? newUnitCost,
    double? newSellingPrice,
    String? newUnit,
    String? newUnitId, // 🔥 NEW: Add unitId parameter
    bool? clearSellingPrice, // Add explicit flag for clearing
  }) {
    final index = _poCartItems.indexWhere(
      (item) => item.product.id == productId,
    );
    if (index != -1) {
      if (newQuantity != null) {
        _poCartItems[index].quantity = newQuantity.clamp(0, 999999);
        _poCartItems[index].quantityController.text =
            _poCartItems[index].quantity.toString();
      }
      if (newUnitCost != null) {
        _poCartItems[index].unitCost = newUnitCost.clamp(0.0, double.infinity);
        _poCartItems[index].unitCostController.text =
            _poCartItems[index].unitCost > 0 
                ? AppFormatter.formatNumber(_poCartItems[index].unitCost) // 🔥 FIXED: Use AppFormatter
                : '';
      }
      // Handle selling price update
      if (clearSellingPrice == true) {
        // Explicitly clear selling price when user deletes all text
        _poCartItems[index].sellingPrice = null;
        _poCartItems[index].sellingPriceController.text = '';
      } else if (newSellingPrice != null) {
        // Update with new selling price value
        _poCartItems[index].sellingPrice =
            newSellingPrice.clamp(0.0, double.infinity);
        _poCartItems[index].sellingPriceController.text =
            _poCartItems[index].sellingPrice! > 0 
                ? AppFormatter.formatNumber(_poCartItems[index].sellingPrice!) // 🔥 FIXED: Use AppFormatter
                : '';
      }
      if (newUnit != null) {
        _poCartItems[index].unit = newUnit;
      }
      if (newUnitId != null) {
        _poCartItems[index].unitId = newUnitId; // 🔥 NEW: Update unitId
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
    final index = _poCartItems.indexWhere(
      (item) => item.product.id == productId,
    );
    if (index != -1) {
      _poCartItems[index].dispose(); // Dispose controllers
      _poCartItems.removeAt(index);
    }
    notifyListeners();
  }

  void clearPOCart() {
    // DON'T clear supplier selection - only clear cart items
    // _selectedSupplierId should be preserved during PO creation workflow
    for (var item in _poCartItems) {
      item.dispose(); // Dispose all controllers
    }
    _poCartItems.clear();
    // Keep _filteredProducts if supplier is still selected
    // _filteredProducts.clear(); // Don't clear - may be needed
    notifyListeners();
  }

  void clearPOCartAndSupplier() {
    // Use this method when truly starting fresh (e.g., after PO creation success)
    _selectedSupplierId = null;
    for (var item in _poCartItems) {
      item.dispose(); // Dispose all controllers
    }
    _poCartItems.clear();
    _filteredProducts.clear();
    notifyListeners();
  }

  Future<PurchaseOrder?> createPOFromCart({
    String? notes,
    PurchaseOrderStatus status = PurchaseOrderStatus.draft,
  }) async {
    final validItems = validPOCartItems;
    if (_selectedSupplierId == null || validItems.isEmpty) {
      _status = POStatus.error;
      _errorMessage =
          'Vui lòng chọn nhà cung cấp và thêm sản phẩm có số lượng > 0 vào đơn hàng';
      notifyListeners();
      return null;
    }

    if (_status == POStatus.loading) return null; // Prevent re-entrant calls

    _status = POStatus.loading;
    _errorMessage = '';

    PurchaseOrder? newPO;
    try {
      final items = <PurchaseOrderItem>[];
      double computedSubtotal = 0.0;

      for (final cartItem in validItems) {
        int baseQuantity = cartItem.quantity;
        double baseUnitCost = cartItem.unitCost;
        String unitName = cartItem.unit ?? cartItem.product.effectiveBaseUnit;

        if (cartItem.unitId != null) {
          try {
            final units =
                await _productProvider.getProductUnits(cartItem.product.id);
            final selectedUnit = units.firstWhere(
              (u) => u.id == cartItem.unitId,
              orElse: () => units.isNotEmpty
                  ? units.first
                  : ProductUnit(
                      id: '',
                      productId: cartItem.product.id,
                      unitName: cartItem.product.effectiveBaseUnit,
                      conversionFactor: 1.0,
                      unitPrice: 0,
                      isDefaultSellingUnit: false,
                      isActive: true,
                      storeId: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
            );
            
            if (selectedUnit.conversionFactor > 0) {
              final convertedQuantity =
                  cartItem.quantity * selectedUnit.conversionFactor;
              baseQuantity = convertedQuantity.round();
              baseUnitCost = cartItem.unitCost / selectedUnit.conversionFactor;
              unitName =
                  cartItem.product.effectiveBaseUnit; // Store using base unit
              debugPrint(
                  'DEBUG: PO Unit Conversion - ${cartItem.quantity} ${cartItem.unit} → ${convertedQuantity.toStringAsFixed(2)} base units (stored as $baseQuantity)');
            }
          } catch (e) {
            debugPrint(
                'Warning: Could not convert units for ${cartItem.product.name}: $e');
          }
        }

        if (cartItem.sellingPrice != null &&
            cartItem.sellingPrice! > 0 &&
            cartItem.sellingPrice! != cartItem.product.currentSellingPrice) {
          try {
            await _productService.updateCurrentSellingPrice(
              cartItem.product.id,
              cartItem.sellingPrice!,
              reason: 'Updated via Purchase Order creation',
            );
            debugPrint(
                'DEBUG: Updated selling price for ${cartItem.product.name}: ${cartItem.sellingPrice}');
          } catch (e) {
            debugPrint(
                'Warning: Could not update selling price for ${cartItem.product.name}: $e');
          }
        }

        final double totalCost = baseQuantity * baseUnitCost;
        computedSubtotal += totalCost;

        items.add(PurchaseOrderItem(
          id: '',
          purchaseOrderId: '',
          productId: cartItem.product.id,
          quantity: baseQuantity,
          unitCost: baseUnitCost,
          sellingPrice:
              cartItem.sellingPrice ?? cartItem.product.currentSellingPrice,
          unit: unitName,
          totalCost: totalCost,
          createdAt: DateTime.now(),
          storeId: BaseService.getDefaultStoreId(),
          notes: cartItem.unitId != null
              ? 'Unit conversion: ${cartItem.quantity} ${cartItem.unit} @ ${AppFormatter.formatNumber(cartItem.unitCost)} → $baseQuantity $unitName @ ${AppFormatter.formatNumber(baseUnitCost)}'
              : null,
        ));
      }

      final order = PurchaseOrder(
        id: '', // Handled by DB
        supplierId: _selectedSupplierId!,
        orderDate: DateTime.now(),
        status: status,
        notes: notes,
        totalAmount: computedSubtotal,
        subtotal: computedSubtotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: BaseService.getDefaultStoreId(),
      );

      newPO = await _poService.createPurchaseOrder(order, items);
      if (newPO != null) {
        debugPrint(
          '✅ createPOFromCart: created PO ${newPO.id} (${newPO.poNumber}) status=${newPO.status.name} total=${newPO.totalAmount}',
        );
      }

      _selectedSupplierId = null;
      for (var item in _poCartItems) {
        item.dispose();
      }
      _poCartItems.clear();
      _filteredProducts.clear();
      await _productProvider.refreshAllCache();
      await searchPurchaseOrders(); // Refresh list view with filters applied
      return newPO;
    } catch (e) {
      _status = POStatus.error;
      _errorMessage = e.toString();
      debugPrint('❌ createPOFromCart failed: $e');
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updatePOStatus(String poId, PurchaseOrderStatus status) async {
    _setStatus(POStatus.loading);
    try {
      final updatedPO = await _poService.updatePurchaseOrderStatus(
        poId,
        status,
      );
      final index = _purchaseOrders.indexWhere((po) => po.id == poId);
      if (index != -1) {
        _purchaseOrders[index] = updatedPO;
      }
      if (_selectedPO?.id == poId) {
        _selectedPO = updatedPO;
      }
      notifyListeners(); // Notify UI of all changes
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
