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
import './product_unit_provider.dart';
import '../../../shared/services/base_service.dart';
import '../../../shared/utils/formatter.dart'; // 🔥 ADD: For proper formatting

// Trạng thái cho giỏ hàng nhập

// Trạng thái cho giỏ hàng nhập
enum PricingUnitSelection { container, base }

class POCartItem {
  final Product product;
  int quantity;
  double unitCost;
  double? sellingPrice;
  String? unit;
  String? unitId;
  String? defaultUnitId;
  String? defaultUnitName;
  double? selectedUnitFactor;
  double? defaultUnitFactor;
  double? defaultUnitCost;
  double? defaultSellingPrice;
  PricingUnitSelection pricingSelection;
  bool allowsPricingToggle;

  final TextEditingController quantityController;
  final TextEditingController unitCostController;
  final TextEditingController sellingPriceController;
  final TextEditingController defaultUnitCostController;
  final TextEditingController defaultSellingPriceController;

  POCartItem({
    required this.product,
    this.quantity = 1,
    this.unitCost = 0.0,
    this.sellingPrice,
    this.unit,
    this.unitId,
    this.defaultUnitId,
    this.defaultUnitName,
    this.selectedUnitFactor,
    this.defaultUnitFactor,
    this.defaultUnitCost,
    this.defaultSellingPrice,
    this.pricingSelection = PricingUnitSelection.container,
    this.allowsPricingToggle = false,
  })  : quantityController = TextEditingController(text: quantity.toString()),
        unitCostController = TextEditingController(
          text: unitCost > 0 ? AppFormatter.formatNumber(unitCost) : '',
        ),
        sellingPriceController = TextEditingController(
          text: (() {
            final seed = sellingPrice ?? product.currentSellingPrice;
            return seed > 0 ? AppFormatter.formatNumber(seed) : '';
          })(),
        ),
        defaultUnitCostController = TextEditingController(
          text: defaultUnitCost != null && defaultUnitCost! > 0
              ? AppFormatter.formatNumber(defaultUnitCost!)
              : '',
        ),
        defaultSellingPriceController = TextEditingController(
          text: (() {
            final seed = defaultSellingPrice ??
                sellingPrice ?? product.currentSellingPrice;
            return seed > 0 ? AppFormatter.formatNumber(seed) : '';
          })(),
        ) {
    this.sellingPrice ??= product.currentSellingPrice;
    this.defaultSellingPrice ??= sellingPrice ?? product.currentSellingPrice;
  }

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
    sellingPriceController.dispose();
    defaultUnitCostController.dispose();
    defaultSellingPriceController.dispose();
  }

  POCartItem copyWith({
    Product? product,
    int? quantity,
    double? unitCost,
    double? sellingPrice,
    String? unit,
    String? unitId,
    String? defaultUnitId,
    String? defaultUnitName,
    double? selectedUnitFactor,
    double? defaultUnitFactor,
    double? defaultUnitCost,
    double? defaultSellingPrice,
    PricingUnitSelection? pricingSelection,
    bool? allowsPricingToggle,
  }) {
    return POCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      unit: unit ?? this.unit,
      unitId: unitId ?? this.unitId,
      defaultUnitId: defaultUnitId ?? this.defaultUnitId,
      defaultUnitName: defaultUnitName ?? this.defaultUnitName,
      selectedUnitFactor: selectedUnitFactor ?? this.selectedUnitFactor,
      defaultUnitFactor: defaultUnitFactor ?? this.defaultUnitFactor,
      defaultUnitCost: defaultUnitCost ?? this.defaultUnitCost,
      defaultSellingPrice: defaultSellingPrice ?? this.defaultSellingPrice,
      pricingSelection: pricingSelection ?? this.pricingSelection,
      allowsPricingToggle: allowsPricingToggle ?? this.allowsPricingToggle,
    );
  }
}
enum POStatus { idle, loading, success, error }

class PurchaseOrderProvider extends ChangeNotifier {
  final PurchaseOrderService _poService = PurchaseOrderService();
  final ProductService _productService = ProductService();
  final ProductProvider _productProvider;
  final ProductUnitProvider _productUnitProvider;

  PurchaseOrderProvider(
    this._productProvider,
    this._productUnitProvider,
  );

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
      // All filtering and sorting is now done by the database RPC.
      final fetched = await _poService.searchPurchaseOrders(
        searchText: _searchText,
        supplierIds: _selectedSupplierIds.isNotEmpty ? _selectedSupplierIds : null,
        statusFilters: _statusFilters.isNotEmpty ? _statusFilters : null,
        fromDate: _fromDate,
        toDate: _toDate,
        minTotal: _minTotal,
        maxTotal: _maxTotal,
        sortBy: _sortBy,
        sortAsc: _sortAsc,
      );

      _purchaseOrders = fetched;

      debugPrint(
        '🔍 searchPurchaseOrders: RPC returned ${_purchaseOrders.length} rows, first=${_purchaseOrders.isNotEmpty ? _purchaseOrders.first.poNumber : 'none'}',
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

        // Invalidate ProductUnitProvider cache and reload latest units
        _productUnitProvider.clearCache(productId: productId);
        final refreshedUnits = prefetchedUnits != null && prefetchedUnits.isNotEmpty
            ? prefetchedUnits
            : await _productUnitProvider.getUnitsForProduct(
                productId,
                forceRefresh: true,
              );
        if (refreshedUnits.isNotEmpty) {
          _productUnitsById[productId] = refreshedUnits;
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
            await _productUnitProvider.getUnitsForProduct(productId);
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
    double? newDefaultUnitCost,
    double? newSellingPrice,
    double? newDefaultSellingPrice,
    String? newUnit,
    String? newUnitId, // 🔥 NEW: Add unitId parameter
    String? newDefaultUnitId,
    String? newDefaultUnitName,
    double? newSelectedUnitFactor,
    double? newDefaultUnitFactor,
    PricingUnitSelection? newPricingSelection,
    bool? newAllowsPricingToggle,
    bool? clearSellingPrice, // Add explicit flag for clearing
    bool? clearDefaultUnitCost,
    bool? clearDefaultSellingPrice,
  }) {
    final index = _poCartItems.indexWhere(
      (item) => item.product.id == productId,
    );
    if (index == -1) return;

    final item = _poCartItems[index];

    double? _ratioForItem(POCartItem cartItem) {
      final selected = cartItem.selectedUnitFactor;
      final base = cartItem.defaultUnitFactor;
      if (selected == null || base == null || base == 0) return null;
      return selected / base;
    }

    double? _toBase(POCartItem cartItem, double containerValue) {
      final ratio = _ratioForItem(cartItem);
      if (ratio == null || ratio == 0) return null;
      return containerValue / ratio;
    }

    double? _toContainer(POCartItem cartItem, double baseValue) {
      final ratio = _ratioForItem(cartItem);
      if (ratio == null) return null;
      return baseValue * ratio;
    }

    void syncControllers(POCartItem cartItem) {
      final containerCost =
          cartItem.unitCost > 0 ? cartItem.unitCost : null;
      final baseCost = cartItem.defaultUnitCost ??
          (containerCost != null ? _toBase(cartItem, containerCost) : null);
      if (baseCost != null) {
        cartItem.defaultUnitCost = baseCost;
        cartItem.defaultUnitCostController.text =
            baseCost > 0 ? AppFormatter.formatNumber(baseCost) : '';
      } else {
        cartItem.defaultUnitCostController.text = '';
      }
      if (containerCost != null) {
        cartItem.unitCostController.text =
            AppFormatter.formatNumber(containerCost);
      } else {
        cartItem.unitCostController.text = '';
      }

      final containerSell = cartItem.sellingPrice;
      final baseSell = cartItem.defaultSellingPrice ??
          (containerSell != null ? _toBase(cartItem, containerSell) : null);
      if (baseSell != null) {
        cartItem.defaultSellingPrice = baseSell;
        cartItem.defaultSellingPriceController.text =
            baseSell > 0 ? AppFormatter.formatNumber(baseSell) : '';
      } else {
        cartItem.defaultSellingPriceController.text = '';
      }
      if (containerSell != null && containerSell > 0) {
        cartItem.sellingPriceController.text =
            AppFormatter.formatNumber(containerSell);
      } else {
        cartItem.sellingPriceController.text = '';
      }
    }

    if (newAllowsPricingToggle != null) {
      item.allowsPricingToggle = newAllowsPricingToggle;
    }

    if (newQuantity != null) {
      item.quantity = newQuantity.clamp(0, 999999);
      item.quantityController.text = item.quantity.toString();
    }
    if (newUnit != null) {
      item.unit = newUnit;
    }
    if (newUnitId != null) {
      item.unitId = newUnitId;
    }
    if (newDefaultUnitId != null) {
      item.defaultUnitId = newDefaultUnitId;
    }
    if (newDefaultUnitName != null) {
      item.defaultUnitName = newDefaultUnitName;
    }
    if (newSelectedUnitFactor != null) {
      item.selectedUnitFactor = newSelectedUnitFactor;
    }
    if (newDefaultUnitFactor != null) {
      item.defaultUnitFactor = newDefaultUnitFactor;
    }

    if (newUnitCost != null) {
      item.unitCost = newUnitCost.clamp(0.0, double.infinity);
      final baseCost = _toBase(item, item.unitCost);
      if (baseCost != null) {
        item.defaultUnitCost = baseCost;
      }
    }
    if (newDefaultUnitCost != null) {
      item.defaultUnitCost = newDefaultUnitCost.clamp(0.0, double.infinity);
      final containerCost = _toContainer(item, item.defaultUnitCost!);
      if (containerCost != null) {
        item.unitCost = containerCost;
      }
    }
    if (clearDefaultUnitCost == true) {
      item.defaultUnitCost = null;
    }

    if (clearSellingPrice == true) {
      item.sellingPrice = null;
      item.defaultSellingPrice = null;
    } else if (newSellingPrice != null) {
      item.sellingPrice = newSellingPrice.clamp(0.0, double.infinity);
      final baseSell =
          item.sellingPrice != null ? _toBase(item, item.sellingPrice!) : null;
      if (baseSell != null) {
        item.defaultSellingPrice = baseSell;
      }
    }
    if (clearDefaultSellingPrice == true) {
      item.defaultSellingPrice = null;
    } else if (newDefaultSellingPrice != null) {
      item.defaultSellingPrice =
          newDefaultSellingPrice.clamp(0.0, double.infinity);
      final containerSell = _toContainer(item, item.defaultSellingPrice!);
      if (containerSell != null) {
        item.sellingPrice = containerSell;
      }
    }

    if (newPricingSelection != null) {
      item.pricingSelection = newPricingSelection;
    }

    syncControllers(item);
    notifyListeners();
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

  void _clearAllFilters() {
    _searchText = '';
    _selectedSupplierIds = [];
    _statusFilters.clear();
    _fromDate = null;
    _toDate = null;
    _minTotal = null;
    _maxTotal = null;
    _sortBy = 'order_date';
    _sortAsc = false;
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
            final units = await _productUnitProvider.getUnitsForProduct(
              cartItem.product.id,
              forceRefresh: true,
            );
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

        double? computedDefaultSellingPrice = cartItem.defaultSellingPrice;
        if (computedDefaultSellingPrice == null &&
            cartItem.sellingPrice != null &&
            cartItem.selectedUnitFactor != null &&
            cartItem.defaultUnitFactor != null &&
            cartItem.selectedUnitFactor! > 0 &&
            cartItem.defaultUnitFactor! > 0) {
          computedDefaultSellingPrice =
              cartItem.sellingPrice! *
                  (cartItem.defaultUnitFactor! / cartItem.selectedUnitFactor!);
        }

        if (computedDefaultSellingPrice != null &&
            computedDefaultSellingPrice > 0 &&
            computedDefaultSellingPrice != cartItem.product.currentSellingPrice) {
          try {
            await _productService.updateCurrentSellingPrice(
              cartItem.product.id,
              computedDefaultSellingPrice,
              reason: 'Updated via Purchase Order creation',
            );
            debugPrint(
                'DEBUG: Updated selling price for ${cartItem.product.name}: $computedDefaultSellingPrice (default unit)');
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
              cartItem.sellingPrice ??
                  cartItem.defaultSellingPrice ??
                  cartItem.product.currentSellingPrice,
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
      _clearAllFilters(); // Clear filters before refreshing
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
